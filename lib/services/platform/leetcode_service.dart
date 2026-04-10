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
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day)
        .millisecondsSinceEpoch ~/ 1000;

    for (final s in submissions) {
      final slug = s['titleSlug'] as String? ?? '';
      final ts   = int.tryParse(s['timestamp'].toString()) ?? 0;
      if (slug == titleSlug && ts >= todayStart) return true;
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