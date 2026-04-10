class DatabaseHabit {
  final String id;
  final String ownerUserId;
  final String title;
  final List<String> completedDates;
  final String createdAt;

  DatabaseHabit({
    required this.id,
    required this.ownerUserId,
    required this.title,
    required this.completedDates,
    required this.createdAt,
  });

  factory DatabaseHabit.fromSnapshot(Map<dynamic, dynamic> map, String id) {
    return DatabaseHabit(
      id: id,
      ownerUserId: map['ownerUserId'] ?? '',
      title: map['title'] ?? '',
      completedDates: List<String>.from(map['completedDates'] ?? []),
      createdAt: map['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerUserId': ownerUserId,
      'title': title,
      'completedDates': completedDates,
      'createdAt': createdAt,
    };
  }
}