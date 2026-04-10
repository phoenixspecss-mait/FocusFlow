import 'package:firebase_database/firebase_database.dart';
import 'package:FocusFlow/services/auth/auth_service.dart';

class FeedPost {
  final String id;
  final String uid;
  final String username;
  final String platform;
  final bool verified;
  final String content;
  final String caption;
  final int xpEarned;
  final int likes;
  final int timestamp;

  FeedPost({
    required this.id,
    required this.uid,
    required this.username,
    required this.platform,
    required this.verified,
    required this.content,
    required this.caption,
    required this.xpEarned,
    required this.likes,
    required this.timestamp,
  });

  factory FeedPost.fromMap(String id, Map<dynamic, dynamic> map) {
    return FeedPost(
      id: id,
      uid: map['uid'] ?? '',
      username: map['username'] ?? 'User',
      platform: map['platform'] ?? 'manual',
      verified: map['verified'] as bool? ?? false,
      content: map['content'] ?? '',
      caption: map['caption'] ?? '',
      xpEarned: map['xpEarned'] as int? ?? 0,
      likes: map['likes'] as int? ?? 0,
      timestamp: map['timestamp'] as int? ?? 0,
    );
  }
}

class FeedService {
  static final _db = FirebaseDatabase.instance.ref();

  static String? get _uid => AuthService.firebase().currentUser?.id;
  static String get _username =>
      AuthService.firebase().currentUser?.email?.split('@').first ?? 'user';

  // ── Post a verified achievement ─────────────────────────────────────────
  static Future<void> postAchievement({
    required String platform,
    required String content,
    String caption = '',
    required int xpEarned,
    bool verified = true,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final ref = _db.child('feed').push();
    await ref.set({
      'uid':       uid,
      'username':  _username,
      'platform':  platform,
      'verified':  verified,
      'content':   content,
      'caption':   caption,
      'xpEarned':  xpEarned,
      'likes':     0,
      'timestamp': ServerValue.timestamp,
    });
  }

  // ── Convenience: post after LeetCode POTD verified ───────────────────────
  static Future<void> postLeetCodeSolved({
    required String problemTitle,
    required String difficulty,
    bool isPOTD = false,
    String caption = '',
  }) async {
    final label = isPOTD ? 'POTD · $difficulty' : difficulty;
    await postAchievement(
      platform:  'leetcode',
      content:   'Solved $problemTitle · $label',
      caption:   caption,
      xpEarned:  isPOTD ? 50 : 30,
    );
  }

  // ── Convenience: post CF problem solved ─────────────────────────────────
  static Future<void> postCFSolved({
    required String problemName,
    required String contestId,
    String caption = '',
  }) async {
    await postAchievement(
      platform: 'codeforces',
      content:  'Solved $problemName (CF $contestId)',
      caption:  caption,
      xpEarned: 50,
    );
  }

  // ── Convenience: post streak milestone ──────────────────────────────────
  static Future<void> postStreak(int days) async {
    await postAchievement(
      platform: 'focusflow',
      content:  '$days-day focus streak! 🔥',
      xpEarned: days >= 30 ? 500 : days >= 7 ? 100 : 30,
    );
  }

  // ── Toggle like ─────────────────────────────────────────────────────────
  static Future<void> toggleLike(String postId, bool isLiked) async {
    await _db.child('feed/$postId/likes').set(
      ServerValue.increment(isLiked ? 1 : -1),
    );
  }

  // ── Delete own post ─────────────────────────────────────────────────────
  static Future<void> deletePost(String postId) async {
    await _db.child('feed/$postId').remove();
  }

  // ── Community feed stream (latest 50 posts) ──────────────────────────────
  static Stream<List<FeedPost>> feedStream() {
    return _db
        .child('feed')
        .orderByChild('timestamp')
        .limitToLast(50)
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return [];
      final raw = Map<String, dynamic>.from(event.snapshot.value as Map);
      return raw.entries
          .map((e) => FeedPost.fromMap(
              e.key, e.value as Map<dynamic, dynamic>))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  // ── My posts stream ─────────────────────────────────────────────────────
  static Stream<List<FeedPost>> myPostsStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return feedStream().map(
      (posts) => posts.where((p) => p.uid == uid).toList(),
    );
  }
}