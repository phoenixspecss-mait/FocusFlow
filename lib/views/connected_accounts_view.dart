import 'package:FocusFlow/views/widgets/skeleton_loader.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:FocusFlow/services/auth/auth_service.dart';
import 'package:FocusFlow/views/app_shell.dart';

class ConnectedAccountsView extends StatefulWidget {
  const ConnectedAccountsView({super.key});
  @override
  State<ConnectedAccountsView> createState() => _ConnectedAccountsViewState();
}

class _ConnectedAccountsViewState extends State<ConnectedAccountsView> {
  final _db  = FirebaseDatabase.instance.ref();
  final _storage = const FlutterSecureStorage();
  String? get _uid => AuthService.firebase().currentUser?.id;

  final _lcCtrl    = TextEditingController();
  final _cfCtrl    = TextEditingController();
  final _ccCtrl    = TextEditingController();
  final _ghCtrl    = TextEditingController();
  final _ghPatCtrl = TextEditingController();

  bool _saving  = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _lcCtrl.dispose(); _cfCtrl.dispose();
    _ccCtrl.dispose(); _ghCtrl.dispose(); _ghPatCtrl.dispose();
    super.dispose();
  }

Future<void> _load() async {
  final prefs = await SharedPreferences.getInstance();
  
  // 1. Try to load from Local Storage first (fast)
  String? lc = prefs.getString('lc_username');
  String? cf = prefs.getString('cf_handle');
  String? cc = prefs.getString('cc_username');
  String? gh = prefs.getString('gh_username');
  String? ghPat = await _storage.read(key: 'gh_pat');

  // 2. If local is empty and user is logged in, fetch from Firebase
  if (_uid != null && (lc == null || cf == null)) {
    final snapshot = await _db.child('users/$_uid/connectedAccounts').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      lc = data['leetcode'] ?? '';
      cf = data['codeforces'] ?? '';
      cc = data['codechef'] ?? '';
      gh = data['github'] ?? '';
      
      // 3. Save back to SharedPreferences so it's faster next time
      await prefs.setString('lc_username', lc!);
      await prefs.setString('cf_handle',   cf!);
      await prefs.setString('cc_username', cc!);
      await prefs.setString('gh_username', gh!);
    }
  }

  // 4. Update the controllers to show the names in the UI
  setState(() {
    _lcCtrl.text = lc ?? '';
    _cfCtrl.text = cf ?? '';
    _ccCtrl.text = cc ?? '';
    _ghCtrl.text = gh ?? '';
    _ghPatCtrl.text = ghPat ?? '';
    _loading = false;
  });
}

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      // Sensitive data → local secure storage on-device
      await prefs.setString('lc_username', _lcCtrl.text.trim());
      await prefs.setString('cf_handle',   _cfCtrl.text.trim());
      await prefs.setString('cc_username', _ccCtrl.text.trim());
      await prefs.setString('gh_username', _ghCtrl.text.trim());
      if (_ghPatCtrl.text.isNotEmpty) {
        await _storage.write(key: 'gh_pat', value: _ghPatCtrl.text.trim());
      }

      var remoteSyncFailed = false;
      final uid = _uid;
      if (uid != null) {
        try {
          await _db.child('users/$uid/connectedAccounts').update({
            'leetcode':  _lcCtrl.text.trim(),
            'codeforces': _cfCtrl.text.trim(),
            'codechef':  _ccCtrl.text.trim(),
            'githubUsername':    _ghCtrl.text.trim(),
          });
          // CHANGE THIS:
await _db.child('leaderboard/$uid').update({
  'username': AuthService.firebase().currentUser?.email?.split('@').first ?? 'user',
  'xp': 0,      // Required by your validation rules
  'streak': 0,  // Required by your validation rules
});
        } catch (error) {
          remoteSyncFailed = true;
          debugPrint('Connected accounts remote save failed: $error');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(
              remoteSyncFailed ? Icons.info_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(remoteSyncFailed
                  ? 'Saved locally. Remote sync failed.'
                  : 'Accounts saved!'),
            ),
          ]),
          backgroundColor: remoteSyncFailed ? Colors.orange.shade700 : FF.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (error) {
      debugPrint('Connected accounts save failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(child: Text('Unable to save accounts. Please try again.')),
          ]),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FF.bg,
      appBar: AppBar(
        backgroundColor: FF.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: FF.textPri, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Connected Accounts',
            style: TextStyle(color: FF.textPri, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: _loading
          ? const ConnectedAccountsSkeleton()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: FF.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: FF.accent.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded, color: FF.accent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Usernames are used to auto-verify tasks.\nGitHub PAT is stored on-device only.',
                        style: TextStyle(color: FF.accent, fontSize: 12, height: 1.5),
                      ),
                    ),
                  ]),
                ),

                _AccountTile(
                  platform: 'LeetCode',
                  icon: Icons.code_rounded,
                  color: const Color(0xFFFFA116),
                  hint: 'your-username',
                  controller: _lcCtrl,
                  obscure: false,
                ),
                _AccountTile(
                  platform: 'Codeforces',
                  icon: Icons.terminal_rounded,
                  color: const Color(0xFF4F8EF7),
                  hint: 'tourist',
                  controller: _cfCtrl,
                  obscure: false,
                ),
                _AccountTile(
                  platform: 'CodeChef',
                  icon: Icons.restaurant_rounded,
                  color: const Color(0xFF5B4638),
                  hint: 'chef_handle',
                  controller: _ccCtrl,
                  obscure: false,
                ),
                _AccountTile(
                  platform: 'GitHub',
                  icon: Icons.hub_rounded,
                  color: const Color(0xFF3DDC84),
                  hint: 'octocat',
                  controller: _ghCtrl,
                  obscure: false,
                ),
                _AccountTile(
                  platform: 'GitHub PAT',
                  icon: Icons.key_rounded,
                  color: FF.textSec,
                  hint: 'ghp_xxxxxxxxxxxx',
                  controller: _ghPatCtrl,
                  obscure: true,
                  subtitle: 'Needs read:user scope only',
                ),
                const SizedBox(height: 32),

                // Save button — matches app style
                GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F8EF7), Color(0xFF3DDC84)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.save_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Save Accounts',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final String platform;
  final IconData icon;
  final Color color;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final String? subtitle;

  const _AccountTile({
    required this.platform,
    required this.icon,
    required this.color,
    required this.hint,
    required this.controller,
    required this.obscure,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FF.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Text(platform,
                style: TextStyle(
                    color: FF.textPri,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            if (subtitle != null) ...[
              const SizedBox(width: 8),
              Text(subtitle!,
                  style: TextStyle(color: FF.textSec, fontSize: 11)),
            ],
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            obscureText: obscure,
            style: TextStyle(color: FF.textPri, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: FF.textSec.withOpacity(0.5)),
              filled: true,
              fillColor: FF.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: FF.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: FF.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: FF.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}