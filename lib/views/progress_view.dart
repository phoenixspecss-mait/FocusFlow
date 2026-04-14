import 'dart:math';
import 'package:flutter/material.dart';
import 'package:FocusFlow/views/app_shell.dart';
import 'package:FocusFlow/services/platform/stats_fetch_service.dart';
import 'package:FocusFlow/services/platform/leetcode_service.dart';
import 'package:FocusFlow/services/platform/github_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Custom Pie Chart Painter ────────────────────────────────────────────────

class _PieSegment {
  final double value;
  final Color color;
  final String label;
  const _PieSegment({required this.value, required this.color, required this.label});
}

class _PiePainter extends CustomPainter {
  final List<_PieSegment> segments;
  final double progress;
  final double holeRatio;

  _PiePainter({required this.segments, required this.progress, this.holeRatio = 0.58});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final holeRadius = radius * holeRatio;

    final total = segments.fold<double>(0, (s, e) => s + e.value);
    if (total == 0) return;

    double startAngle = -pi / 2;
    const gap = 0.025;

    for (final seg in segments) {
      final sweep = (seg.value / total) * 2 * pi * progress - gap;
      if (sweep <= 0) {
        startAngle += (seg.value / total) * 2 * pi * progress;
        continue;
      }

      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(
        center.dx + (holeRadius + 1) * cos(startAngle + gap / 2),
        center.dy + (holeRadius + 1) * sin(startAngle + gap / 2),
      );
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + gap / 2,
        sweep,
        false,
      );
      path.arcTo(
        Rect.fromCircle(center: center, radius: holeRadius),
        startAngle + gap / 2 + sweep,
        -sweep,
        false,
      );
      path.close();
      canvas.drawPath(path, paint);

      final glowPaint = Paint()
        ..color = seg.color.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;
      final glowPath = Path();
      glowPath.addArc(
        Rect.fromCircle(center: center, radius: radius - 3),
        startAngle + gap / 2,
        sweep,
      );
      canvas.drawPath(glowPath, glowPaint);

      startAngle += (seg.value / total) * 2 * pi * progress;
    }
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) => oldDelegate.progress != progress;
}

// ─── Heatmap Painter (shared by LeetCode + GitHub) ──────────────────────────

class _HeatmapPainter extends CustomPainter {
  final Map<DateTime, int> data;
  final Color baseColor;
  final double progress; // fade-in animation

  _HeatmapPainter({required this.data, required this.baseColor, required this.progress});

  static const int _weeks = 26; // 6 months
  static const double _cellSize = 11.0;
  static const double _gap = 3.0;
  static const double _step = _cellSize + _gap;
  static const double _radius = 2.5;

  int _maxVal() {
    if (data.isEmpty) return 1;
    return data.values.reduce(max).clamp(1, 999);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Start from (weeks * 7) days ago, aligned to Sunday
    final totalDays = _weeks * 7;
    DateTime start = today.subtract(Duration(days: totalDays - 1));
    // Align start to Sunday (weekday 7 = Sunday in Dart)
    while (start.weekday != DateTime.sunday) {
      start = start.subtract(const Duration(days: 1));
    }

    final maxVal = _maxVal();
    final bg = FF.card;

    int col = 0;
    DateTime cursor = start;

    while (!cursor.isAfter(today)) {
      final row = cursor.weekday % 7; // Sun=0 … Sat=6
      final x = col * _step;
      final y = row * _step;

      final count = data[cursor] ?? 0;
      final intensity = count == 0 ? 0.0 : (count / maxVal).clamp(0.08, 1.0);
      final cellColor = count == 0
          ? FF.divider.withOpacity(0.6)
          : Color.lerp(baseColor.withOpacity(0.25), baseColor, intensity)!
              .withOpacity(progress);

      final paint = Paint()..color = cellColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, _cellSize, _cellSize),
          const Radius.circular(_radius),
        ),
        paint,
      );

      cursor = cursor.add(const Duration(days: 1));
      if (cursor.weekday == DateTime.sunday) col++;
    }
  }

  // Required canvas width
  static double canvasWidth() => _weeks * _step;
  // Required canvas height (7 rows)
  static double canvasHeight() => 7 * _step - _gap;

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.progress != progress || old.data != data;
}

// ─── Progress View ───────────────────────────────────────────────────────────

class ProgressView extends StatefulWidget {
  const ProgressView({super.key});
  @override
  State<ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<ProgressView>
    with TickerProviderStateMixin {
  Map<String, dynamic>? lcData;
  Map<String, dynamic>? cfData;
  LeetCodeStats? lcStats;
  GitHubStats? ghStats;
  bool loading = true;

  late AnimationController _pieCtrl;
  late AnimationController _staggerCtrl;
  late AnimationController _heatmapCtrl;

  late Animation<double> _pieAnim;
  late Animation<double> _heatmapAnim;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  // Increased item count to accommodate GitHub section
  static const int _itemCount = 8;

  @override
  void initState() {
    super.initState();

    _pieCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pieAnim = CurvedAnimation(parent: _pieCtrl, curve: Curves.easeOutQuart);

    _heatmapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _heatmapAnim = CurvedAnimation(parent: _heatmapCtrl, curve: Curves.easeOut);

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _fadeAnims = List.generate(_itemCount, (i) {
      final start = i * 0.09;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(start.clamp(0.0, 1.0), end, curve: Curves.easeOut),
        ),
      );
    });

    _slideAnims = List.generate(_itemCount, (i) {
      final start = i * 0.09;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(start.clamp(0.0, 1.0), end, curve: Curves.easeOutCubic),
        ),
      );
    });

    _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    final prefs = await SharedPreferences.getInstance();
    final lcUser = prefs.getString('lc_username');
    final cfUser = prefs.getString('cf_handle');
    final ghUser = prefs.getString('gh_username');
    final ghPat  = prefs.getString('gh_pat') ?? '';

    // Fetch in parallel
    final futures = await Future.wait([
      // LeetCode basic stats (for pie chart)
      lcUser != null && lcUser.isNotEmpty
          ? StatsFetchService.fetchLeetCode(lcUser)
          : Future.value(null),
      // LeetCode full stats (for heatmap)
      lcUser != null && lcUser.isNotEmpty
          ? LeetCodeService.fetchStats(lcUser)
          : Future.value(null),
      // Codeforces
      cfUser != null && cfUser.isNotEmpty
          ? StatsFetchService.fetchCodeforces(cfUser)
          : Future.value(null),
      // GitHub
      ghUser != null && ghUser.isNotEmpty
          ? GitHubService.fetchStats(ghUser, ghPat)
          : Future.value(null),
    ]);

    if (mounted) {
      setState(() {
        lcData  = futures[0] as Map<String, dynamic>?;
        lcStats = futures[1] as LeetCodeStats?;
        cfData  = futures[2] as Map<String, dynamic>?;
        ghStats = futures[3] as GitHubStats?;
        loading = false;
      });
      _pieCtrl.forward();
      _staggerCtrl.forward();
      _heatmapCtrl.forward();
    }
  }

  @override
  void dispose() {
    _pieCtrl.dispose();
    _staggerCtrl.dispose();
    _heatmapCtrl.dispose();
    super.dispose();
  }

  Widget _animated(int index, Widget child) {
    final i = index.clamp(0, _itemCount - 1);
    return FadeTransition(
      opacity: _fadeAnims[i],
      child: SlideTransition(position: _slideAnims[i], child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FF.bg,
      appBar: AppBar(
        backgroundColor: FF.bg,
        elevation: 0,
        title: Text(
          'My Growth',
          style: TextStyle(
            color: FF.textPri,
            fontWeight: FontWeight.w900,
            fontFamily: 'medifont',
            fontSize: 22,
            letterSpacing: 0.4,
          ),
        ),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: FF.accent, strokeWidth: 2))
          : (lcData == null && cfData == null && ghStats == null)
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_rounded, color: FF.textSec, size: 48),
          const SizedBox(height: 14),
          Text('No accounts connected',
              style: TextStyle(color: FF.textSec, fontSize: 15)),
          const SizedBox(height: 6),
          Text('Link LeetCode, GitHub or Codeforces\nfrom your profile settings',
              textAlign: TextAlign.center,
              style: TextStyle(color: FF.textSec.withOpacity(0.6), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final easy   = lcData?['easySolved']   as int? ?? 0;
    final medium = lcData?['mediumSolved'] as int? ?? 0;
    final hard   = lcData?['hardSolved']   as int? ?? 0;
    final total  = lcData?['totalSolved']  as int? ?? 0;

    int idx = 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [

        // ── LeetCode section ──────────────────────────────────────────────
        if (lcData != null) ...[
          _animated(idx++, _buildLcHeader(total)),
          const SizedBox(height: 14),
          _animated(idx++, _buildPieSection(easy, medium, hard, total)),
          const SizedBox(height: 10),
          _animated(idx++, _buildDiffRow(easy, medium, hard)),

          // Streak & active days chips
          if (lcStats != null) ...[
            const SizedBox(height: 10),
            _animated(idx++, _buildLcStreakRow()),
          ],

          // Heatmap
          if (lcStats != null && lcStats!.submissionCalendar.isNotEmpty) ...[
            const SizedBox(height: 14),
            _animated(idx++, _buildHeatmapCard(
              title: 'SUBMISSION ACTIVITY',
              subtitle: 'Last 6 months',
              heatmap: LeetCodeService.toHeatmap(lcStats!.submissionCalendar),
              color: const Color(0xFFFFA116),
            )),
          ],
        ],

        // ── Codeforces card ───────────────────────────────────────────────
        if (cfData != null) ...[
          const SizedBox(height: 14),
          _animated(idx++, _buildCfCard()),
        ],

        // ── GitHub section ────────────────────────────────────────────────
        if (ghStats != null) ...[
          const SizedBox(height: 20),
          _animated(idx++, _buildGhHeader()),
          const SizedBox(height: 14),
          _animated(idx++, _buildHeatmapCard(
            title: 'CONTRIBUTION ACTIVITY',
            subtitle: 'Last 6 months',
            heatmap: ghStats!.heatmap,
            color: const Color(0xFF3DDC84),
          )),
        ],
      ],
    );
  }

  // ── LeetCode header banner ───────────────────────────────────────────────
  Widget _buildLcHeader(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FF.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFA116).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.code_rounded, color: Color(0xFFFFA116), size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LEETCODE', style: TextStyle(
                color: FF.textSec, fontSize: 11,
                letterSpacing: 1.2, fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 3),
              Text('$total problems solved', style: TextStyle(
                color: FF.textPri, fontSize: 18,
                fontWeight: FontWeight.w800, fontFamily: 'medifont',
              )),
            ],
          ),
          if (lcStats != null) ...[
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Rank', style: TextStyle(
                  color: FF.textSec, fontSize: 10, letterSpacing: 0.8,
                )),
                Text(
                  lcStats!.ranking > 0 ? '#${_formatNumber(lcStats!.ranking)}' : '–',
                  style: TextStyle(
                    color: FF.textPri, fontSize: 15,
                    fontWeight: FontWeight.w800, fontFamily: 'medifont',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── LeetCode streak row ──────────────────────────────────────────────────
  Widget _buildLcStreakRow() {
    final streak = lcStats?.streak ?? 0;
    final activeDays = lcStats?.totalActiveDays ?? 0;
    return Row(
      children: [
        Expanded(child: _chipCard(
          icon: Icons.local_fire_department_rounded,
          iconColor: const Color(0xFFFF6B35),
          label: 'Current Streak',
          value: '$streak days',
        )),
        const SizedBox(width: 10),
        Expanded(child: _chipCard(
          icon: Icons.calendar_today_rounded,
          iconColor: const Color(0xFF4F8EF7),
          label: 'Active Days',
          value: '$activeDays days',
        )),
      ],
    );
  }

  Widget _chipCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FF.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                color: FF.textSec, fontSize: 10, letterSpacing: 0.5,
              )),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(
                color: FF.textPri, fontSize: 14,
                fontWeight: FontWeight.w800, fontFamily: 'medifont',
              )),
            ],
          ),
        ],
      ),
    );
  }

  // ── Pie chart section ────────────────────────────────────────────────────
  Widget _buildPieSection(int easy, int medium, int hard, int total) {
    final hasData = easy + medium + hard > 0;
    final segments = hasData
        ? [
            _PieSegment(value: easy.toDouble(),   color: const Color(0xFF3DDC84), label: 'Easy'),
            _PieSegment(value: medium.toDouble(), color: const Color(0xFFFFB547), label: 'Medium'),
            _PieSegment(value: hard.toDouble(),   color: const Color(0xFFFF5C5C), label: 'Hard'),
          ]
        : [_PieSegment(value: 1, color: FF.divider, label: '')];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FF.divider),
      ),
      child: Column(
        children: [
          Text('DIFFICULTY BREAKDOWN', style: TextStyle(
            color: FF.textSec, fontSize: 11,
            letterSpacing: 1.2, fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 24),
          SizedBox(
            width: 200, height: 200,
            child: AnimatedBuilder(
              animation: _pieAnim,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(200, 200),
                    painter: _PiePainter(segments: segments, progress: _pieAnim.value),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(total * _pieAnim.value).round()}',
                        style: TextStyle(
                          color: FF.textPri, fontSize: 34,
                          fontWeight: FontWeight.w900, fontFamily: 'medifont',
                        ),
                      ),
                      Text('solved', style: TextStyle(color: FF.textSec, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (hasData) ...[
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legend(const Color(0xFF3DDC84), 'Easy'),
                const SizedBox(width: 22),
                _legend(const Color(0xFFFFB547), 'Medium'),
                const SizedBox(width: 22),
                _legend(const Color(0xFFFF5C5C), 'Hard'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9, height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: FF.textSec, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ── Difficulty stat cards ────────────────────────────────────────────────
  Widget _buildDiffRow(int easy, int medium, int hard) {
    return Row(
      children: [
        Expanded(child: _diffCard('Easy',   easy,   const Color(0xFF3DDC84))),
        const SizedBox(width: 10),
        Expanded(child: _diffCard('Medium', medium, const Color(0xFFFFB547))),
        const SizedBox(width: 10),
        Expanded(child: _diffCard('Hard',   hard,   const Color(0xFFFF5C5C))),
      ],
    );
  }

  Widget _diffCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        children: [
          Text('$count', style: TextStyle(
            color: color, fontSize: 24,
            fontWeight: FontWeight.w900, fontFamily: 'medifont',
          )),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            color: color.withOpacity(0.75), fontSize: 11,
            fontWeight: FontWeight.w600, letterSpacing: 0.5,
          )),
        ],
      ),
    );
  }

  // ── Shared heatmap card ──────────────────────────────────────────────────
  Widget _buildHeatmapCard({
    required String title,
    required String subtitle,
    required Map<DateTime, int> heatmap,
    required Color color,
  }) {
    final totalInRange = _countLast6Months(heatmap);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FF.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(
                color: FF.textSec, fontSize: 11,
                letterSpacing: 1.2, fontWeight: FontWeight.w600,
              )),
              Text('$totalInRange in 6 months', style: TextStyle(
                color: color, fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(
            color: FF.textSec.withOpacity(0.5), fontSize: 11,
          )),
          const SizedBox(height: 16),

          // Day labels row: Sun Mon Tue Wed Thu Fri Sat
          Row(
            children: [
              const SizedBox(width: 2),
              ..._buildDayLabels(),
            ],
          ),
          const SizedBox(height: 4),

          // Scrollable heatmap grid
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // show most recent on the right
            child: AnimatedBuilder(
              animation: _heatmapAnim,
              builder: (_, __) => CustomPaint(
                size: Size(
                  _HeatmapPainter.canvasWidth(),
                  _HeatmapPainter.canvasHeight(),
                ),
                painter: _HeatmapPainter(
                  data: heatmap,
                  baseColor: color,
                  progress: _heatmapAnim.value,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),
          // Legend
          Row(
            children: [
              Text('Less', style: TextStyle(color: FF.textSec.withOpacity(0.5), fontSize: 10)),
              const SizedBox(width: 6),
              ...List.generate(5, (i) {
                final t = i / 4.0;
                return Container(
                  margin: const EdgeInsets.only(right: 3),
                  width: 11, height: 11,
                  decoration: BoxDecoration(
                    color: i == 0
                        ? FF.divider.withOpacity(0.6)
                        : Color.lerp(color.withOpacity(0.25), color, t),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                );
              }),
              const SizedBox(width: 6),
              Text('More', style: TextStyle(color: FF.textSec.withOpacity(0.5), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDayLabels() {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return labels.map((l) => SizedBox(
      width: 14,
      height: 14,
      child: Center(
        child: Text(l, style: TextStyle(
          color: FF.textSec.withOpacity(0.4), fontSize: 8.5,
        )),
      ),
    )).toList();
  }

  int _countLast6Months(Map<DateTime, int> heatmap) {
    final cutoff = DateTime.now().subtract(const Duration(days: 182));
    return heatmap.entries
        .where((e) => e.key.isAfter(cutoff))
        .fold(0, (sum, e) => sum + e.value);
  }

  // ── Codeforces card ──────────────────────────────────────────────────────
  Widget _buildCfCard() {
    final rating = cfData?['rating'] as int?;
    final rank   = cfData?['rank']   as String? ?? 'unrated';
    final rankColor = _cfRankColor(rank);
    final displayRank = rank.isNotEmpty
        ? rank[0].toUpperCase() + rank.substring(1)
        : 'Unrated';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FF.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: FF.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.trending_up_rounded, color: FF.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CODEFORCES', style: TextStyle(
                  color: FF.textSec, fontSize: 11,
                  letterSpacing: 1.2, fontWeight: FontWeight.w600,
                )),
                const SizedBox(height: 3),
                Text(
                  rating != null ? 'Rating  $rating' : 'Unrated',
                  style: TextStyle(
                    color: FF.textPri, fontSize: 18,
                    fontWeight: FontWeight.w800, fontFamily: 'medifont',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: rankColor.withOpacity(0.28)),
            ),
            child: Text(displayRank, style: TextStyle(
              color: rankColor, fontSize: 12,
              fontWeight: FontWeight.w700, letterSpacing: 0.3,
            )),
          ),
        ],
      ),
    );
  }

  Color _cfRankColor(String rank) {
    final r = rank.toLowerCase();
    if (r.contains('legendary') || r.contains('grandmaster')) return const Color(0xFFFF5C5C);
    if (r.contains('international') && r.contains('master'))  return const Color(0xFFFF8C00);
    if (r.contains('master'))     return const Color(0xFFFF8C00);
    if (r.contains('candidate'))  return const Color(0xFFB06EF5);
    if (r.contains('expert'))     return const Color(0xFF4F8EF7);
    if (r.contains('specialist')) return const Color(0xFF3DDC84);
    return FF.textSec;
  }

  // ── GitHub header + stats row ────────────────────────────────────────────
  Widget _buildGhHeader() {
    final gh = ghStats!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FF.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF3DDC84).withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hub_rounded, color: Color(0xFF3DDC84), size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GITHUB', style: TextStyle(
                    color: FF.textSec, fontSize: 11,
                    letterSpacing: 1.2, fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 3),
                  Text(
                    gh.name.isNotEmpty ? gh.name : gh.username,
                    style: TextStyle(
                      color: FF.textPri, fontSize: 18,
                      fontWeight: FontWeight.w800, fontFamily: 'medifont',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Total contributions badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3DDC84).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF3DDC84).withOpacity(0.28)),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatNumber(gh.totalContributions),
                      style: const TextStyle(
                        color: Color(0xFF3DDC84), fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('commits', style: TextStyle(
                      color: const Color(0xFF3DDC84).withOpacity(0.7),
                      fontSize: 9, fontWeight: FontWeight.w600,
                    )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Repos + Followers chips
          Row(
            children: [
              Expanded(child: _ghStatChip(
                icon: Icons.folder_copy_rounded,
                color: const Color(0xFF4F8EF7),
                label: 'Repositories',
                value: '${gh.publicRepos}',
              )),
              const SizedBox(width: 10),
              Expanded(child: _ghStatChip(
                icon: Icons.people_rounded,
                color: const Color(0xFFB06EF5),
                label: 'Followers',
                value: _formatNumber(gh.followers),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ghStatChip({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(
                color: color, fontSize: 16,
                fontWeight: FontWeight.w800, fontFamily: 'medifont',
              )),
              Text(label, style: TextStyle(
                color: color.withOpacity(0.65), fontSize: 10,
                fontWeight: FontWeight.w500,
              )),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}