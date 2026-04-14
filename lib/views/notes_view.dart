import 'package:FocusFlow/views/progress_view.dart';
import 'package:flutter/material.dart';
import 'package:FocusFlow/enums/menu_action.dart';
import 'package:FocusFlow/services/platform/stats_fetch_service.dart';
import 'package:FocusFlow/services/weekly_stats_service.dart';
import 'package:FocusFlow/services/auth/auth_service.dart';
import 'package:FocusFlow/views/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
//  Colour palette & text styles
// ─────────────────────────────────────────────
class FocusFlowTheme {
  static Color get background => FF.bg;
  static Color get surface => FF.surface;
  static Color get cardBg => FF.card;
  static Color get accent => FF.accent;
  static Color get accentSoft => FF.accentSoft;
  static Color get success => FF.success;
  static Color get textPrimary => FF.textPri;
  static Color get textSecondary => FF.textSec;
  static Color get divider => FF.divider;
}

// ─────────────────────────────────────────────
//  Main widget
// ─────────────────────────────────────────────
class NotesView extends StatefulWidget {
  /// Set to true when used inside AppShell so the standalone bottom nav is hidden.
  final bool embedded;
  const NotesView({super.key, this.embedded = false});

  @override
  State<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> with TickerProviderStateMixin {
  String _lcSolved = '0';
  String _cfRating = 'Unrated';
  bool _isStatsLoading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Sample data – replace with real data from your service
  final List<Map<String, dynamic>> _tasks = [
    {'title': 'Design onboarding flow', 'done': true, 'tag': 'Design'},
    {'title': 'Write unit tests', 'done': false, 'tag': 'Dev'},
    {'title': 'Review pull requests', 'done': false, 'tag': 'Dev'},
    {'title': 'Team standup notes', 'done': true, 'tag': 'Meeting'},
  ];

  final int _focusMinutesToday = 142;
  final int _streakDays = 7;
  final int _sessionsToday = 4;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadCodingStats();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── helpers ─────────────────────────────────
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _fmtMinutes(int mins) => '${mins ~/ 60}h ${mins % 60}m';

  Widget _buildCodingStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FocusFlowTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FocusFlowTheme.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _miniPlatformStat(
                icon: Icons.code_rounded,
                color: const Color(0xFFFFA116),
                label: 'LeetCode',
                value: '$_lcSolved Solved', // Updated
              ),
              // ... divider ...
              _miniPlatformStat(
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF4F8EF7),
                label: 'Codeforces',
                value: _cfRating, // Updated
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniPlatformStat({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: FocusFlowTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: FocusFlowTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── build ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FocusFlowTheme.background,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              _buildGreetingHeader(),
              const SizedBox(height: 24),
              _buildStatsRow(),
              const SizedBox(height: 28),
              _buildStartFocusCard(),
              const SizedBox(height: 28),
              _buildSectionHeader(
                'Today\'s Tasks',
                onSeeAll: () {
                  context.findAncestorStateOfType<AppShellState>()?.jumpToTab(
                    2,
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildTaskList(),
              const SizedBox(height: 28),
              _buildSectionHeader(
                'Coding Progress',
                onSeeAll: () {
                  // Navigate to your progress view
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProgressView()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildCodingStatsCard(),

              const SizedBox(height: 28),
              _buildSectionHeader(
                'Weekly Progress',
                onSeeAll: () {
                  context.findAncestorStateOfType<AppShellState>()?.jumpToTab(
                    5,
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildWeeklyProgress(),
              const SizedBox(height: 28),
              _buildQuickActionsRow(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.embedded ? null : _buildBottomNav(),
      floatingActionButton: widget.embedded ? null : _buildFAB(),
    );
  }

  // ── AppBar ───────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: FocusFlowTheme.background,
      elevation: 0,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: FocusFlowTheme.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.bolt, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'FocusFlow',
            style: TextStyle(
              color: FocusFlowTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
      actions: [
        // Notification bell
        IconButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No new notifications'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: Icon(
            Icons.notifications_outlined,
            color: FocusFlowTheme.textSecondary,
          ),
        ),
        // Avatar + popup menu
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: PopupMenuButton<MenuAction>(
            offset: const Offset(0, 48),
            color: FocusFlowTheme.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: FocusFlowTheme.divider),
            ),
            onSelected: (value) async {
              switch (value) {
                case MenuAction.logout:
                  final shouldLogout = await showLogoutDialog(context);
                  if (shouldLogout && mounted) {
                    AuthService.firebase().Logout();
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<MenuAction>(
                value: MenuAction.logout,
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: FocusFlowTheme.textSecondary,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Log Out',
                      style: TextStyle(color: FocusFlowTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 17,
              backgroundColor: FocusFlowTheme.accentSoft,
              child: Text(
                'U',
                style: TextStyle(
                  color: FocusFlowTheme.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Greeting header ──────────────────────────
  Widget _buildGreetingHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_greeting 👋',
          style: TextStyle(
            color: FocusFlowTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ready to focus?',
          style: TextStyle(
            color: FocusFlowTheme.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  // ── Stats row ────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.timer_outlined,
            label: 'Focus Time',
            value: _fmtMinutes(_focusMinutesToday),
            color: FocusFlowTheme.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_outlined,
            label: 'Day Streak',
            value: '$_streakDays days',
            color: const Color(0xFFFF7043),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline,
            label: 'Sessions',
            value: '$_sessionsToday today',
            color: FocusFlowTheme.success,
          ),
        ),
      ],
    );
  }

  // ── Start Focus card ─────────────────────────
  Widget _buildStartFocusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3A6B), Color(0xFF0F2347)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FocusFlowTheme.accentSoft, width: 1),
        boxShadow: [
          BoxShadow(
            color: FocusFlowTheme.accent.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start Focus Session',
                  style: TextStyle(
                    color: FocusFlowTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '25 min · Pomodoro',
                  style: TextStyle(
                    color: FocusFlowTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    context.findAncestorStateOfType<AppShellState>()?.jumpToTab(
                      1,
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Begin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FocusFlowTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          // Timer ring graphic
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 0.6,
                  strokeWidth: 6,
                  backgroundColor: FocusFlowTheme.accentSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    FocusFlowTheme.accent,
                  ),
                ),
                Text(
                  '25:00',
                  style: TextStyle(
                    color: FocusFlowTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ───────────────────────────
  Widget _buildSectionHeader(String title, {required VoidCallback onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: FocusFlowTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            'See all',
            style: TextStyle(
              color: FocusFlowTheme.accent,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ── Task list ────────────────────────────────
  Widget _buildTaskList() {
    return Column(
      children: _tasks.map((task) => _TaskTile(task: task)).toList(),
    );
  }

  // ── Weekly progress ──────────────────────────
  Widget _buildWeeklyProgress() {
    return FutureBuilder(
      future: WeeklyStatsService.fetchCurrentWeek(),
      builder: (context, snapshot) {
        final data =
            snapshot.data ??
            List.generate(
              7,
              (i) => DayStats(
                label: ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                minutes: 0,
                isToday: i == DateTime.now().weekday - 1,
              ),
            );
        final maxMins = data
            .map((d) => d.minutes)
            .fold(1, (a, b) => a > b ? a : b);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FocusFlowTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FocusFlowTheme.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final d = data[i];
              final height = d.minutes == 0 ? 4.0 : (d.minutes / maxMins) * 72;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: Duration(milliseconds: 400 + i * 60),
                        curve: Curves.easeOut,
                        height: height,
                        decoration: BoxDecoration(
                          color: d.isToday
                              ? FocusFlowTheme.accent
                              : FocusFlowTheme.accentSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d.label,
                        style: TextStyle(
                          color: d.isToday
                              ? FocusFlowTheme.accent
                              : FocusFlowTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: d.isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ── Quick actions ────────────────────────────
  Widget _buildQuickActionsRow() {
    final actions = [
      {'icon': Icons.note_alt_outlined, 'label': 'Notes', 'tab': 0},
      {'icon': Icons.bar_chart_rounded, 'label': 'Stats', 'tab': 5},
      {'icon': Icons.tune_rounded, 'label': 'Settings', 'tab': 5},
      {'icon': Icons.auto_awesome_rounded, 'label': 'AI', 'tab': 4},
    ];
    return Row(
      children: actions.map((a) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _QuickActionButton(
              icon: a['icon'] as IconData,
              label: a['label'] as String,
              onTap: () {
                context.findAncestorStateOfType<AppShellState>()?.jumpToTab(
                  a['tab'] as int,
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Bottom nav ───────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: FocusFlowTheme.surface,
        border: Border(top: BorderSide(color: FocusFlowTheme.divider)),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: FocusFlowTheme.accent,
        unselectedItemColor: FocusFlowTheme.textSecondary,
        currentIndex: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 11),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_outlined),
            label: 'Focus',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt_outlined),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ── FAB ──────────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () {
        context.findAncestorStateOfType<AppShellState>()?.jumpToTab(2);
      },
      backgroundColor: FocusFlowTheme.accent,
      foregroundColor: Colors.white,
      elevation: 4,
      child: Icon(Icons.add_rounded),
    );
  }

Future<void> _loadCodingStats() async {
  final prefs = await SharedPreferences.getInstance();
  final lcUser = prefs.getString('lc_username') ?? '';
  final cfUser = prefs.getString('cf_handle') ?? '';

  // If no usernames are set, stop loading immediately
  if (lcUser.isEmpty && cfUser.isEmpty) {
    if (mounted) setState(() => _isStatsLoading = false);
    return;
  }

  // Set loading to true at the start
  if (mounted) setState(() => _isStatsLoading = true);

  try {
    // Run both requests in parallel. If one fails, the other can still succeed.
    final results = await Future.wait([
      lcUser.isNotEmpty 
          ? StatsFetchService.fetchLeetCode(lcUser) 
          : Future.value(null),
      cfUser.isNotEmpty 
          ? StatsFetchService.fetchCodeforces(cfUser) 
          : Future.value(null),
    ]).timeout(const Duration(seconds: 12)); // Slightly longer than service timeout

    if (mounted) {
      setState(() {
        final lcData = results[0];
        final cfData = results[1];

        if (lcData != null) {
          _lcSolved = lcData['totalSolved']?.toString() ?? '0';
        }
        if (cfData != null) {
          _cfRating = cfData['rating']?.toString() ?? 'Unrated';
        }
      });
    }
  } catch (e) {
    debugPrint('Error in _loadCodingStats: $e');
    // On error, the variables keep their default values ('0' and 'Unrated')
  } finally {
    // Ensure loading is set to false no matter what happens
    if (mounted) {
      setState(() => _isStatsLoading = false);
    }
  }
}
}

// ─────────────────────────────────────────────
//  Reusable sub-widgets
// ─────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FocusFlowTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FocusFlowTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: FocusFlowTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: FocusFlowTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────

class _TaskTile extends StatefulWidget {
  final Map<String, dynamic> task;
  const _TaskTile({required this.task});

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  late bool _done;

  @override
  void initState() {
    super.initState();
    _done = widget.task['done'] as bool;
  }

  Color _tagColor(String tag) {
    switch (tag) {
      case 'Design':
        return const Color(0xFFB06EF5);
      case 'Dev':
        return FocusFlowTheme.accent;
      case 'Meeting':
        return const Color(0xFFFF7043);
      default:
        return FocusFlowTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: FocusFlowTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FocusFlowTheme.divider),
      ),
      child: Row(
        children: [
          // Checkbox
          GestureDetector(
            onTap: () => setState(() => _done = !_done),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _done ? FocusFlowTheme.accent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _done
                      ? FocusFlowTheme.accent
                      : FocusFlowTheme.textSecondary,
                  width: 2,
                ),
              ),
              child: _done
                  ? Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          // Title
          Expanded(
            child: Text(
              widget.task['title'] as String,
              style: TextStyle(
                color: _done
                    ? FocusFlowTheme.textSecondary
                    : FocusFlowTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                decoration: _done ? TextDecoration.lineThrough : null,
                decorationColor: FocusFlowTheme.textSecondary,
              ),
            ),
          ),
          // Tag badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _tagColor(widget.task['tag'] as String).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.task['tag'] as String,
              style: TextStyle(
                color: _tagColor(widget.task['tag'] as String),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: FocusFlowTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FocusFlowTheme.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: FocusFlowTheme.accent, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: FocusFlowTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showLogoutDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: FocusFlowTheme.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: FocusFlowTheme.divider),
      ),
      title: Text(
        'Log out',
        style: TextStyle(
          color: FocusFlowTheme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        'Are you sure you want to log out?',
        style: TextStyle(color: FocusFlowTheme.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(color: FocusFlowTheme.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text('Log out'),
        ),
      ],
    ),
  ).then((v) => v ?? false);
}
