class DatabaseTask {
  final String id;
  final String ownerUserId;
  final String title;
  final bool completed;
  final String createdAt;

  // Platform-sync fields (null for manual tasks)
  final String? platform;   // 'leetcode' | 'codeforces' | 'codechef' | 'github'
  final bool verified;      // true once auto-verified by TaskVerifier
  final bool isPOTD;        // true if this is a POTD task
  final String? problemSlug;
  final String? contestId;
  final String? problemIndex;

  DatabaseTask({
    required this.id,
    required this.ownerUserId,
    required this.title,
    required this.completed,
    required this.createdAt,
    this.platform,
    this.verified = false,
    this.isPOTD = false,
    this.problemSlug,
    this.contestId,
    this.problemIndex,
  });

  bool get isTrackable => platform != null && platform != 'manual';

  factory DatabaseTask.fromSnapshot(Map<dynamic, dynamic> map, String id) {
    final plat = map['platform'] as String?;
    return DatabaseTask(
      id: id,
      ownerUserId: map['ownerUserId'] ?? '',
      title: map['title'] ?? '',
      completed: map['completed'] ?? false,
      createdAt: map['createdAt'] ?? '',
      platform: (plat == 'manual') ? null : plat,
      verified: map['verified'] as bool? ?? false,
      isPOTD: map['isPOTD'] as bool? ?? false,
      problemSlug: map['problemSlug'] as String?,
      contestId: map['contestId'] as String?,
      problemIndex: map['problemIndex'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerUserId': ownerUserId,
      'title': title,
      'completed': completed,
      'createdAt': createdAt,
      if (platform != null) 'platform': platform,
      'verified': verified,
      'isPOTD': isPOTD,
      if (problemSlug != null) 'problemSlug': problemSlug,
      if (contestId != null) 'contestId': contestId,
      if (problemIndex != null) 'problemIndex': problemIndex,
    };
  }
}