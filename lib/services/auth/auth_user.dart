import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  final String id;
  final String? email;
  final bool isEmailVeified;
  const AuthUser({
    required this.id,
    this.email,
    required this.isEmailVeified
    });

  factory AuthUser.fromFirebase(User user) => 
  AuthUser(
    id: user.uid,
    email: user.email,
    isEmailVeified: user.emailVerified
    );

}