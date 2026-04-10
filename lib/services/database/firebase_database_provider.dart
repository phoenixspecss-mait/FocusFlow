import 'package:firebase_database/firebase_database.dart';
import 'database_exceptions.dart';
import 'database_task.dart';
import 'database_note.dart';
import 'database_provider.dart';
import 'database_habit.dart';

class FirebaseDatabaseProvider implements DatabaseProvider {
  final _db = FirebaseDatabase.instance.ref();

  // ─── User ────────────────────────────────────────────
  @override
  Future<void> createUser({required String ownerUserId}) async {
    try {
      await _db.child("users/$ownerUserId").set({
        'ownerUserId': ownerUserId,
        'focusHours': 0,
        'totalSessions': 0,
        'tasksDone': 0,
        'streak': 0,
        'lastActiveDate': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw CouldNotCreateNote();
    }
  }

  // Get user profile
  @override
  Future<Map<String, dynamic>> getUserProfile({
    required String ownerUserId,
  }) async {
    final snapshot = await _db.child("users/$ownerUserId").get();
    if (!snapshot.exists) return {};
    return Map<String, dynamic>.from(
      snapshot.value as Map<dynamic, dynamic>,
    );
  }

  // Update user stats
  @override
  Future<void> updateUserStats({
    required String ownerUserId,
    int? focusHours,
    int? totalSessions,
    int? tasksDone,
    int? streak,
  }) async {
    final updates = <String, dynamic>{};
    if (focusHours != null) updates['focusHours'] = focusHours;
    if (totalSessions != null) updates['totalSessions'] = totalSessions;
    if (tasksDone != null) updates['tasksDone'] = tasksDone;
    if (streak != null) updates['streak'] = streak;
    updates['lastActiveDate'] = DateTime.now().toIso8601String();
    await _db.child("users/$ownerUserId").update(updates);
  }

  // ─── Tasks ───────────────────────────────────────────
  @override
  Future<DatabaseTask> createTask({
    required String ownerUserId,
    required String title,
  }) async {
    final ref = _db.child("tasks/$ownerUserId").push();
    final task = {
      'ownerUserId': ownerUserId,
      'title': title,
      'completed': false,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await ref.set(task);
    return DatabaseTask.fromSnapshot(task, ref.key!);
  }

  @override
  Future<List<DatabaseTask>> getAllTasks({
    required String ownerUserId,
  }) async {
    final snapshot = await _db.child("tasks/$ownerUserId").get();
    if (!snapshot.exists) return [];
    final data = snapshot.value as Map<dynamic, dynamic>;
    return data.entries
        .map((e) => DatabaseTask.fromSnapshot(e.value, e.key))
        .toList();
  }

  @override
  Future<void> updateTask({
    required String ownerUserId,
    required String taskId,
    required bool completed,
  }) async {
    await _db.child("tasks/$ownerUserId/$taskId").update({
      'completed': completed,
    });
  }

  @override
  Future<void> deleteTask({
    required String ownerUserId,
    required String taskId,
  }) async {
    await _db.child("tasks/$ownerUserId/$taskId").remove();
  }

  Stream<List<DatabaseTask>> tasksStream({required String ownerUserId}) {
    return _db.child("tasks/$ownerUserId").onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries
          .map((e) => DatabaseTask.fromSnapshot(e.value, e.key))
          .toList();
    });
  }

  // ─── Notes ───────────────────────────────────────────
  @override
  Future<DatabaseNote> createNote({
    required String ownerUserId,
    required String title,
    required String content,
  }) async {
    final ref = _db.child("notes/$ownerUserId").push();
    final note = {
      'ownerUserId': ownerUserId,
      'title': title,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await ref.set(note);
    return DatabaseNote.fromSnapshot(note, ref.key!);
  }

  @override
  Future<List<DatabaseNote>> getAllNotes({
    required String ownerUserId,
  }) async {
    final snapshot = await _db.child("notes/$ownerUserId").get();
    if (!snapshot.exists) return [];
    final data = snapshot.value as Map<dynamic, dynamic>;
    return data.entries
        .map((e) => DatabaseNote.fromSnapshot(e.value, e.key))
        .toList();
  }

  @override
  Future<void> updateNote({
    required String ownerUserId,
    required String noteId,
    required String title,
    required String content,
  }) async {
    await _db.child("notes/$ownerUserId/$noteId").update({
      'title': title,
      'content': content,
    });
  }

  @override
  Future<void> deleteNote({
    required String ownerUserId,
    required String noteId,
  }) async {
    await _db.child("notes/$ownerUserId/$noteId").remove();
  }

  Stream<List<DatabaseNote>> notesStream({required String ownerUserId}) {
    return _db.child("notes/$ownerUserId").onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries
          .map((e) => DatabaseNote.fromSnapshot(e.value, e.key))
          .toList();
    });
  }

  // ─── Timer / Pomodoro ────────────────────────────────
  @override
  Future<void> saveTimerSession({
    required String ownerUserId,
    required int focusMinutes,
    required int breakMinutes,
  }) async {
    // Save timer settings
    await _db.child("timers/$ownerUserId/settings").set({
      'focusMinutes': focusMinutes,
      'breakMinutes': breakMinutes,
    });

    // Save session history
    final ref = _db.child("timers/$ownerUserId/sessions").push();
    await ref.set({
      'focusMinutes': focusMinutes,
      'completedAt': DateTime.now().toIso8601String(),
    });

    // Update user stats
    final profile = await getUserProfile(ownerUserId: ownerUserId);
    final currentSessions = (profile['totalSessions'] ?? 0) as int;
    final currentHours = (profile['focusHours'] ?? 0) as int;
    await updateUserStats(
      ownerUserId: ownerUserId,
      totalSessions: currentSessions + 1,
      focusHours: currentHours + (focusMinutes ~/ 60),
    );
  }

  @override
  Future<Map<String, dynamic>> getTimerSettings({
    required String ownerUserId,
  }) async {
    final snapshot =
        await _db.child("timers/$ownerUserId/settings").get();
    if (!snapshot.exists) {
      return {'focusMinutes': 25, 'breakMinutes': 5}; // defaults
    }
    return Map<String, dynamic>.from(
      snapshot.value as Map<dynamic, dynamic>,
    );
  }

  // ─── Habits ──────────────────────────────────────────
  @override
  Future<DatabaseHabit> createHabit({
    required String ownerUserId,
    required String title,
  }) async {
    final ref = _db.child("habits/$ownerUserId").push();
    final habit = {
      'ownerUserId': ownerUserId,
      'title': title,
      'completedDates': [],
      'createdAt': DateTime.now().toIso8601String(),
    };
    await ref.set(habit);
    return DatabaseHabit.fromSnapshot(habit, ref.key!);
  }

  @override
  Future<List<DatabaseHabit>> getAllHabits({
    required String ownerUserId,
  }) async {
    final snapshot = await _db.child("habits/$ownerUserId").get();
    if (!snapshot.exists) return [];
    final data = snapshot.value as Map<dynamic, dynamic>;
    return data.entries
        .map((e) => DatabaseHabit.fromSnapshot(e.value, e.key))
        .toList();
  }

  @override
  Future<void> markHabitComplete({
    required String ownerUserId,
    required String habitId,
    required List<String> completedDates,
  }) async {
    await _db.child("habits/$ownerUserId/$habitId").update({
      'completedDates': completedDates,
    });
  }

  @override
  Future<void> deleteHabit({
    required String ownerUserId,
    required String habitId,
  }) async {
    await _db.child("habits/$ownerUserId/$habitId").remove();
  }

  Stream<List<DatabaseHabit>> habitsStream({required String ownerUserId}) {
    return _db.child("habits/$ownerUserId").onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries
          .map((e) => DatabaseHabit.fromSnapshot(e.value, e.key))
          .toList();
    });
  }
}