import 'package:flutter/material.dart';
import 'package:FocusFlow/views/app_shell.dart';
import 'package:FocusFlow/services/platform/stats_fetch_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressView extends StatefulWidget {
  const ProgressView({super.key});
  @override
  State<ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<ProgressView> {
  Map<String, dynamic>? lcData;
  Map<String, dynamic>? cfData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    final prefs = await SharedPreferences.getInstance();
    final lcUser = prefs.getString('lc_username');
    final cfUser = prefs.getString('cf_handle');

    if (lcUser != null && lcUser.isNotEmpty) {
      lcData = await StatsFetchService.fetchLeetCode(lcUser);
    }
    if (cfUser != null && cfUser.isNotEmpty) {
      cfData = await StatsFetchService.fetchCodeforces(cfUser);
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FF.bg,
      appBar: AppBar(title: Text('My Growth', style: TextStyle(color: FF.textPri, fontWeight: FontWeight.w800))),
      body: loading 
        ? Center(child: CircularProgressIndicator(color: FF.accent))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (lcData != null) _buildLeetCodeCard(),
              const SizedBox(height: 16),
              if (cfData != null) _buildCodeforcesCard(),
              // Add GitHub cards here later
            ],
          ),
    );
  }

  Widget _buildLeetCodeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: FF.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: FF.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.code, color: Colors.orange),
            SizedBox(width: 8),
            Text('LeetCode Progress', style: TextStyle(fontWeight: FontWeight.bold, color: FF.textPri)),
          ]),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem('Solved', '${lcData!['totalSolved']}'),
              _statItem('Easy', '${lcData!['easySolved']}', color: Colors.green),
              _statItem('Hard', '${lcData!['hardSolved']}', color: Colors.red),
            ],
          )
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {Color? color}) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color ?? FF.textPri)),
      Text(label, style: TextStyle(fontSize: 12, color: FF.textSec)),
    ]);
  }

  Widget _buildCodeforcesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: FF.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: FF.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.trending_up, color: Colors.blue),
            SizedBox(width: 8),
            Text('Codeforces Rating', style: TextStyle(fontWeight: FontWeight.bold, color: FF.textPri)),
          ]),
          const SizedBox(height: 12),
          Text('${cfData!['rating'] ?? 'Unrated'}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.blue)),
          Text('Rank: ${cfData!['rank'] ?? 'N/A'}', style: TextStyle(color: FF.textSec)),
        ],
      ),
    );
  }
}