import 'dart:convert';
import 'package:http/http.dart' as http;

class LeetCodeStats {
  final int solved;
  final int easy;
  final int medium;
  final int hard;
  final int ranking;
  final int streak;
  final int totalActiveDays;
  final Map<String, int> submissionCalendar; // unix_timestamp_str -> count

  LeetCodeStats({
    required this.solved,
    required this.easy,
    required this.medium,
    required this.hard,
    required this.ranking,
    required this.streak,
    required this.totalActiveDays,
    required this.submissionCalendar,
  });
}

class LeetCodeProblem {
  final String title;
  final String titleSlug;
  final String difficulty;
  LeetCodeProblem({required this.title, required this.titleSlug, required this.difficulty});
}

class LeetCodeService {
  static const _endpoint = 'https://leetcode.com/graphql';

  static Future<Map<String, dynamic>?> _query(String query, Map<String, dynamic> variables) async {
    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Referer': 'https://leetcode.com',
        },
        body: jsonEncode({'query': query, 'variables': variables}),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ── Fetch POTD ──────────────────────────────────────────────────────────
  static Future<LeetCodeProblem?> fetchPOTD() async {
    const q = '''
      query {
        activeDailyCodingChallengeQuestion {
          question {
            title
            titleSlug
            difficulty
          }
        }
      }
    ''';
    final data = await _query(q, {});
    if (data == null) return null;
    final q2 = data['data']?['activeDailyCodingChallengeQuestion']?['question'];
    if (q2 == null) return null;
    return LeetCodeProblem(
      title: q2['title'] ?? '',
      titleSlug: q2['titleSlug'] ?? '',
      difficulty: q2['difficulty'] ?? '',
    );
  }
  static Future<List<dynamic>> fetchRecentSubmissions(String username) async {
    // GraphQL query to get recent AC (Accepted) submissions
    final query = {
      "query": """
        query recentAcSubmissions(\$username: String!, \$limit: Int!) {
          recentAcSubmissionList(username: \$username, limit: \$limit) {
            title
            titleSlug
            timestamp
            statusDisplay
          }
        }
      """,
      "variables": {"username": username, "limit": 20}
    };

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(query),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // This returns the list of submissions from the JSON response
        return data['data']['recentAcSubmissionList'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      print('LeetCode API Error: $e');
      return [];
    }
  }
  

  // ── Check if user solved a specific problem today ───────────────────────
static Future<bool> isSolvedToday(String username, String titleSlug) async {
  const q = '''
    query getRecentAC(\$username: String!) {
      recentAcSubmissionList(username: \$username, limit: 20) {
        titleSlug
        timestamp
      }
    }
  ''';
  final data = await _query(q, {'username': username});
  if (data == null) return false;

  final submissions = data['data']?['recentAcSubmissionList'] as List? ?? [];
  
  // 1. Normalize your target slug (Remove all non-alphanumeric chars)
  final normalizedTarget = titleSlug.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  // 2. Window logic: Using 24 hours (86400s) is safer for IST morning solves
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final dayWindow = 86400; 

  for (final s in submissions) {
    final apiSlug = s['titleSlug'] as String? ?? '';
    final ts = int.tryParse(s['timestamp'].toString()) ?? 0;

    // 3. Normalize the API slug for comparison
    final normalizedApiSlug = apiSlug.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    // Check if the slugs match and if it happened within the rolling 24h window
    if (normalizedApiSlug == normalizedTarget && (now - ts) <= dayWindow) {
      return true;
    }
  }
  return false;
}

  // ── Fetch full stats + heatmap ──────────────────────────────────────────
  static Future<LeetCodeStats?> fetchStats(String username) async {
    const q = '''
      query getUserProfile(\$username: String!) {
        matchedUser(username: \$username) {
          profile { ranking }
          submitStats {
            acSubmissionNum {
              difficulty
              count
            }
          }
          userCalendar {
            streak
            totalActiveDays
            submissionCalendar
          }
        }
      }
    ''';
    final data = await _query(q, {'username': username});
    if (data == null) return null;

    final user = data['data']?['matchedUser'];
    if (user == null) return null;

    final acList = user['submitStats']?['acSubmissionNum'] as List? ?? [];
    int solved = 0, easy = 0, medium = 0, hard = 0;
    for (final item in acList) {
      final d = item['difficulty'] as String? ?? '';
      final c = item['count'] as int? ?? 0;
      if (d == 'All')    solved  = c;
      if (d == 'Easy')   easy   = c;
      if (d == 'Medium') medium = c;
      if (d == 'Hard')   hard   = c;
    }

    final cal = user['userCalendar'];
    final rawCal = cal?['submissionCalendar'] as String? ?? '{}';
    final calMap = (jsonDecode(rawCal) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as num).toInt()));

    return LeetCodeStats(
      solved: solved,
      easy: easy,
      medium: medium,
      hard: hard,
      ranking: user['profile']?['ranking'] as int? ?? 0,
      streak: cal?['streak'] as int? ?? 0,
      totalActiveDays: cal?['totalActiveDays'] as int? ?? 0,
      submissionCalendar: calMap,
    );
  }

  // ── Convert submissionCalendar to DateTime heatmap ──────────────────────
  static Map<DateTime, int> toHeatmap(Map<String, int> cal) {
    return cal.map((ts, count) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
          (int.tryParse(ts) ?? 0) * 1000);
      final day = DateTime(dt.year, dt.month, dt.day);
      return MapEntry(day, count);
    });
  }
}