import 'package:flutter/material.dart';
import 'package:FocusFlow/views/connected_accounts_view.dart';
import 'package:FocusFlow/views/widgets/skeleton_loader.dart';
import 'package:FocusFlow/services/settings_service.dart';
import 'package:FocusFlow/views/timer_settings_view.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:FocusFlow/services/auth/auth_service.dart';
import 'package:FocusFlow/services/database/database_service.dart';
import 'package:FocusFlow/views/app_shell.dart';
import 'package:FocusFlow/services/localization_service.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});
  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  String? get _uid => AuthService.firebase().currentUser?.id;
  final _db = DatabaseService.firebase();

  Map<String, dynamic> _profile = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_uid == null) return;
    final profile = await _db.getUserProfile(ownerUserId: _uid!);
    if (mounted) setState(() { _profile = profile; _loading = false; });
  }

  String get _displayName   => (_profile['name']          ?? 'Focus User') as String;
  int    get _totalSessions => (_profile['totalSessions']  ?? 0) as int;
  int    get _focusHours    => (_profile['focusHours']     ?? 0) as int;
  int    get _tasksDone     => (_profile['tasksDone']      ?? 0) as int;
  int    get _streak        => (_profile['streak']         ?? 0) as int;

  // ── Edit profile bottom sheet ──────────────
  void _showEditSheet() {
    final nameCtrl = TextEditingController(text: _displayName);
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FF.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: FF.textSec.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              LocalizationService.t('edit_profile'),
              style: TextStyle(
                color: FF.textPri, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            // Avatar preview
            CircleAvatar(
              radius: 36,
              backgroundColor: FF.accentSoft,
              child: Text(
                nameCtrl.text.isNotEmpty
                    ? nameCtrl.text[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  color: FF.accent, fontSize: 28, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 20),
            // Name field
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: TextStyle(color: FF.textPri, fontSize: 16),
              onChanged: (_) => setS(() {}), // refresh avatar letter
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: TextStyle(color: FF.textSec),
                prefixIcon: Icon(Icons.person_outline, color: FF.accent, size: 20),
                filled: true,
                fillColor: FF.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: FF.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: FF.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: FF.accent, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final newName = nameCtrl.text.trim();
                        if (newName.isEmpty) return;
                        setS(() => saving = true);
                        // Save to Firebase
                        await FirebaseDatabase.instance
                            .ref()
                            .child('users/$_uid')
                            .update({'name': newName});
                        // Refresh local state
                        if (mounted) {
                          setState(() => _profile['name'] = newName);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Profile updated!'),
                              backgroundColor: FF.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(12),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FF.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: FF.card,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: FF.bg,
          appBar: AppBar(
            backgroundColor: FF.bg,
            elevation: 0,
            title: Text(LocalizationService.t('profile'),
                style: TextStyle(
                    color: FF.textPri, fontWeight: FontWeight.w700, fontSize: 22)),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: FF.textSec),
                onPressed: () {
                  setState(() => _loading = true);
                  _loadProfile();
                },
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: FF.accent),
                onPressed: _showEditSheet,
              ),
            ],
          ),
          body: _loading
              ? const ProfileViewSkeleton()
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildStatsGrid(),
                    const SizedBox(height: 24),
                    _buildSection(LocalizationService.t('achievements'), _buildAchievements()),
                    const SizedBox(height: 24),
                    _buildSection(LocalizationService.t('settings'), _buildSettings()),
                    const SizedBox(height: 24),
                    _buildLogoutBtn(context),
                    const SizedBox(height: 32),
                  ]),
                ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(children: [
      Stack(alignment: Alignment.bottomRight, children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: FF.accentSoft,
          child: Text(
            _displayName[0].toUpperCase(),
            style: TextStyle(
                color: FF.accent, fontSize: 32, fontWeight: FontWeight.w800),
          ),
        ),
        // Tapping the edit icon on avatar also opens edit sheet
        GestureDetector(
          onTap: _showEditSheet,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
                color: FF.accent, shape: BoxShape.circle),
            child: const Icon(Icons.edit, color: Colors.white, size: 14),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      // Tap name to edit too
      GestureDetector(
        onTap: _showEditSheet,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_displayName,
              style: TextStyle(
                  color: FF.textPri, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Icon(Icons.edit, color: FF.textSec, size: 14),
        ]),
      ),
      const SizedBox(height: 4),
      Text(
        AuthService.firebase().currentUser?.id ?? '',
        style: TextStyle(color: FF.textSec, fontSize: 13),
      ),
      const SizedBox(height: 10),
      if (_streak > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: FF.success.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FF.success.withOpacity(0.4)),
          ),
          child: Text('🔥 $_streak-day streak',
              style: TextStyle(
                  color: FF.success, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
    ]);
  }

  Widget _buildStatsGrid() {
    final stats = [
      {'label': LocalizationService.t('total_sessions'), 'value': '$_totalSessions',
       'icon': Icons.timer_rounded,          'color': FF.accent},
      {'label': LocalizationService.t('focus_hours'),    'value': '${_focusHours}h',
       'icon': Icons.bolt,                   'color': FF.warning},
      {'label': LocalizationService.t('tasks_done'),     'value': '$_tasksDone',
       'icon': Icons.check_circle,           'color': FF.success},
      {'label': LocalizationService.t('current_streak'), 'value': '$_streak days',
       'icon': Icons.local_fire_department,  'color': const Color(0xFFFF7043)},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: stats.map((s) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FF.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FF.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(s['icon'] as IconData, color: s['color'] as Color, size: 20),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s['value'] as String,
                  style: TextStyle(
                      color: FF.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
              Text(s['label'] as String,
                  style: TextStyle(color: FF.textSec, fontSize: 11)),
            ]),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: TextStyle(
              color: FF.textPri, fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      content,
    ]);
  }

  Widget _buildAchievements() {
    final badges = [
      {'emoji': '🔥', 'title': LocalizationService.t('on_fire'),      'desc': LocalizationService.t('streak_desc'),
       'earned': _streak >= 7},
      {'emoji': '⚡',  'title': LocalizationService.t('speed_demon'),  'desc': LocalizationService.t('sessions_desc'),
       'earned': _totalSessions >= 10},
      {'emoji': '🎯', 'title': LocalizationService.t('sharpshooter'), 'desc': LocalizationService.t('tasks_desc'),
       'earned': _tasksDone >= 50},
      {'emoji': '🌙', 'title': LocalizationService.t('night_owl'),    'desc': LocalizationService.t('night_desc'),
       'earned': false},
      {'emoji': '🏆', 'title': LocalizationService.t('champion'),     'desc': LocalizationService.t('streak_30_desc'),
       'earned': _streak >= 30},
      {'emoji': '💎', 'title': LocalizationService.t('diamond'),      'desc': LocalizationService.t('sessions_500_desc'),
       'earned': _totalSessions >= 500},
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: badges.map((b) {
        final earned = b['earned'] as bool;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: earned ? FF.card : FF.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: earned ? FF.divider : FF.divider.withOpacity(0.5)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(b['emoji'] as String,
                style: TextStyle(
                    fontSize: 26,
                    color: earned ? null : const Color(0x44FFFFFF))),
            const SizedBox(height: 4),
            Text(b['title'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: earned ? FF.textPri : FF.textSec,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            Text(b['desc'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(color: FF.textSec, fontSize: 9)),
          ]),
        );
      }).toList(),
    );
  }

Widget _buildSettings() {
  final svc = SettingsService.instance;

  return Container(
    decoration: BoxDecoration(
      color: FF.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: FF.divider),
    ),
    child: Column(children: [

      // ── Notifications ──────────────────────
      ListTile(
        leading: Icon(Icons.notifications_outlined,
            color: FF.accent, size: 20),
        title: Text(LocalizationService.t('notifications'),
            style: TextStyle(color: FF.textPri, fontSize: 14)),
        trailing: Switch(
          value: svc.notifications,
          activeColor: FF.accent,
          onChanged: (v) {
            svc.setNotifications(v);
          },
        ),
      ),
      Divider(height: 1, color: FF.divider, indent: 52),
      ListTile(
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: FF.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.link_rounded, color: FF.accent, size: 18),
    ),
    title: Text('Connected Accounts',
        style: TextStyle(color: FF.textPri, fontWeight: FontWeight.w600)),
    subtitle: Text('LeetCode, Codeforces, GitHub...',
        style: TextStyle(color: FF.textSec, fontSize: 12)),
    trailing: Icon(Icons.chevron_right_rounded, color: FF.textSec),
    onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ConnectedAccountsView())),
  ),

      // ── Timer Duration ─────────────────────
      ListTile(
        leading: Icon(Icons.timer_outlined,
            color: FF.accent, size: 20),
        title: Text(LocalizationService.t('timer_duration'),
            style: TextStyle(color: FF.textPri, fontSize: 14)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(LocalizationService.t('customise'),
              style: TextStyle(color: FF.textSec, fontSize: 13)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: FF.textSec, size: 18),
        ]),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const TimerSettingsView()),
        ),
      ),
      Divider(height: 1, color: FF.divider, indent: 52),

      // ── Sounds ─────────────────────────────
      ListTile(
        leading: Icon(Icons.volume_up_outlined,
            color: FF.accent, size: 20),
        title: Text(LocalizationService.t('sounds'),
            style: TextStyle(color: FF.textPri, fontSize: 14)),
        trailing: Switch(
          value: svc.sounds,
          activeColor: FF.accent,
          onChanged: (v) {
            svc.setSounds(v);
          },
        ),
      ),
      Divider(height: 1, color: FF.divider, indent: 52),

      // ── Theme ──────────────────────────────
      ListTile(
        leading: Icon(Icons.dark_mode_outlined,
            color: FF.accent, size: 20),
        title: Text(LocalizationService.t('theme'),
            style: TextStyle(color: FF.textPri, fontSize: 14)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(svc.theme,
              style: TextStyle(color: FF.textSec, fontSize: 13)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: FF.textSec, size: 18),
        ]),
        onTap: () => _showPickerSheet(
          title: LocalizationService.t('theme'),
          options: ['Dark', 'Light'],
          current: svc.theme,
          icon: Icons.dark_mode_outlined,
          onSelect: (v) {
            svc.setTheme(v);
          },
        ),
      ),
      Divider(height: 1, color: FF.divider, indent: 52),

      // ── Language ───────────────────────────
      ListTile(
        leading: Icon(Icons.language_outlined,
            color: FF.accent, size: 20),
        title: Text(LocalizationService.t('language'),
            style: TextStyle(color: FF.textPri, fontSize: 14)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(svc.language,
              style: TextStyle(color: FF.textSec, fontSize: 13)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: FF.textSec, size: 18),
        ]),
        onTap: () => _showPickerSheet(
          title: LocalizationService.t('language'),
          options: ['English', 'Hindi', 'Spanish', 'French', 'German'],
          current: svc.language,
          icon: Icons.language_outlined,
          onSelect: (v) {
            svc.setLanguage(v);
          },
        ),
      ),

    ]),
  );
}

// ── Reusable option picker sheet ───────────────
void _showPickerSheet({
  required String title,
  required List<String> options,
  required String current,
  required IconData icon,
  required ValueChanged<String> onSelect,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: FF.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: FF.textSec.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Icon(icon, color: FF.accent, size: 20),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  color: FF.textPri, fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        ...options.map((opt) {
          final selected = opt == current;
          return GestureDetector(
            onTap: () {
              onSelect(opt);
              Navigator.pop(context);
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: selected
                    ? FF.accent.withOpacity(0.12)
                    : FF.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? FF.accent : FF.divider,
                ),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(opt,
                      style: TextStyle(
                        color: selected ? FF.accent : FF.textPri,
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      )),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded,
                      color: FF.accent, size: 20),
              ]),
            ),
          );
        }),
      ]),
    ),
  );
}

  Widget _buildLogoutBtn(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final should = await _showLogoutDialog(context);
          if (should && context.mounted) {
            await AuthService.firebase().Logout();
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/login', (_) => false);
          }
        },
        icon: Icon(Icons.logout_rounded, color: FF.danger, size: 18),
        label: Text(LocalizationService.t('log_out'),
            style: TextStyle(
                color: FF.danger, fontWeight: FontWeight.w600, fontSize: 15)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: FF.danger),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<bool> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: FF.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: FF.divider),
        ),
        title: Text('Log out',
            style: TextStyle(color: FF.textPri, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to log out?',
            style: TextStyle(color: FF.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel',
                style: TextStyle(color: FF.textSec)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FF.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    ).then((v) => v ?? false);
  }
}