class DatabaseTask {
  final String id;
  final String ownerUserId;
  final String title;
  final bool completed;
  final String createdAt;

  DatabaseTask({
    required this.id,
    required this.ownerUserId,
    required this.title,
    required this.completed,
    required this.createdAt,
  });

  factory DatabaseTask.fromSnapshot(Map<dynamic, dynamic> map, String id) {
    return DatabaseTask(
      id: id,
      ownerUserId: map['ownerUserId'] ?? '',
      title: map['title'] ?? '',
      completed: map['completed'] ?? false,
      createdAt: map['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerUserId': ownerUserId,
      'title': title,
      'completed': completed,
      'createdAt': createdAt,
    };
  }
}