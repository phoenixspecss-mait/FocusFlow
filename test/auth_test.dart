import 'package:FocusFlow/services/auth/auth_exceptions.dart';
import 'package:FocusFlow/services/auth/auth_provider.dart';
import 'package:FocusFlow/services/auth/auth_user.dart';
import 'package:test/test.dart';

void main() {
  group('MockAuthProvider', () {                          // FIX 1: String, not instance
    final provider = MockAuthProvider();
    test('Should not be initialized to begin with ', () {
      expect(provider.isinitialized, false);
    });

    test('Cannot log out if not initialized', () {
      expect(
        provider.Logout(),
        throwsA(const TypeMatcher<NotInitializedException>()),
      );
    });
    test('Should be able to be initialized', () async {
      await provider.initialize();
      expect(provider.isinitialized, true);
    });

    test('User should be null after initialization', () {
      expect(provider.currentUser, null);
    });

    test(
      'Should be able to initialize before 2 seconds',
      () async {
        await provider.initialize();
        expect(provider.isinitialized, true);
      },
      timeout: const Timeout(Duration(seconds: 2)),
    );

    test('Create user should delegate to login function', () async {
      final badEmailuser = provider.createUser(
        email: 'foo@bar.com',
        password: 'foobarbaz',
      );
      expect(badEmailuser, throwsA(const TypeMatcher<UserNotFoundException>()));

      final user = await provider.createUser(
        email: 'someone@valid.com',                       // FIX 2: valid email
        password: 'foobarbaz',
      );
      expect(provider.currentUser, user);
      expect(user.isEmailVeified, false);
    });

    test('Logged i user should be able to get verified ', () {
      provider.sendEmailVerification();
      final user = provider.currentUser;
      expect(user, isNotNull);
      expect(user!.isEmailVeified, true);
    });

    test('Should be able to log out and log in agian', () async {
      await provider.Logout();
      await provider.logIn(
        email: 'someone@valid.com',                       // FIX 3: valid email
        password: 'foobarbaz',
      );
      final user = provider.currentUser;                  // FIX 4: moved inside test
      expect(user, isNotNull);                            // FIX 4: moved inside test
    });
  });
}

class NotInitializedException implements Exception {}

class MockAuthProvider implements AuthProvider {
  AuthUser? _user;
  var _isinitialized = false;
  bool get isinitialized => _isinitialized;               // FIX 5: was recursive
  @override
  Future<void> Logout() async {
    if (!isinitialized) throw NotInitializedException();
    if (_user == null) throw UserNotFoundException();
    await Future.delayed(Duration(seconds: 1));
    _user = null;
  }

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) async {
    if (!isinitialized) throw NotInitializedException();
    await Future.delayed(Duration(seconds: 1));
    return logIn(email: email, password: password);
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  Future<AuthUser> getupdateduser() {
    throw UnimplementedError();
  }

  @override
  Future<void> initialize() async {
    await Future.delayed(Duration(seconds: 1));
    _isinitialized = true;
  }

  @override
  Future<AuthUser> logIn({required String email, required String password}) {
    if (!isinitialized) throw NotInitializedException();
    if (email == 'foo@bar.com') throw UserNotFoundException(); // FIX 6: wrong exception
    if (password == 'foobar') throw WrongPassAuthException();
    const user = AuthUser(id: 'test-id', isEmailVeified: false);
    _user = user;
    return Future.value(user);
  }

  @override
  Future<void> sendEmailVerification() async {
    if (!isinitialized) throw NotInitializedException();
    final user = _user;
    if (user == null) throw UserNotFoundException();
    const newuser = AuthUser(id: 'test-id', isEmailVeified: true);
    _user = newuser;
  }
}