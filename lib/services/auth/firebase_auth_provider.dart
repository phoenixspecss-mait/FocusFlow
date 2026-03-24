import 'package:firebase_core/firebase_core.dart';
import 'package:FocusFlow/services/auth/auth_provider.dart';
import 'package:FocusFlow/services/auth/auth_exceptions.dart';
import 'package:FocusFlow/services/auth/auth_user.dart';
import 'package:FocusFlow/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuth, FirebaseAuthException;
import 'package:FocusFlow/services/database/database_service.dart';
class FirebaseAuthProvider implements AuthProvider {
  @override
  Future<AuthUser> getupdateduser() async {
    final user = FirebaseAuth.instance.currentUser;
    if(user != null){
      await user.reload();
      final freshuser = FirebaseAuth.instance.currentUser;
      return AuthUser.fromFirebase(freshuser!);
    }else{
      throw UserNotLoggedinException();
    }
  }
  @override
  Future<void> Logout() async{
    final user = FirebaseAuth.instance.currentUser;
    if (user !=null){
      await FirebaseAuth.instance.signOut();
    }else{
      throw UserNotLoggedinException();
    }
  }

  @override
Future<AuthUser> createUser({
  required String email,
  required String password,
}) async {
  try {
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = currentUser;
    if (user != null) {

      // ← ADD THIS: create user in database after signup
      await DatabaseService.firebase().createUser(
        ownerUserId: user.id,
      );

      return user;
    } else {
      throw UserNotLoggedinException();
    }
  } on FirebaseAuthException catch (e) {
    if (e.code == 'weak-password') {
      throw WeakPassowrdExcetion();
    } else if (e.code == 'email-already-in-use') {
      throw EmailAlreadyInUseException();
    } else if (e.code == 'invalid-email') {
      throw InvalidEmailException();
    } else {
      throw GenericAuthException();
    }
  } catch (_) {
    throw GenericAuthException();
  }
}

  @override
  // TODO: implement currentUser
  AuthUser? get currentUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return AuthUser.fromFirebase(user);
    } else {
      return null;
    }
  }

  @override
  Future<AuthUser> logIn({
    required String email,
    required String password,
  })async{
    try{
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email, 
        password: password,
        );
         final user = currentUser;
      if (user != null) {
        return user;
      } else {
        throw UserNotLoggedinException();
      }
    }on FirebaseAuthException catch(e){
      if(e.code == 'user-not-found'){
        throw UserNotFoundException();
      }else if(e.code == 'wrong-password'){
        throw WrongPassAuthException();
      }else{
        throw  GenericAuthException();
      }
    }catch (e){
      throw GenericAuthException();
    }
  }

  @override
  Future<void> sendEmailVerification() async{
    final user = FirebaseAuth.instance.currentUser;
    if(user != null){
      await user.sendEmailVerification();
    }else{
      throw UserNotLoggedinException();
    }
  }
  
  @override
  Future<void> initialize() async{
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform
    );
  }
}
