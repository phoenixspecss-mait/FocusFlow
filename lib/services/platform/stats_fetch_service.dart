import 'dart:convert';
import 'package:http/http.dart' as http;

class StatsFetchService {
  // LeetCode Stats — uses the official GraphQL API directly
  static Future<Map<String, dynamic>?> fetchLeetCode(String username) async {
    const endpoint = 'https://leetcode.com/graphql';
    const query = '''
      query getUserProfile(\$username: String!) {
        matchedUser(username: \$username) {
          submitStats {
            acSubmissionNum {
              difficulty
              count
            }
          }
        }
      }
    ''';
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Referer': 'https://leetcode.com',
        },
        body: jsonEncode({'query': query, 'variables': {'username': username}}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final acList = body['data']?['matchedUser']?['submitStats']
                ?['acSubmissionNum'] as List? ?? [];

        int totalSolved = 0, easySolved = 0, mediumSolved = 0, hardSolved = 0;
        for (final item in acList) {
          final d = item['difficulty'] as String? ?? '';
          final c = item['count'] as int? ?? 0;
          if (d == 'All')    totalSolved  = c;
          if (d == 'Easy')   easySolved   = c;
          if (d == 'Medium') mediumSolved = c;
          if (d == 'Hard')   hardSolved   = c;
        }

        // Return map with keys matching what progress_view.dart expects
        return {
          'status': 'success',
          'totalSolved': totalSolved,
          'easySolved': easySolved,
          'mediumSolved': mediumSolved,
          'hardSolved': hardSolved,
        };
      }
    } catch (e) {
      print('LeetCode Error: $e');
    }
    return null;
  }

  // Codeforces Stats
  static Future<Map<String, dynamic>?> fetchCodeforces(String handle) async {
    final url = Uri.parse('https://codeforces.com/api/user.info?handles=$handle');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK') return data['result'][0];
    } catch (e) {
      print('Codeforces Error: $e');
    }
    return null;
  }
}