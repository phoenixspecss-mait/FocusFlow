import 'package:firebase_database/firebase_database.dart';
import 'package:FocusFlow/services/auth/auth_service.dart';

class StatsService {
  static final _db = FirebaseDatabase.instance.ref();
  static String? get _uid => AuthService.firebase().currentUser?.id;

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Called when a Pomodoro completes (hook into focus_view.dart) ────────
  static Future<void> recordSession({required int focusMinutes}) async {
    final uid = _uid;
    if (uid == null) return;

    final today  = _dayKey(DateTime.now());
    final xp     = focusMinutes >= 25 ? 30 : 10;

    // Single multi-path write — one network call
    await _db.update({
      // Daily log (feeds heatmap)
      'users/$uid/sessions/$today/sessions':  ServerValue.increment(1),
      'users/$uid/sessions/$today/minutes':   ServerValue.increment(focusMinutes),
      'users/$uid/sessions/$today/xp':        ServerValue.increment(xp),
      // Global profile counters (already tracked by firebase_database_provider
      // as focusHours/totalSessions — we ADD xp and level on top)
      'users/$uid/xp':             ServerValue.increment(xp),
      'users/$uid/totalSessions':  ServerValue.increment(1),
      // Leaderboard mirror
      'leaderboard/$uid/xp':       ServerValue.increment(xp),
    });

    await _checkBadges(uid);
    await _updateLevel(uid);
  }

  // ── Award XP for platform task verification ─────────────────────────────
  static Future<void> awardTaskXP({required String platform}) async {
    final uid = _uid;
    if (uid == null) return;

    final xp = platform == 'leetcode' ? 50
             : platform == 'codeforces' ? 50
             : platform == 'codechef' ? 40
             : platform == 'github' ? 30
             : 20;

    await _db.update({
      'users/$uid/xp':       ServerValue.increment(xp),
      'leaderboard/$uid/xp': ServerValue.increment(xp),
    });
  }

  // ── Level = xp / 500 + 1 ───────────────────────────────────────────────
  static Future<void> _updateLevel(String uid) async {
    final snap = await _db.child('users/$uid/xp').get();
    final xp   = (snap.value as int?) ?? 0;
    final level = xp ~/ 500 + 1;
    await _db.child('users/$uid/level').set(level);
    await _db.child('leaderboard/$uid/level').set(level);
  }

  // ── Badge unlock logic ──────────────────────────────────────────────────
  static Future<void> _checkBadges(String uid) async {
    final snap = await _db.child('users/$uid').get();
    if (!snap.exists) return;
    final data = Map<String, dynamic>.from(snap.value as Map);

    final streak   = (data['streak']         as int?) ?? 0;
    final sessions = (data['totalSessions']   as int?) ?? 0;
    final xp       = (data['xp']             as int?) ?? 0;

    final updates = <String, dynamic>{};

    if (streak   >= 7)    updates['users/$uid/badges/seven_day_streak']   = true;
    if (streak   >= 30)   updates['users/$uid/badges/thirty_day_legend']  = true;
    if (sessions >= 5)    updates['users/$uid/badges/speed_demon']        = true;
    if (sessions >= 100)  updates['users/$uid/badges/century_mark']       = true;
    if (xp       >= 1000) updates['users/$uid/badges/xp_king']            = true;
    if (xp       >= 5000) updates['users/$uid/badges/focus_master']       = true;

    if (updates.isNotEmpty) await _db.update(updates);
  }

  // ── Streams for Stats screen ────────────────────────────────────────────

  // Profile stream: xp, level, streak, totalSessions, badges
  static Stream<Map<String, dynamic>> profileStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db.child('users/$uid').onValue.map((e) {
      if (!e.snapshot.exists) return {};
      return Map<String, dynamic>.from(e.snapshot.value as Map);
    });
  }

  // Sessions stream for heatmap (last 245 days)
  static Stream<Map<String, dynamic>> sessionsStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    final cutoff = _dayKey(DateTime.now().subtract(const Duration(days: 245)));
    return _db
        .child('users/$uid/sessions')
        .orderByKey()
        .startAt(cutoff)
        .onValue
        .map((e) {
      if (!e.snapshot.exists) return {};
      return Map<String, dynamic>.from(e.snapshot.value as Map);
    });
  }

  // Leaderboard stream (top 50 by XP)
  static Stream<List<Map<String, dynamic>>> leaderboardStream() {
    return _db
        .child('leaderboard')
        .orderByChild('xp')
        .limitToLast(50)
        .onValue
        .map((e) {
      if (!e.snapshot.exists) return [];
      final raw = Map<String, dynamic>.from(e.snapshot.value as Map);
      final list = raw.entries
          .map((en) => {'uid': en.key, ...Map<String, dynamic>.from(en.value as Map)})
          .toList()
        ..sort((a, b) => ((b['xp'] as int?) ?? 0).compareTo((a['xp'] as int?) ?? 0));
      return list;
    });
  }
}