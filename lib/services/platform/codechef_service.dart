import 'dart:convert';
import 'package:http/http.dart' as http;

class CodeChefStats {
  final String username;
  final int currentRating;
  final int highestRating;
  final String stars;
  final int globalRank;
  final int countryRank;
  final Map<DateTime, int> heatmap;

  CodeChefStats({
    required this.username,
    required this.currentRating,
    required this.highestRating,
    required this.stars,
    required this.globalRank,
    required this.countryRank,
    required this.heatmap,
  });
}

class CodeChefService {
  // Community-maintained API — widely used, no auth needed
  static const _base = 'https://codechef-api.vercel.app/handle';

  static Future<CodeChefStats?> fetchStats(String username) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/$username'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == false) return null;

      // Parse heatmap from heatMap array: [{month,year,value:[{count,date}]}]
      final heatmap = <DateTime, int>{};
      final heatRaw = data['heatMap'] as List? ?? [];
      for (final month in heatRaw) {
        final values = month['value'] as List? ?? [];
        for (final v in values) {
          final dateStr = v['date'] as String? ?? '';
          final count   = v['count'] as int? ?? 0;
          final dt = DateTime.tryParse(dateStr);
          if (dt != null && count > 0) {
            heatmap[DateTime(dt.year, dt.month, dt.day)] = count;
          }
        }
      }

      return CodeChefStats(
        username: username,
        currentRating: data['currentRating'] as int? ?? 0,
        highestRating: data['highestRating'] as int? ?? 0,
        stars: data['stars'] ?? '0★',
        globalRank: data['globalRank'] as int? ?? 0,
        countryRank: data['countryRank'] as int? ?? 0,
        heatmap: heatmap,
      );
    } catch (_) {
      return null;
    }
  }

  // Check if user submitted today (CodeChef heatmap has today's count)
  static Future<bool> submittedToday(String username) async {
    final stats = await fetchStats(username);
    if (stats == null) return false;
    final today = DateTime.now();
    final key = DateTime(today.year, today.month, today.day);
    return (stats.heatmap[key] ?? 0) > 0;
  }
}