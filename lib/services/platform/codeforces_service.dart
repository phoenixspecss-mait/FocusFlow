import 'dart:convert';
import 'package:http/http.dart' as http;

class CFUser {
  final String handle;
  final int rating;
  final int maxRating;
  final String rank;
  final String maxRank;
  final int contribution;
  CFUser({
    required this.handle,
    required this.rating,
    required this.maxRating,
    required this.rank,
    required this.maxRank,
    required this.contribution,
  });
}

class CFSubmission {
  final int id;
  final String problemName;
  final String contestId;
  final String index;
  final String verdict; // 'OK' = accepted
  final int creationTimeSeconds;
  CFSubmission({
    required this.id,
    required this.problemName,
    required this.contestId,
    required this.index,
    required this.verdict,
    required this.creationTimeSeconds,
  });
}

class CFRatingChange {
  final int contestId;
  final String contestName;
  final int rank;
  final int oldRating;
  final int newRating;
  final int ratingUpdateTimeSeconds;
  CFRatingChange({
    required this.contestId,
    required this.contestName,
    required this.rank,
    required this.oldRating,
    required this.newRating,
    required this.ratingUpdateTimeSeconds,
  });
}

class CodeforcesService {
  static const _base = 'https://codeforces.com/api';

  static Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/$path'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['status'] == 'OK') return body;
      }
    } catch (_) {}
    return null;
  }

  // ── Fetch user info ─────────────────────────────────────────────────────
  static Future<CFUser?> fetchUser(String handle) async {
    final data = await _get('user.info?handles=$handle');
    if (data == null) return null;
    final u = (data['result'] as List).first as Map<String, dynamic>;
    return CFUser(
      handle: u['handle'] ?? handle,
      rating: u['rating'] as int? ?? 0,
      maxRating: u['maxRating'] as int? ?? 0,
      rank: u['rank'] ?? 'unranked',
      maxRank: u['maxRank'] ?? 'unranked',
      contribution: u['contribution'] as int? ?? 0,
    );
  }

  // ── Fetch recent submissions ────────────────────────────────────────────
  static Future<List<CFSubmission>> fetchRecentSubmissions(
      String handle, {int count = 30}) async {
    final data = await _get('user.status?handle=$handle&from=1&count=$count');
    if (data == null) return [];
    final list = data['result'] as List? ?? [];
    return list.map((s) {
      final p = s['problem'] as Map<String, dynamic>;
      return CFSubmission(
        id: s['id'] as int? ?? 0,
        problemName: p['name'] ?? '',
        contestId: (p['contestId'] ?? '').toString(),
        index: p['index'] ?? '',
        verdict: s['verdict'] ?? '',
        creationTimeSeconds: s['creationTimeSeconds'] as int? ?? 0,
      );
    }).toList();
  }

  // ── Check if a specific problem is solved ───────────────────────────────
  static Future<bool> isProblemSolved(
      String handle, String contestId, String index) async {
    final subs = await fetchRecentSubmissions(handle, count: 100);
    return subs.any((s) =>
        s.contestId == contestId &&
        s.index == index &&
        s.verdict == 'OK');
  }

  // ── Check if user submitted anything today (for streak) ─────────────────
  static Future<bool> submittedToday(String handle) async {
    final subs = await fetchRecentSubmissions(handle, count: 10);
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day)
        .millisecondsSinceEpoch ~/ 1000;
    return subs.any((s) => s.creationTimeSeconds >= todayStart);
  }

  // ── Rating history (for graph) ──────────────────────────────────────────
  static Future<List<CFRatingChange>> fetchRatingHistory(String handle) async {
    final data = await _get('user.rating?handle=$handle');
    if (data == null) return [];
    final list = data['result'] as List? ?? [];
    return list.map((r) => CFRatingChange(
      contestId: r['contestId'] as int? ?? 0,
      contestName: r['contestName'] ?? '',
      rank: r['rank'] as int? ?? 0,
      oldRating: r['oldRating'] as int? ?? 0,
      newRating: r['newRating'] as int? ?? 0,
      ratingUpdateTimeSeconds: r['ratingUpdateTimeSeconds'] as int? ?? 0,
    )).toList();
  }

  // ── Build heatmap from submissions ──────────────────────────────────────
  static Future<Map<DateTime, int>> buildHeatmap(String handle) async {
    final subs = await fetchRecentSubmissions(handle, count: 500);
    final map = <DateTime, int>{};
    for (final s in subs) {
      if (s.verdict != 'OK') continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(s.creationTimeSeconds * 1000);
      final day = DateTime(dt.year, dt.month, dt.day);
      map[day] = (map[day] ?? 0) + 1;
    }
    return map;
  }
}