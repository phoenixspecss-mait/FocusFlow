class DatabaseNote {
  final String id;
  final String ownerUserId;
  final String text;
  final bool completed;

  DatabaseNote({
    required this.id,
    required this.ownerUserId,
    required this.text,
    required this.completed,
  });

  // Convert Firebase snapshot to DatabaseNote
  factory DatabaseNote.fromSnapshot(Map<dynamic, dynamic> map, String id) {
    return DatabaseNote(
      id: id,
      ownerUserId: map['ownerUserId'] ?? '',
      text: map['text'] ?? '',
      completed: map['completed'] ?? false,
    );
  }

  // Convert DatabaseNote to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'ownerUserId': ownerUserId,
      'text': text,
      'completed': completed,
    };
  }
}