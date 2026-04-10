class DatabaseTimer {
  final String id;
  final String ownerUserId;
  final int focusMinutes;
  final int breakMinutes;
  final String createdAt;

  DatabaseTimer({
    required this.id,
    required this.ownerUserId,
    required this.focusMinutes,
    required this.breakMinutes,
    required this.createdAt,
  });

  factory DatabaseTimer.fromSnapshot(Map<dynamic, dynamic> map, String id) {
    return DatabaseTimer(
      id: id,
      ownerUserId: map['ownerUserId'] ?? '',
      focusMinutes: map['focusMinutes'] ?? 25,
      breakMinutes: map['breakMinutes'] ?? 5,
      createdAt: map['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerUserId': ownerUserId,
      'focusMinutes': focusMinutes,
      'breakMinutes': breakMinutes,
      'createdAt': createdAt,
    };
  }
}
