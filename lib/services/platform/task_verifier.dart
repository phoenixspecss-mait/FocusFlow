import 'package:firebase_database/firebase_database.dart';
import 'package:FocusFlow/services/auth/auth_service.dart';
import 'package:FocusFlow/services/platform/leetcode_service.dart';
import 'package:FocusFlow/services/platform/codeforces_service.dart';
import 'package:FocusFlow/services/platform/codechef_service.dart';
import 'package:FocusFlow/services/platform/github_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Task platforms supported
enum TaskPlatform { leetcode, codeforces, codechef, github, manual }

class PlatformTask {
  final String id;
  final String title;
  final TaskPlatform platform;
  final bool verified;
  final bool completed;
  final String createdAt;

  // Platform-specific identifiers
  final String? problemSlug;   // LeetCode titleSlug
  final String? contestId;     // Codeforces contest ID
  final String? problemIndex;  // Codeforces problem index (e.g. "A", "B")
  final bool isPOTD;           // true = LeetCode POTD

  PlatformTask({
    required this.id,
    required this.title,
    required this.platform,
    required this.verified,
    required this.completed,
    required this.createdAt,
    this.problemSlug,
    this.contestId,
    this.problemIndex,
    this.isPOTD = false,
  });

  factory PlatformTask.fromMap(String id, Map<dynamic, dynamic> map) {
    TaskPlatform plat;
    switch (map['platform'] as String? ?? 'manual') {
      case 'leetcode':   plat = TaskPlatform.leetcode;   break;
      case 'codeforces': plat = TaskPlatform.codeforces; break;
      case 'codechef':   plat = TaskPlatform.codechef;   break;
      case 'github':     plat = TaskPlatform.github;     break;
      default:           plat = TaskPlatform.manual;
    }
    return PlatformTask(
      id: id,
      title: map['title'] ?? '',
      platform: plat,
      verified: map['verified'] as bool? ?? false,
      completed: map['completed'] as bool? ?? false,
      createdAt: map['createdAt'] ?? '',
      problemSlug: map['problemSlug'] as String?,
      contestId: map['contestId'] as String?,
      problemIndex: map['problemIndex'] as String?,
      isPOTD: map['isPOTD'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'platform': platform.name,
    'verified': verified,
    'completed': completed,
    'createdAt': createdAt,
    if (problemSlug != null) 'problemSlug': problemSlug,
    if (contestId != null) 'contestId': contestId,
    if (problemIndex != null) 'problemIndex': problemIndex,
    'isPOTD': isPOTD,
  };
}

class TaskVerifier {
  static final _db  = FirebaseDatabase.instance.ref();
  static String? get _uid => AuthService.firebase().currentUser?.id;

  // ── Read stored usernames ───────────────────────────────────────────────
  static Future<Map<String, String>> _getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'leetcode':  prefs.getString('lc_username')  ?? '',
      'codeforces': prefs.getString('cf_handle')   ?? '',
      'codechef':  prefs.getString('cc_username')  ?? '',
      'github':    prefs.getString('gh_username')  ?? '',
      'github_pat': prefs.getString('gh_pat')      ?? '',
    };
  }

  // ── Main verify method ──────────────────────────────────────────────────
  // Returns true if the task is now confirmed complete.
  static Future<bool> verify(PlatformTask task) async {
    if (task.platform == TaskPlatform.manual) return false;

    final accounts = await _getAccounts();
    bool result = false;

    switch (task.platform) {
      case TaskPlatform.leetcode:
        final username = accounts['leetcode'] ?? '';
        if (username.isEmpty) return false;

        if (task.isPOTD) {
          // Get today's POTD slug, then check if solved
          final potd = await LeetCodeService.fetchPOTD();
          if (potd == null) return false;
          result = await LeetCodeService.isSolvedToday(username, potd.titleSlug);
        } else if (task.problemSlug != null) {
          result = await LeetCodeService.isSolvedToday(username, task.problemSlug!);
        }
        break;

      case TaskPlatform.codeforces:
        final handle = accounts['codeforces'] ?? '';
        if (handle.isEmpty) return false;

        if (task.contestId != null && task.problemIndex != null) {
          result = await CodeforcesService.isProblemSolved(
              handle, task.contestId!, task.problemIndex!);
        } else {
          result = await CodeforcesService.submittedToday(handle);
        }
        break;

      case TaskPlatform.codechef:
        final username = accounts['codechef'] ?? '';
        if (username.isEmpty) return false;
        result = await CodeChefService.submittedToday(username);
        break;

      case TaskPlatform.github:
        final username = accounts['github'] ?? '';
        if (username.isEmpty) return false;
        result = await GitHubService.committedToday(username);
        break;

      case TaskPlatform.manual:
        break;
    }

    // If verified, write to Firebase
    if (result) {
      await _markVerified(task.id);
    }

    return result;
  }

  static Future<void> _markVerified(String taskId) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.child('tasks/$uid/$taskId').update({
      'verified': true,
      'completed': true,
      'verifiedAt': DateTime.now().toIso8601String(),
    });
  }

  // ── Create a platform task ──────────────────────────────────────────────
  static Future<void> createPlatformTask({
    required String title,
    required TaskPlatform platform,
    String? problemSlug,
    String? contestId,
    String? problemIndex,
    bool isPOTD = false,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final ref = _db.child('tasks/$uid').push();
    final task = PlatformTask(
      id: ref.key!,
      title: title,
      platform: platform,
      verified: false,
      completed: false,
      createdAt: DateTime.now().toIso8601String(),
      problemSlug: problemSlug,
      contestId: contestId,
      problemIndex: problemIndex,
      isPOTD: isPOTD,
    );
    await ref.set(task.toMap());
  }

  // ── Stream all platform tasks ───────────────────────────────────────────
  static Stream<List<PlatformTask>> platformTasksStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _db.child('tasks/$uid').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries
          .where((e) {
            final m = e.value as Map<dynamic, dynamic>;
            return m['platform'] != null && m['platform'] != 'manual';
          })
          .map((e) => PlatformTask.fromMap(e.key, e.value))
          .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }
}