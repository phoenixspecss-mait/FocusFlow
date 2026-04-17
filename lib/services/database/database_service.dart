import 'database_provider.dart';
import 'firebase_database_provider.dart';
import 'database_note.dart';
import 'database_task.dart';
import 'database_habit.dart';

class DatabaseService implements DatabaseProvider {
  final DatabaseProvider provider;

  const DatabaseService(this.provider);

  factory DatabaseService.firebase() =>
      DatabaseService(FirebaseDatabaseProvider());

  // ─── User ─────────────────────────────────────────────
  @override
  Future<void> createUser({required String ownerUserId}) =>
      provider.createUser(ownerUserId: ownerUserId);

  @override
  Future<Map<String, dynamic>> getUserProfile({
    required String ownerUserId,
  }) =>
      provider.getUserProfile(ownerUserId: ownerUserId);

  @override
  Future<void> updateUserStats({
    required String ownerUserId,
    int? focusHours,
    int? totalSessions,
    int? tasksDone,
    int? streak,
  }) =>
      provider.updateUserStats(
        ownerUserId: ownerUserId,
        focusHours: focusHours,
        totalSessions: totalSessions,
        tasksDone: tasksDone,
        streak: streak,
      );

  // ─── Tasks ────────────────────────────────────────────
  @override
  Future<DatabaseTask> createTask({
    required String ownerUserId,
    required String title,
  }) =>
      provider.createTask(ownerUserId: ownerUserId, title: title);

  @override
  Future<List<DatabaseTask>> getAllTasks({
    required String ownerUserId,
  }) =>
      provider.getAllTasks(ownerUserId: ownerUserId);

  @override
  Future<void> updateTask({
    required String ownerUserId,
    required String taskId,
    required bool completed,
  }) =>
      provider.updateTask(
        ownerUserId: ownerUserId,
        taskId: taskId,
        completed: completed,
      );

  @override
  Future<void> deleteTask({
    required String ownerUserId,
    required String taskId,
  }) =>
      provider.deleteTask(
        ownerUserId: ownerUserId,
        taskId: taskId,
      );

  // ─── Notes ────────────────────────────────────────────
  @override
  Future<DatabaseNote> createNote({
    required String ownerUserId,
    required String title,
    required String content,
  }) =>
      provider.createNote(
        ownerUserId: ownerUserId,
        title: title,
        content: content,
      );

  @override
  Future<List<DatabaseNote>> getAllNotes({
    required String ownerUserId,
  }) =>
      provider.getAllNotes(ownerUserId: ownerUserId);

  @override
  Future<void> updateNote({
    required String ownerUserId,
    required String noteId,
    required String title,
    required String content,
  }) =>
      provider.updateNote(
        ownerUserId: ownerUserId,
        noteId: noteId,
        title: title,
        content: content,
      );

  @override
  Future<void> deleteNote({
    required String ownerUserId,
    required String noteId,
  }) =>
      provider.deleteNote(
        ownerUserId: ownerUserId,
        noteId: noteId,
      );

  // ─── Timer ────────────────────────────────────────────
  @override
  Future<void> saveTimerSession({
    required String ownerUserId,
    required int focusMinutes,
    required int breakMinutes,
  }) =>
      provider.saveTimerSession(
        ownerUserId: ownerUserId,
        focusMinutes: focusMinutes,
        breakMinutes: breakMinutes,
      );

  @override
  Future<Map<String, dynamic>> getTimerSettings({
    required String ownerUserId,
  }) =>
      provider.getTimerSettings(ownerUserId: ownerUserId);

  // ─── Habits ───────────────────────────────────────────
  @override
  Future<DatabaseHabit> createHabit({
    required String ownerUserId,
    required String title,
  }) =>
      provider.createHabit(
        ownerUserId: ownerUserId,
        title: title,
      );

  @override
  Future<List<DatabaseHabit>> getAllHabits({
    required String ownerUserId,
  }) =>
      provider.getAllHabits(ownerUserId: ownerUserId);

  @override
  Future<void> markHabitComplete({
    required String ownerUserId,
    required String habitId,
    required List<String> completedDates,
  }) =>
      provider.markHabitComplete(
        ownerUserId: ownerUserId,
        habitId: habitId,
        completedDates: completedDates,
      );

  @override
  Future<void> deleteHabit({
    required String ownerUserId,
    required String habitId,
  }) =>
      provider.deleteHabit(
        ownerUserId: ownerUserId,
        habitId: habitId,
      );

  // ─── Streams (Real-time) ──────────────────────────────
  Stream<List<DatabaseTask>> tasksStream({required String ownerUserId}) {
    final fp = provider as FirebaseDatabaseProvider;
    return fp.tasksStream(ownerUserId: ownerUserId);
  }

  Stream<List<DatabaseNote>> notesStream({required String ownerUserId}) {
    final fp = provider as FirebaseDatabaseProvider;
    return fp.notesStream(ownerUserId: ownerUserId);
  }

  Stream<List<DatabaseHabit>> habitsStream({required String ownerUserId}) {
    final fp = provider as FirebaseDatabaseProvider;
    return fp.habitsStream(ownerUserId: ownerUserId);
  }

  /// Real-time stream of the user document — used by the home screen
  /// stats row so focus hours, sessions and streak update live.
  Stream<Map<String, dynamic>> userStatsStream({
    required String ownerUserId,
  }) {
    final fp = provider as FirebaseDatabaseProvider;
    return fp.userStatsStream(ownerUserId: ownerUserId);
  }
}