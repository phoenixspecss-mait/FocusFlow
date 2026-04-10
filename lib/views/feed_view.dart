import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:FocusFlow/views/app_shell.dart';
import 'package:FocusFlow/views/video_player_view.dart';

// ── Global notifier: increments every time a focus session completes ─────────
// focus_view.dart should call: feedUnlockNotifier.value++; when session ends
final ValueNotifier<int> feedUnlockNotifier = ValueNotifier(0);

// ── Video data model ──────────────────────────────────────────────────────────
class _Video {
  final String id;        // YouTube video ID
  final String title;
  final String person;
  final String tag;       // e.g. "Mindset", "Discipline"
  final Color tagColor;

  const _Video({
    required this.id,
    required this.title,
    required this.person,
    required this.tag,
    required this.tagColor,
  });

  String get thumbnailUrl => 'https://img.youtube.com/vi/$id/mqdefault.jpg';
  String get youtubeUrl   => 'https://www.youtube.com/watch?v=$id';
}

// ── Curated motivational video list ──────────────────────────────────────────
const List<_Video> _videos = [
  _Video(
    id: 'w-0H7G5XavM',
    title: 'The Most Eye Opening 14 Minutes Of Your Life',
    person: 'David Goggins',
    tag: 'Mindset',
    tagColor: Color(0xFFFF5C5C),
  ),
  _Video(
    id: 'J0Ep6ZlqA9k',
    title: "The Most Eye-Opening 20 Minutes You'll Ever Watch",
    person: 'David Goggins',
    tag: 'Motivation',
    tagColor: Color(0xFFFF5C5C),
  ),
  _Video(
    id: '8k5QIN8zsxc',
    title: 'The Most Eye Opening 10 Minutes Of Your Life',
    person: 'David Goggins',
    tag: 'Discipline',
    tagColor: Color(0xFFFF5C5C),
  ),
  _Video(
    id: 'oyOtMNRsvsw',
    title: 'The Most Eye-Opening 20 Minutes Of Your Life',
    person: 'David Goggins',
    tag: 'Mental Toughness',
    tagColor: Color(0xFFFF5C5C),
  ),
  _Video(
    id: '0V_g1zNhbyA',
    title: '10 Minutes Of Cristiano Ronaldo Giving Life Changing Advice',
    person: 'Cristiano Ronaldo',
    tag: 'Advice',
    tagColor: Color(0xFF4F8EF7),
  ),
  _Video(
    id: 'kBJwE9h2qNA',
    title: 'These Powerful Speeches Will Change Your Life',
    person: 'Cristiano Ronaldo',
    tag: 'Inspiration',
    tagColor: Color(0xFF4F8EF7),
  ),
  _Video(
    id: 'miQe5-rE5ZY',
    title: "Cristiano Ronaldo's Greatest Speech",
    person: 'Cristiano Ronaldo',
    tag: 'Focus',
    tagColor: Color(0xFF4F8EF7),
  ),
  _Video(
    id: '8MqkV0BO-a8',
    title: '"My son is a WEAK" The reality of new generation',
    person: 'Cristiano Ronaldo',
    tag: 'Discipline',
    tagColor: Color(0xFF4F8EF7),
  ),
  _Video(
    id: 'afJ6cURJVmY',
    title: "Christiano Ronaldo's Life Advice Will Leave You Speechless",
    person: 'Cristiano Ronaldo',
    tag: 'Mentality',
    tagColor: Color(0xFF4F8EF7),
  ),
  _Video(
    id: 'JV8mIfjwPeM',
    title: 'THE 4 MINUTE SPEECH THAT WILL CHANGE YOUR LIFE',
    person: 'David Goggins',
    tag: 'Motivation',
    tagColor: Color(0xFFFF5C5C),
  ),
  _Video(
    id: '4JRrAe-xz44',
    title: 'BE CONSISTENT',
    person: 'David Goggins',
    tag: 'Consistency',
    tagColor: Color(0xFFFF5C5C),
  ),
  _Video(
    id: 'MY_0YKmEG0A',
    title: 'To Grow, You Must Suffer',
    person: 'David Goggins',
    tag: 'Growth',
    tagColor: Color(0xFFFF5C5C),
  ),
  _Video(
    id: 'TLKxdTmk-zc',
    title: 'The Most Eye Opening 10 Minutes Of Your Life',
    person: 'David Goggins',
    tag: 'Life Changing',
    tagColor: Color(0xFFFF5C5C),
  ),
];

// ── Prefs keys ────────────────────────────────────────────────────────────────
const _kSecondsRemaining = 'feed_seconds_remaining';
const _kLastDate         = 'feed_last_date';
const _kUnlockExpiry     = 'feed_unlock_expiry';
const _kDailyBudget      = 1800; // 30 minutes in seconds

class FeedView extends StatefulWidget {
  const FeedView({super.key});

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> with WidgetsBindingObserver {
  int _secondsRemaining = _kDailyBudget;
  bool _locked          = false;
  bool _loading         = true;
  Timer? _countdown;
  int _lastUnlockCount  = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastUnlockCount = feedUnlockNotifier.value;
    feedUnlockNotifier.addListener(_onFocusSessionCompleted);
    _initTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    feedUnlockNotifier.removeListener(_onFocusSessionCompleted);
    _countdown?.cancel();
    super.dispose();
  }

  // Pause countdown when app goes to background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _countdown?.cancel();
      _saveState();
    } else if (state == AppLifecycleState.resumed) {
      _initTimer();
    }
  }

  // Called whenever a focus session completes
  void _onFocusSessionCompleted() {
    if (feedUnlockNotifier.value > _lastUnlockCount) {
      _lastUnlockCount = feedUnlockNotifier.value;
      _unlockFeedAfterSession();
    }
  }

  Future<void> _initTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString(_kLastDate) ?? '';

    // Reset daily budget at midnight
    if (savedDate != today) {
      await prefs.setString(_kLastDate, today);
      await prefs.setInt(_kSecondsRemaining, _kDailyBudget);
    }

    // Check if feed is unlocked via study session bonus
    final unlockExpiry = prefs.getInt(_kUnlockExpiry) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    int remaining = prefs.getInt(_kSecondsRemaining) ?? _kDailyBudget;

    // If within unlock window, add bonus time
    if (unlockExpiry > nowMs) {
      final bonusSeconds = ((unlockExpiry - nowMs) / 1000).round();
      remaining = remaining + bonusSeconds;
      if (remaining > _kDailyBudget * 2) remaining = _kDailyBudget * 2;
    }

    if (mounted) {
      setState(() {
        _secondsRemaining = remaining;
        _locked = remaining <= 0;
        _loading = false;
      });
    }

    if (!_locked) _startCountdown();
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _locked = true;
          _countdown?.cancel();
          _saveState();
        }
      });
      // Save every 10 seconds to avoid too many writes
      if (_secondsRemaining % 10 == 0) _saveState();
    });
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSecondsRemaining, _secondsRemaining);
  }

  // Called when focus session completes — unlocks feed for 30 more minutes
  Future<void> _unlockFeedAfterSession() async {
    final prefs = await SharedPreferences.getInstance();
    final bonusSeconds = 1800; // 30 minutes bonus
    final expiryMs = DateTime.now().millisecondsSinceEpoch + (bonusSeconds * 1000);
    await prefs.setInt(_kUnlockExpiry, expiryMs);
    await prefs.setInt(_kSecondsRemaining, bonusSeconds);

    if (mounted) {
      setState(() {
        _secondsRemaining = bonusSeconds;
        _locked = false;
      });
      _startCountdown();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.celebration_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Great work! Feed unlocked for 30 minutes 🎉'),
          ]),
          backgroundColor: FF.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _timerColor {
    if (_secondsRemaining > 600) return FF.success;      // > 10 min: green
    if (_secondsRemaining > 180) return FF.warning;      // > 3 min: orange
    return FF.danger;                                     // < 3 min: red
  }

  // Open YouTube link using Android Intent via url_launcher approach
  void _openVideo(_Video video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerView(
          videoId: video.id,
          title: video.title,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: FF.bg,
        body: Center(
            child: CircularProgressIndicator(color: FF.accent)),
      );
    }

    return Scaffold(
      backgroundColor: FF.bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────────────────────
              SliverAppBar(
                backgroundColor: FF.bg,
                floating: true,
                snap: true,
                elevation: 0,
                title: Row(
                  children: [
                    Icon(Icons.video_library_rounded,
                        color: FF.warning, size: 22),
                    SizedBox(width: 8),
                    Text('Motivation Feed',
                        style: TextStyle(
                            color: FF.textPri,
                            fontWeight: FontWeight.w800,
                            fontSize: 18)),
                  ],
                ),
                actions: [
                  // Timer chip
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _timerColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _timerColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_rounded,
                            color: _timerColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _locked ? 'LOCKED' : _formatTime(_secondsRemaining),
                          style: TextStyle(
                            color: _timerColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Timer progress bar ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _locked
                              ? 0
                              : _secondsRemaining / _kDailyBudget,
                          backgroundColor: FF.divider,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_timerColor),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _locked
                            ? '⏰ Time\'s up! Complete a study session to unlock'
                            : '${_formatTime(_secondsRemaining)} of daily feed time remaining',
                        style: TextStyle(
                          color: _locked ? FF.danger : FF.textSec,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Video grid ────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _VideoCard(
                      video: _videos[i],
                      onTap: () => _openVideo(_videos[i]),
                    ),
                    childCount: _videos.length,
                  ),
                ),
              ),
            ],
          ),

          // ── Lock overlay ──────────────────────────────────────────────────
          if (_locked) _LockOverlay(),
        ],
      ),
    );
  }
}

// ── Lock overlay widget ───────────────────────────────────────────────────────

class _LockOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.88),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: FF.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: FF.warning.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: FF.warning.withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lock icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: FF.warning.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: FF.warning.withOpacity(0.4), width: 2),
                  ),
                  child: Icon(Icons.lock_clock_rounded,
                      color: FF.warning, size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  'Timer Active',
                  style: TextStyle(
                    color: FF.textPri,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'The feed is locked while you are focusing to help you stay productive.',
                  style: TextStyle(
                    color: FF.textSec,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Stats row
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: FF.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_rounded,
                          color: FF.accent, size: 16),
                      SizedBox(width: 6),
                      Text('25 min session = 30 min feed',
                          style: TextStyle(
                              color: FF.textSec,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Go study button
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to Focus tab (index 1)
                      // We use the global shell state
                      final shell = context
                          .findAncestorStateOfType<AppShellState>();
                      shell?.jumpToTab(1);
                    },
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
                            'Start Study Session',
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
                Text(
                  'Come back after your session — feed unlocks automatically!',
                  style: TextStyle(color: FF.textSec, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Video card widget ─────────────────────────────────────────────────────────

class _VideoCard extends StatelessWidget {
  final _Video video;
  final VoidCallback onTap;
  const _VideoCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: FF.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FF.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    child: Image.network(
                      video.thumbnailUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          color: FF.surface,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_outline_rounded,
                                color: FF.textSec, size: 52),
                            const SizedBox(height: 8),
                            Text(video.person,
                                style: TextStyle(
                                    color: FF.textSec, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Play button overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_filled_rounded,
                        color: Colors.white,
                        size: 56,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 12)
                        ],
                      ),
                    ),
                  ),
                ),
                // YouTube badge
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.keyboard_arrow_left_rounded,
                            color: FF.accent, size: 16),
                        SizedBox(width: 2),
                        Text('YouTube',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Info section
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Person avatar circle
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              video.tagColor.withOpacity(0.7),
                              video.tagColor,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            video.person[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(video.person,
                                style: TextStyle(
                                    color: FF.textSec,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            Text(
                              video.title,
                              style: TextStyle(
                                color: FF.textPri,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Tag chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: video.tagColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: video.tagColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          video.tag,
                          style: TextStyle(
                            color: video.tagColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
