import 'package:FocusFlow/views/progress_view.dart';
import 'package:flutter/material.dart';
import 'package:FocusFlow/views/focus_view.dart';
import 'package:FocusFlow/views/tasks_view.dart';
import 'package:FocusFlow/views/ai_agent_view.dart';
import 'package:FocusFlow/views/profile_view.dart';
import 'package:FocusFlow/views/notes_view.dart';
import 'package:FocusFlow/views/feed_view.dart';
import 'package:FocusFlow/views/study_buddy_view.dart';
import 'package:FocusFlow/services/settings_service.dart';
import 'package:FocusFlow/services/localization_service.dart';

// Global notifier — true when a Focus timer is actively running
final ValueNotifier<bool> focusTimerRunning = ValueNotifier(false);

// Index of the AI tab — allowed even during focus lock
const int _kAiTabIndex = 4;

// Index of the Study Buddy tab — also allowed during focus lock
const int _kStudyTabIndex = 5;

class FF {
  static bool get _isLight => SettingsService.instance.theme == 'Light';

  static Color get bg         => _isLight ? const Color(0xFFF5F7FA) : const Color(0xFF0D0F14);
  static Color get surface    => _isLight ? const Color(0xFFFFFFFF) : const Color(0xFF161920);
  static Color get card       => _isLight ? const Color(0xFFEDF1F7) : const Color(0xFF1E2128);
  static Color get accent     => const Color(0xFF4F8EF7);
  static Color get accentSoft => _isLight ? const Color(0xFFE1E9F5) : const Color(0xFF2A3F6F);
  static Color get success    => const Color(0xFF3DDC84);
  static Color get warning    => const Color(0xFFFFB547);
  static Color get danger     => const Color(0xFFFF5C5C);
  static Color get purple     => const Color(0xFFB06EF5);
  static Color get textPri    => _isLight ? const Color(0xFF1A1C1E) : const Color(0xFFF0F2F8);
  static Color get textSec    => _isLight ? const Color(0xFF6B7280) : const Color(0xFF8890A4);
  static Color get divider    => _isLight ? const Color(0xFFE5E7EB) : const Color(0xFF252830);
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _showExitWarning = false;
  int _progressRefreshTrigger = 0;

 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listen for focus session completion to unlock feed
    focusTimerRunning.addListener(_onTimerChanged);
  }

  bool _wasRunning = false;

  void _onTimerChanged() {
    final isRunning = focusTimerRunning.value;
    // Detect when timer stops (session completed)
    if (_wasRunning && !isRunning) {
      // Timer just stopped — notify feed that a session completed
      feedUnlockNotifier.value++;
    }
    _wasRunning = isRunning;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    focusTimerRunning.removeListener(_onTimerChanged);
    super.dispose();
  }

  // Public method for FeedView lock overlay to navigate to Focus tab
  void jumpToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (focusTimerRunning.value &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive)) {
      setState(() => _showExitWarning = true);
    }
    if (state == AppLifecycleState.resumed) {
      setState(() => _showExitWarning = false);
    }
  }

  void _handleTabTap(int i) {
    if (focusTimerRunning.value && i != 1 && i != _kAiTabIndex && i != _kStudyTabIndex) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.lock_clock, color: Colors.white),
            SizedBox(width: 10),
            Text('Timer is running! Finish your session first.'),
          ]),
          backgroundColor: FF.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _currentIndex = i);
    setState(() {
    _currentIndex = i;
    if (i == 2) _progressRefreshTrigger++; // Increment to force rebuild
  });
  }

  @override
  Widget build(BuildContext context) {
     final List<Widget> _screens = [
    NotesView(embedded: true),
    FocusView(),
    ProgressView(key: ValueKey(_progressRefreshTrigger)),
    FeedView(),       // ← Replaced HabitsView with FeedView
    AiAgentView(),
    StudyBuddyView(),
    ProfileView(),
    TasksView()
  ];
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        return Stack(
          children: [
            Scaffold(
              backgroundColor: FF.bg,
              body: IndexedStack(index: _currentIndex, children: _screens),
              bottomNavigationBar: ValueListenableBuilder<bool>(
                valueListenable: focusTimerRunning,
                builder: (context, isRunning, _) => _BottomNav(
                  currentIndex: _currentIndex,
                  isLocked: isRunning,
                  onTap: _handleTabTap,
                ),
              ),
            ),
            if (_showExitWarning)
              _FocusExitWarningOverlay(
                onDismiss: () => setState(() => _showExitWarning = false),
              ),
          ],
        );
      },
    );
  }
}

// ── Exit-warning full-screen overlay ──────────────────────────────────────────

class _FocusExitWarningOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  const _FocusExitWarningOverlay({required this.onDismiss});

  @override
  State<_FocusExitWarningOverlay> createState() =>
      _FocusExitWarningOverlayState();
}

class _FocusExitWarningOverlayState extends State<_FocusExitWarningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: FF.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: FF.danger.withOpacity(0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: FF.danger.withOpacity(0.25),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: FF.danger.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: FF.danger.withOpacity(0.4), width: 2),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: FF.danger,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Focus Session Active!',
                    style: TextStyle(
                      color: FF.textPri,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'You tried to leave while your Pomodoro timer is running.\n\nStay focused — you\'re almost there! 💪',
                    style: TextStyle(
                      color: FF.textSec,
                      fontSize: 14,
                      height: 1.55,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: widget.onDismiss,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F8EF7), Color(0xFF3DDC84)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.timer_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Back to Focus',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      focusTimerRunning.value = false;
                      widget.onDismiss();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Stop timer and exit session',
                        style: TextStyle(
                          color: FF.textSec,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                          decorationColor: FF.textSec,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isLocked;
  final ValueChanged<int> onTap;
  const _BottomNav({
    required this.currentIndex,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.home_rounded,                label: LocalizationService.t('home')),
      _NavItem(icon: Icons.timer_rounded,               label: LocalizationService.t('focus')),
      _NavItem(icon: Icons.leaderboard_rounded,            label: LocalizationService.t('Progress')),
      _NavItem(icon: Icons.local_fire_department_rounded, label: LocalizationService.t('feed')),
      _NavItem(icon: Icons.auto_awesome_rounded,        label: LocalizationService.t('ai')),
      _NavItem(icon: Icons.school_rounded,              label: 'Study'),
      _NavItem(icon: Icons.person_rounded,              label: LocalizationService.t('profile')),
    ];

    return Container(
      decoration: BoxDecoration(
        color: FF.surface,
        border: Border(top: BorderSide(color: FF.divider)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final selected  = i == currentIndex;
              final isAiTab   = i == _kAiTabIndex;
              final isStudyTab = i == _kStudyTabIndex;
              final dimmed    = isLocked && i != 1 && !isAiTab && !isStudyTab;
              final aiAllowed = isLocked && isAiTab && !selected;
              final studyAllowed = isLocked && isStudyTab && !selected;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Opacity(
                    opacity: dimmed ? 0.35 : 1.0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? FF.accentSoft
                                : aiAllowed
                                    ? FF.purple.withOpacity(0.18)
                                    : studyAllowed
                                        ? FF.success.withOpacity(0.18)
                                        : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: aiAllowed
                                ? Border.all(
                                    color: FF.purple.withOpacity(0.45))
                                : studyAllowed
                                    ? Border.all(
                                        color: FF.success.withOpacity(0.45))
                                    : null,
                            boxShadow: aiAllowed
                                ? [
                                    BoxShadow(
                                      color: FF.purple.withOpacity(0.3),
                                      blurRadius: 8,
                                    )
                                  ]
                                : studyAllowed
                                    ? [
                                        BoxShadow(
                                          color: FF.success.withOpacity(0.3),
                                          blurRadius: 8,
                                        )
                                      ]
                                    : null,
                          ),
                          child: Icon(items[i].icon,
                              color: selected
                                  ? FF.accent
                                  : aiAllowed
                                      ? FF.purple
                                      : studyAllowed
                                          ? FF.success
                                          : FF.textSec,
                              size: 22),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          aiAllowed
                              ? 'AI ✓'
                              : studyAllowed
                                  ? 'Study ✓'
                                  : items[i].label,
                          style: TextStyle(
                            color: selected
                                ? FF.accent
                                : aiAllowed
                                    ? FF.purple
                                    : studyAllowed
                                        ? FF.success
                                        : FF.textSec,
                            fontSize: 9,
                            fontWeight: (selected || aiAllowed || studyAllowed)
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
