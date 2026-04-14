import 'dart:convert';
import 'package:http/http.dart' as http;

class StatsFetchService {
  // LeetCode Stats
  static Future<Map<String, dynamic>?> fetchLeetCode(String username) async {
    final url = Uri.parse('https://leetcode-stats-api.herokuapp.com/$username');
    try {
      // Added a 5-second timeout
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') return data;
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