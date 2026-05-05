import 'dart:async';
import 'dart:math' as math;
import 'package:FocusFlow/services/timer_settings_service.dart';
import 'package:FocusFlow/services/platform/stats_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:FocusFlow/views/app_shell.dart';
import 'package:FocusFlow/views/timer_settings_view.dart';
import 'package:FocusFlow/services/auth/auth_service.dart';
import 'package:FocusFlow/services/database/database_service.dart';
import 'package:FocusFlow/services/settings_service.dart';
import 'package:FocusFlow/services/localization_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';

class FocusView extends StatefulWidget {
  const FocusView({super.key});
  @override
  State<FocusView> createState() => _FocusViewState();
}

class _FocusViewState extends State<FocusView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  // ── Method channel ─────────────────────────────────────────────────────────
  static const _lockChannel = MethodChannel('com.example.FocusFlow/lockTask');
  Future<void> _startAppLock() async {
    focusTimerRunning.value = true;
    try { await _lockChannel.invokeMethod('startLockTask'); } catch (_) {}
  }
  Future<void> _stopAppLock() async {
    focusTimerRunning.value = false;
    try { await _lockChannel.invokeMethod('stopLockTask'); } catch (_) {}
  }

  // ── Timer state ────────────────────────────────────────────────────────────
  static const int _defaultMinutes = 25;
  int  _totalSeconds  = _defaultMinutes * 60;
  int  _remainSeconds = _defaultMinutes * 60;
  bool _running       = false;
  int  _sessionsDone  = 0;
  Timer? _timer;
  DateTime? _endTime;
  List<_Mode> _modes = [];
  int _modeIndex = 0;

  // ── PDF state ──────────────────────────────────────────────────────────────
  String? _pdfPath;
  String? _pdfName;
  bool _pdfOpen = false;
  final PdfViewerController _pdfController = PdfViewerController();

  // ── Existing methods (unchanged) ───────────────────────────────────────────
  void _refreshsettings() {
    final settings = TimerSettingsService.instance.settings;
    setState(() {
      _modes = [
        _Mode(LocalizationService.t('pomorodo'), settings.focusMinutes, FF.accent),
        _Mode(LocalizationService.t('short_break'), settings.shortBreakMinutes, FF.success),
        _Mode(LocalizationService.t('long_break'), settings.longBreakMinutes, FF.purple),
      ];
      _totalSeconds = _modes[_modeIndex].minutes * 60;
      if (!_running) _remainSeconds = _totalSeconds;
    });
  }

  late AnimationController _pulseController;
  String? get _uid => AuthService.firebase().currentUser?.id;
  final _db = DatabaseService.firebase();
  int _savedFocusMinutes  = 0;
  int _savedTotalSessions = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadStats();
    await TimerSettingsService.instance.load();
    if (mounted) _refreshsettings();
  }

  Future<void> _loadStats() async {
    if (_uid == null) return;
    final profile = await _db.getUserProfile(ownerUserId: _uid!);
    if (mounted) {
      setState(() {
        _savedFocusMinutes  = (profile['focusHours'] ?? 0) * 60;
        _savedTotalSessions =  profile['totalSessions'] ?? 0;
        _sessionsDone       = _savedTotalSessions;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _stopAppLock();
    _pulseController.dispose();
    _pdfController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _running && _endTime != null) {
      final remaining = _endTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _timer?.cancel();
        _stopAppLock();
        setState(() { _running = false; _remainSeconds = 0; });
        if (_modeIndex == 0) _onPomodoroComplete();
      } else {
        setState(() => _remainSeconds = remaining);
      }
    }
  }

  void _selectMode(int i) {
    _timer?.cancel();
    _stopAppLock();
    setState(() {
      _modeIndex     = i;
      _running       = false;
      _endTime       = null;
      _totalSeconds  = _modes[i].minutes * 60;
      _remainSeconds = _modes[i].minutes * 60;
    });
  }

  void _toggleTimer() {
    if (_running) {
      _timer?.cancel();
      _stopAppLock();
      setState(() { _running = false; _endTime = null; });
    } else {
      final end = DateTime.now().add(Duration(seconds: _remainSeconds));
      setState(() { _running = true; _endTime = end; });
      _startAppLock();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final remaining = _endTime!.difference(DateTime.now()).inSeconds;
        if (remaining <= 0) {
          _timer?.cancel();
          _stopAppLock();
          setState(() { _running = false; _remainSeconds = 0; _endTime = null; });
          if (_modeIndex == 0) _onPomodoroComplete();
        } else {
          setState(() => _remainSeconds = remaining);
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
    await StatsService.recordSession(focusMinutes: _modes[0].minutes);
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
    _stopAppLock();
    setState(() { _running = false; _endTime = null; _remainSeconds = _totalSeconds; });
  }

  String get _timeLabel {
    final m = _remainSeconds ~/ 60;
    final s = _remainSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress  => 1 - (_remainSeconds / _totalSeconds);
  Color  get _modeColor => _modes[_modeIndex].color;

  // ── PDF picker ─────────────────────────────────────────────────────────────
  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pdfPath = result.files.single.path!;
        _pdfName = result.files.single.name;
        _pdfOpen = true; // open immediately after picking
      });
    }
  }

  void _openPdf()  => setState(() => _pdfOpen = true);
  void _closePdf() => setState(() => _pdfOpen = false);

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_modes.isEmpty) {
      return Scaffold(
        backgroundColor: FF.bg,
        body: Center(child: CircularProgressIndicator(color: FF.accent)),
      );
    }

    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        return PopScope(
          canPop: !_running && !_pdfOpen, // also block back when PDF is open
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _pdfOpen) {
              // Back pressed while PDF open — close PDF instead
              _closePdf();
              return;
            }
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.all(12),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: Stack(
            children: [
              // ── Main timer scaffold ────────────────────────────────────────
              Scaffold(
                backgroundColor: FF.bg,
                appBar: AppBar(
                  backgroundColor: FF.bg,
                  elevation: 0,
                  title: Text(
                    LocalizationService.t('focus'),
                    style: TextStyle(color: FF.textPri, fontWeight: FontWeight.w700, fontSize: 22),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                              style: TextStyle(color: FF.textPri, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ]),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.settings_outlined,
                        color: _running ? FF.textSec.withOpacity(0.35) : FF.textSec,
                      ),
                      onPressed: _running ? null : () async {
                        await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const TimerSettingsView()));
                        _refreshsettings();
                      },
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
                    _buildPdfCard(),   // ← new
                    const SizedBox(height: 16),
                    _buildTipCard(),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),

              // ── PDF full-screen overlay ────────────────────────────────────
              if (_pdfOpen && _pdfPath != null)
                _PdfOverlay(
                  path: _pdfPath!,
                  name: _pdfName ?? 'Document',
                  controller: _pdfController,
                  timerLabel: _timeLabel,
                  modeColor: _modeColor,
                  isRunning: _running,
                  onClose: _closePdf,
                ),
            ],
          ),
        );
      },
    );
  }

  // ── PDF card (sits between sessions row and tip card) ──────────────────────
  Widget _buildPdfCard() {
    final hasPdf = _pdfPath != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasPdf ? _modeColor.withOpacity(0.4) : FF.divider),
      ),
      child: hasPdf
          ? Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _modeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.picture_as_pdf_rounded, color: _modeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    _pdfName!,
                    style: TextStyle(color: FF.textPri, fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    LocalizationService.t('tap_to_read'),  // 'Tap to read'
                    style: TextStyle(color: FF.textSec, fontSize: 11),
                  ),
                ]),
              ),
              // Open button
              GestureDetector(
                onTap: _openPdf,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _modeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    LocalizationService.t('read'),  // 'Read'
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Replace PDF button
              GestureDetector(
                onTap: _pickPdf,
                child: Icon(Icons.swap_horiz_rounded, color: FF.textSec, size: 20),
              ),
            ])
          : GestureDetector(
              onTap: _pickPdf,
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: FF.divider,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.upload_file_rounded, color: FF.textSec, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    LocalizationService.t('Read from any file'),  // 'Add reading material'
                    style: TextStyle(color: FF.textPri, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    LocalizationService.t('open pdf during session'),  // 'Open a PDF during your session'
                    style: TextStyle(color: FF.textSec, fontSize: 11),
                  ),
                ]),
              ]),
            ),
    );
  }

  // ── Unchanged widgets ──────────────────────────────────────────────────────

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
              onTap: _running ? null : () => _selectMode(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? _modes[i].color.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: sel ? Border.all(color: _modes[i].color.withOpacity(0.5)) : null,
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
            width: 240, height: 240,
            child: Stack(alignment: Alignment.center, children: [
              if (_running)
                Container(
                  width: 240, height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _modeColor.withOpacity(0.15), blurRadius: 40, spreadRadius: 10)],
                  ),
                ),
              CustomPaint(
                size: const Size(240, 240),
                painter: _RingPainter(progress: _progress, color: _modeColor, trackColor: FF.card),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_timeLabel, style: TextStyle(color: FF.textPri, fontSize: 52, fontWeight: FontWeight.w800, letterSpacing: -2)),
                Text(_modes[_modeIndex].name, style: TextStyle(color: FF.textSec, fontSize: 14, fontWeight: FontWeight.w500)),
                if (_running)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.lock_rounded, color: _modeColor.withOpacity(0.8), size: 12),
                      const SizedBox(width: 4),
                      Text(LocalizationService.t('focus_lock_on'),
                          style: TextStyle(color: _modeColor.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500)),
                    ]),
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
      _CircleBtn(icon: Icons.replay_rounded, size: 52, bg: FF.card, color: FF.textSec, onTap: _reset),
      const SizedBox(width: 20),
      _CircleBtn(
        icon: _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 72, bg: _modeColor, color: Colors.white, onTap: _toggleTimer,
      ),
      const SizedBox(width: 20),
      _CircleBtn(
        icon: Icons.skip_next_rounded, size: 52, bg: FF.card,
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
          width: 14, height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? _modeColor : FF.card,
            border: Border.all(color: done ? _modeColor : FF.divider, width: 2),
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
      child: Text(tips[_sessionsDone % tips.length],
          style: TextStyle(color: FF.textSec, fontSize: 13, height: 1.5)),
    );
  }
}

// ── PDF full-screen overlay widget ────────────────────────────────────────────
class _PdfOverlay extends StatelessWidget {
  final String path;
  final String name;
  final PdfViewerController controller;
  final String timerLabel;
  final Color modeColor;
  final bool isRunning;
  final VoidCallback onClose;

  const _PdfOverlay({
    required this.path,
    required this.name,
    required this.controller,
    required this.timerLabel,
    required this.modeColor,
    required this.isRunning,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FF.bg,
      child: Column(children: [
        // ── Top bar ──────────────────────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: FF.bg,
              border: Border(bottom: BorderSide(color: FF.divider)),
            ),
            child: Row(children: [
              // Back to timer
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: FF.textPri),
                onPressed: onClose,
                tooltip: 'Back to timer',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(color: FF.textPri, fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Live timer pill — always visible while reading
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isRunning ? modeColor.withOpacity(0.15) : FF.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isRunning ? modeColor.withOpacity(0.5) : FF.divider,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isRunning) ...[
                    Icon(Icons.timer_rounded, color: modeColor, size: 13),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    timerLabel,
                    style: TextStyle(
                      color: isRunning ? modeColor : FF.textSec,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
            ]),
          ),
        ),

        // ── PDF viewer ───────────────────────────────────────────────────────
        Expanded(
          child: SfPdfViewer.file(
            File(path),
            controller: controller,
            pageLayoutMode: PdfPageLayoutMode.continuous,
            scrollDirection: PdfScrollDirection.vertical,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            enableDoubleTapZooming: true,
            onDocumentLoadFailed: (details) {
              // Show error inside the viewer area
            },
          ),
        ),
      ]),
    );
  }
}

// ── Helpers (unchanged) ───────────────────────────────────────────────────────

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
    required this.icon, required this.size,
    required this.bg, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: Icon(icon, color: color, size: size * 0.44),
    ),
  );
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color, trackColor;
  const _RingPainter({required this.progress, required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width - 16) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false,
      Paint()..color = trackColor..strokeWidth = 10..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    if (progress > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false,
        Paint()..color = color..strokeWidth = 10..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}