import 'package:flutter/widgets.dart';

@immutable
class databaseuser {
  final int id;
  final String email;
  const databaseuser({required this.id, required this.email});

  databaseuser.fromRow(Map<String, Object?> map)
    : id = map[idcolumn] as int,
      email = map[emailcolumn] as String;

    @override
    String tostring() => 'Person, ID = $id, email = $email';

    @override bool operator == (covariant databaseuser other) => id == other.id;
}

const idcolumn = 'id';
const emailcolumn = 'email';
