import 'database_note.dart';
import 'database_task.dart';
import 'database_timer.dart';
import 'database_habit.dart';

abstract class DatabaseProvider {
  // ─── User ─────────────────────────────────────────────
  Future<void> createUser({required String ownerUserId});
  
  Future<Map<String, dynamic>> getUserProfile({
    required String ownerUserId,
  });
  
  Future<void> updateUserStats({
    required String ownerUserId,
    int? focusHours,
    int? totalSessions,
    int? tasksDone,
    int? streak,
  });

  // ─── Tasks ────────────────────────────────────────────
  Future<DatabaseTask> createTask({
    required String ownerUserId,
    required String title,
  });
  
  Future<List<DatabaseTask>> getAllTasks({
    required String ownerUserId,
  });
  
  Future<void> updateTask({
    required String ownerUserId,
    required String taskId,
    required bool completed,
  });
  
  Future<void> deleteTask({
    required String ownerUserId,
    required String taskId,
  });

  // ─── Notes ────────────────────────────────────────────
  Future<DatabaseNote> createNote({
    required String ownerUserId,
    required String title,
    required String content,
  });
  
  Future<List<DatabaseNote>> getAllNotes({
    required String ownerUserId,
  });
  
  Future<void> updateNote({
    required String ownerUserId,
    required String noteId,
    required String title,
    required String content,
  });
  
  Future<void> deleteNote({
    required String ownerUserId,
    required String noteId,
  });

  // ─── Timer ────────────────────────────────────────────
  Future<void> saveTimerSession({
    required String ownerUserId,
    required int focusMinutes,
    required int breakMinutes,
  });
  
  Future<Map<String, dynamic>> getTimerSettings({
    required String ownerUserId,
  });

  // ─── Habits ───────────────────────────────────────────
  Future<DatabaseHabit> createHabit({
    required String ownerUserId,
    required String title,
  });
  
  Future<List<DatabaseHabit>> getAllHabits({
    required String ownerUserId,
  });
  
  Future<void> markHabitComplete({
    required String ownerUserId,
    required String habitId,
    required List<String> completedDates,
  });
  
  Future<void> deleteHabit({
    required String ownerUserId,
    required String habitId,
  });
}
