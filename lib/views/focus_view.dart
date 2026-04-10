import 'dart:async';
import 'dart:math' as math;
import 'package:FocusFlow/services/platform/stats_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:FocusFlow/views/app_shell.dart';
import 'package:FocusFlow/views/timer_settings_view.dart';
import 'package:FocusFlow/services/auth/auth_service.dart';
import 'package:FocusFlow/services/database/database_service.dart';
import 'package:FocusFlow/services/settings_service.dart';
import 'package:FocusFlow/services/localization_service.dart';

class FocusView extends StatefulWidget {
  const FocusView({super.key});
  @override
  State<FocusView> createState() => _FocusViewState();
}

class _FocusViewState extends State<FocusView>
    with SingleTickerProviderStateMixin {

  // ── Method channel to native Android lock task ────────────────────────────
  static const _lockChannel = MethodChannel('com.example.FocusFlow/lockTask');

  Future<void> _startAppLock() async {
    focusTimerRunning.value = true;
    try {
      await _lockChannel.invokeMethod('startLockTask');
    } catch (_) {
      // Lock task may not be available on all devices — fail silently.
      // The in-app guards (PopScope + tab block) still apply.
    }
  }

  Future<void> _stopAppLock() async {
    focusTimerRunning.value = false;
    try {
      await _lockChannel.invokeMethod('stopLockTask');
    } catch (_) {
      // Fail silently.
    }
  }

  // ── Timer state ────────────────────────────────────────────────────────────
  static const int _defaultMinutes = 25;
  int  _totalSeconds  = _defaultMinutes * 60;
  int  _remainSeconds = _defaultMinutes * 60;
  bool _running       = false;
  int  _sessionsDone  = 0;
  Timer? _timer;

  final List<_Mode> _modes = [
    _Mode(LocalizationService.t('pomodoro'),    25, FF.accent),
    _Mode(LocalizationService.t('short_break'),  5, FF.success),
    _Mode(LocalizationService.t('long_break'),  15, FF.purple),
  ];
  int _modeIndex = 0;

  late AnimationController _pulseController;

  String? get _uid => AuthService.firebase().currentUser?.id;
  final _db = DatabaseService.firebase();

  int _savedFocusMinutes  = 0;
  int _savedTotalSessions = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (_uid == null) return;
    final profile = await _db.getUserProfile(ownerUserId: _uid!);
    if (mounted) {
      setState(() {
        _savedFocusMinutes  = (profile['focusHours']   ?? 0) * 60;
        _savedTotalSessions =  profile['totalSessions'] ?? 0;
        _sessionsDone       = _savedTotalSessions;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopAppLock();           // always release lock on dispose
    _pulseController.dispose();
    super.dispose();
  }

  // ── Timer controls ─────────────────────────────────────────────────────────

  void _selectMode(int i) {
    _timer?.cancel();
    _stopAppLock();           // release lock when mode changes
    setState(() {
      _modeIndex     = i;
      _running       = false;
      _totalSeconds  = _modes[i].minutes * 60;
      _remainSeconds = _modes[i].minutes * 60;
    });
  }

  void _toggleTimer() {
    if (_running) {
      _timer?.cancel();
      _stopAppLock();         // release lock on pause
      setState(() => _running = false);
    } else {
      setState(() => _running = true);
      _startAppLock();        // acquire lock on start
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remainSeconds <= 1) {
          _timer?.cancel();
          _stopAppLock();     // release lock on natural completion
          setState(() {
            _running       = false;
            _remainSeconds = 0;
          });
          if (_modeIndex == 0) _onPomodoroComplete();
        } else {
          setState(() => _remainSeconds--);
        }
      });
    }
  }

  Future<void> _onPomodoroComplete() async {
    setState(() => _sessionsDone++);
    if (_uid == null) return;
    await _db.saveTimerSession(
      ownerUserId:  _uid!,
      focusMinutes: _modes[0].minutes,
      breakMinutes: _modes[1].minutes,
    );
    // ── NEW: record XP + update stats + check badges ──
    await StatsService.recordSession(focusMinutes: _modes[0].minutes);
    // ─────────────────────────────────────────────────
    if (mounted) _showCompletionSnackbar(_modes[0].minutes);
  }

  void _showCompletionSnackbar(int minutes) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Text('$minutes ${LocalizationService.t('session_saved')}'),
        ]),
        backgroundColor: FF.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _reset() {
    _timer?.cancel();
    _stopAppLock();           // release lock on reset
    setState(() {
      _running       = false;
      _remainSeconds = _totalSeconds;
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _timeLabel {
    final m = _remainSeconds ~/ 60;
    final s = _remainSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress  => 1 - (_remainSeconds / _totalSeconds);
  Color  get _modeColor => _modes[_modeIndex].color;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        return PopScope(
          // Block Android back-button / predictive-back swipe while running
          canPop: !_running,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _running) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(children: [
                    const Icon(Icons.lock_clock, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(LocalizationService.t('stop_timer_before_leaving')),
                  ]),
                  backgroundColor: FF.danger,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.all(12),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: Scaffold(
            backgroundColor: FF.bg,
            appBar: AppBar(
              backgroundColor: FF.bg,
              elevation: 0,
              title: Text(
                LocalizationService.t('focus'),
                style: TextStyle(
                    color: FF.textPri, fontWeight: FontWeight.w700, fontSize: 22),
              ),
              actions: [
                // Sessions counter
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: FF.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: FF.divider),
                      ),
                      child: Row(children: [
                        Icon(Icons.bolt, color: FF.warning, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$_sessionsDone ${LocalizationService.t('sessions')}',
                          style: TextStyle(
                              color: FF.textPri,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ),
                ),
                // Settings — disabled while timer is running
                IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color: _running ? FF.textSec.withOpacity(0.35) : FF.textSec,
                  ),
                  onPressed: _running
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TimerSettingsView()),
                          ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(children: [
                _buildModeChips(),
                const SizedBox(height: 40),
                _buildTimerRing(),
                const SizedBox(height: 40),
                _buildControls(),
                const SizedBox(height: 36),
                _buildSessionsRow(),
                const SizedBox(height: 28),
                _buildTipCard(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeChips() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FF.divider),
      ),
      child: Row(
        children: List.generate(_modes.length, (i) {
          final sel = i == _modeIndex;
          return Expanded(
            child: GestureDetector(
              // Disable mode switching while timer is running
              onTap: _running ? null : () => _selectMode(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? _modes[i].color.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: sel
                      ? Border.all(color: _modes[i].color.withOpacity(0.5))
                      : null,
                ),
                child: Opacity(
                  opacity: (_running && !sel) ? 0.35 : 1.0,
                  child: Text(
                    _modes[i].name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: sel ? _modes[i].color : FF.textSec,
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTimerRing() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        final pulse = _running ? 1.0 + _pulseController.value * 0.03 : 1.0;
        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: 240,
            height: 240,
            child: Stack(alignment: Alignment.center, children: [
              if (_running)
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _modeColor.withOpacity(0.15),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              CustomPaint(
                size: const Size(240, 240),
                painter: _RingPainter(
                  progress: _progress,
                  color: _modeColor,
                  trackColor: FF.card,
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  _timeLabel,
                  style: TextStyle(
                    color: FF.textPri,
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                  ),
                ),
                Text(
                  _modes[_modeIndex].name,
                  style: TextStyle(
                    color: FF.textSec,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_running)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded,
                            color: _modeColor.withOpacity(0.8), size: 12),
                        const SizedBox(width: 4),
                        Text(
                          LocalizationService.t('focus_lock_on'),
                          style: TextStyle(
                            color: _modeColor.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _CircleBtn(
        icon: Icons.replay_rounded,
        size: 52,
        bg: FF.card,
        color: FF.textSec,
        onTap: _reset,
      ),
      const SizedBox(width: 20),
      _CircleBtn(
        icon: _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 72,
        bg: _modeColor,
        color: Colors.white,
        onTap: _toggleTimer,
      ),
      const SizedBox(width: 20),
      _CircleBtn(
        icon: Icons.skip_next_rounded,
        size: 52,
        bg: FF.card,
        // Dim skip button while running — skipping clears the lock
        color: _running ? FF.textSec.withOpacity(0.35) : FF.textSec,
        onTap: () => _selectMode((_modeIndex + 1) % _modes.length),
      ),
    ]);
  }

  Widget _buildSessionsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final done = i < _sessionsDone % 4;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? _modeColor : FF.card,
            border:
                Border.all(color: done ? _modeColor : FF.divider, width: 2),
          ),
        );
      }),
    );
  }

  Widget _buildTipCard() {
    final tips = [
      LocalizationService.t('tip1'),
      LocalizationService.t('tip2'),
      LocalizationService.t('tip3'),
      LocalizationService.t('tip4'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FF.divider),
      ),
      child: Text(
        tips[_sessionsDone % tips.length],
        style: TextStyle(color: FF.textSec, fontSize: 13, height: 1.5),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Mode {
  final String name;
  final int minutes;
  final Color color;
  const _Mode(this.name, this.minutes, this.color);
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color bg, color;
  final VoidCallback onTap;
  const _CircleBtn({
    required this.icon,
    required this.size,
    required this.bg,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
          child: Icon(icon, color: color, size: size * 0.44),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color, trackColor;
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width  / 2;
    final cy     = size.height / 2;
    final radius = (size.width - 16) / 2;
    final rect   = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    canvas.drawArc(
      rect, -math.pi / 2, 2 * math.pi, false,
      Paint()
        ..color      = trackColor
        ..strokeWidth = 10
        ..style      = PaintingStyle.stroke
        ..strokeCap  = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawArc(
        rect, -math.pi / 2, 2 * math.pi * progress, false,
        Paint()
          ..color      = color
          ..strokeWidth = 10
          ..style      = PaintingStyle.stroke
          ..strokeCap  = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}