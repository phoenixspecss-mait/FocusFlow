import 'dart:convert';
import 'package:http/http.dart' as http;

class GitHubStats {
  final String username;
  final String name;
  final int publicRepos;
  final int followers;
  final int totalContributions;
  final int streak;
  final Map<DateTime, int> heatmap;

  GitHubStats({
    required this.username,
    required this.name,
    required this.publicRepos,
    required this.followers,
    required this.totalContributions,
    required this.streak,
    required this.heatmap,
  });
}

class GitHubService {
  static const _restBase    = 'https://api.github.com';
  static const _graphqlBase = 'https://api.github.com/graphql';

  // ── Fetch basic user info (no auth needed for public profiles) ──────────
  static Future<Map<String, dynamic>?> fetchUserInfo(String username) async {
    try {
      final res = await http.get(
        Uri.parse('$_restBase/users/$username'),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  // ── Fetch contribution calendar (requires PAT) ──────────────────────────
  static Future<GitHubStats?> fetchStats(String username, String pat) async {
    // Step 1: basic info
    final userInfo = await fetchUserInfo(username);
    if (userInfo == null) return null;

    // Step 2: contribution graph via GraphQL
    const query = '''
      query(\$login: String!) {
        user(login: \$login) {
          contributionsCollection {
            contributionCalendar {
              totalContributions
              weeks {
                contributionDays {
                  date
                  contributionCount
                }
              }
            }
          }
        }
      }
    ''';

    final heatmap = <DateTime, int>{};
    int totalContributions = 0;

    try {
      final res = await http.post(
        Uri.parse(_graphqlBase),
        headers: {
          'Authorization': 'Bearer $pat',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'query': query, 'variables': {'login': username}}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final cal = data['data']?['user']?['contributionsCollection']
            ?['contributionCalendar'];
        totalContributions = cal?['totalContributions'] as int? ?? 0;

        final weeks = cal?['weeks'] as List? ?? [];
        for (final week in weeks) {
          final days = week['contributionDays'] as List? ?? [];
          for (final day in days) {
            final dt    = DateTime.tryParse(day['date'] ?? '');
            final count = day['contributionCount'] as int? ?? 0;
            if (dt != null && count > 0) {
              heatmap[DateTime(dt.year, dt.month, dt.day)] = count;
            }
          }
        }
      }
    } catch (_) {}

    return GitHubStats(
      username: username,
      name: userInfo['name'] ?? username,
      publicRepos: userInfo['public_repos'] as int? ?? 0,
      followers: userInfo['followers'] as int? ?? 0,
      totalContributions: totalContributions,
      streak: _calculateStreak(heatmap),
      heatmap: heatmap,
    );
  }

  static int _calculateStreak(Map<DateTime, int> heatmap) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int streak = 0;
    DateTime current = today;

    // Check if today has contributions
    if ((heatmap[current] ?? 0) > 0) {
      streak++;
      current = current.subtract(const Duration(days: 1));
    } else {
      // If not today, check yesterday
      current = current.subtract(const Duration(days: 1));
      if ((heatmap[current] ?? 0) > 0) {
        streak++;
        current = current.subtract(const Duration(days: 1));
      } else {
        return 0; // No recent contributions
      }
    }

    // Continue counting backwards
    while ((heatmap[current] ?? 0) > 0) {
      streak++;
      current = current.subtract(const Duration(days: 1));
    }

    return streak;
  }

  // ── Check if user committed today (no PAT needed) ───────────────────────
  static Future<bool> committedToday(String username) async {
    try {
      final res = await http.get(
        Uri.parse('$_restBase/users/$username/events?per_page=30'),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return false;
      final events = jsonDecode(res.body) as List;
      final today  = DateTime.now();

      for (final e in events) {
        if (e['type'] != 'PushEvent') continue;
        final createdAt = DateTime.tryParse(e['created_at'] ?? '');
        if (createdAt == null) continue;
        if (createdAt.year == today.year &&
            createdAt.month == today.month &&
            createdAt.day == today.day) return true;
      }
    } catch (_) {}
    return false;
  }
}