import 'package:firebase_database/firebase_database.dart';
import 'package:FocusFlow/services/auth/auth_service.dart';

class DayStats {
  final String label;   // "Mon", "Tue" etc.
  final int minutes;
  final bool isToday;
  const DayStats({required this.label, required this.minutes, required this.isToday});
}

class WeeklyStatsService {
  static final _db = FirebaseDatabase.instance.ref();
  static String? get _uid => AuthService.firebase().currentUser?.id;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Returns stats for Monday–Sunday of the current week.
  static Future<List<DayStats>> fetchCurrentWeek() async {
    final uid = _uid;
    if (uid == null) return _emptyWeek();

    final now     = DateTime.now();
    // Monday of this week
    final monday  = now.subtract(Duration(days: now.weekday - 1));
    final mondayDay = DateTime(monday.year, monday.month, monday.day);

    final snap = await _db.child('timers/$uid/sessions').get();
    if (!snap.exists) return _emptyWeek();

    // Accumulate minutes per weekday index (0 = Mon)
    final mins = List<int>.filled(7, 0);
    final data = snap.value as Map<dynamic, dynamic>;

    for (final entry in data.entries) {
      final session = Map<dynamic, dynamic>.from(entry.value);
      final completedAt = session['completedAt'] as String?;
      if (completedAt == null) continue;
      final date = DateTime.tryParse(completedAt);
      if (date == null) continue;
      final sessionDay = DateTime(date.year, date.month, date.day);
      final diff = sessionDay.difference(mondayDay).inDays;
      if (diff >= 0 && diff < 7) {
        mins[diff] += (session['focusMinutes'] as int? ?? 0);
      }
    }

    return List.generate(7, (i) => DayStats(
      label: _dayLabels[i],
      minutes: mins[i],
      isToday: i == now.weekday - 1,
    ));
  }

  static List<DayStats> _emptyWeek() => List.generate(7, (i) => DayStats(
    label: _dayLabels[i], minutes: 0,
    isToday: i == DateTime.now().weekday - 1,
  ));
}