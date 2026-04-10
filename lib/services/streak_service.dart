import 'package:firebase_database/firebase_database.dart';
import 'package:FocusFlow/services/auth/auth_service.dart';

/// Call StreakService.checkAndUpdate() once on app start (after auth).
/// It reads lastActiveDate from Firebase and decides whether to increment
/// or reset the streak, then writes back.
class StreakService {
  static final _db = FirebaseDatabase.instance.ref();

  static String? get _uid => AuthService.firebase().currentUser?.id;

  static String _dayKey(DateTime d) => d.toIso8601String().substring(0, 10);

  /// Returns the updated streak value.
  static Future<int> checkAndUpdate() async {
    final uid = _uid;
    if (uid == null) return 0;

    final snap = await _db.child('users/$uid').get();
    if (!snap.exists) return 0;

    final data   = Map<String, dynamic>.from(snap.value as Map);
    final today  = DateTime.now();
    final todayKey = _dayKey(today);
    final lastKey  = (data['lastActiveDate'] as String?)?.substring(0, 10) ?? '';
    int streak     = (data['streak'] as int?) ?? 0;

    if (lastKey == todayKey) {
      // Already checked today — do nothing
      return streak;
    }

    final yesterday = _dayKey(today.subtract(const Duration(days: 1)));
    if (lastKey == yesterday) {
      // Active yesterday → extend streak
      streak++;
    } else if (lastKey.isEmpty || lastKey != yesterday) {
      // Missed a day (or brand new) → reset
      streak = 1;
    }

    await _db.child('users/$uid').update({
      'streak': streak,
      'lastActiveDate': today.toIso8601String(),
    });

    return streak;
  }

  /// Call after a focus session completes to mark today as active.
  static Future<void> markActiveToday() async {
    final uid = _uid;
    if (uid == null) return;

    final snap = await _db.child('users/$uid').get();
    if (!snap.exists) return;

    final data     = Map<String, dynamic>.from(snap.value as Map);
    final today    = DateTime.now();
    final todayKey = _dayKey(today);
    final lastKey  = (data['lastActiveDate'] as String?)?.substring(0, 10) ?? '';

    if (lastKey == todayKey) return; // already marked

    final yesterday = _dayKey(today.subtract(const Duration(days: 1)));
    int streak = (data['streak'] as int?) ?? 0;
    streak = (lastKey == yesterday) ? streak + 1 : 1;

    await _db.child('users/$uid').update({
      'streak': streak,
      'lastActiveDate': today.toIso8601String(),
    });
  }
}