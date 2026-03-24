import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  final String id;
  final bool isEmailVeified;
  const AuthUser({
    required this.id,
    required this.isEmailVeified
    });

  factory AuthUser.fromFirebase(User user) => 
  AuthUser(
    id: user.uid,
    isEmailVeified: user.emailVerified
    );

}