import 'package:FocusFlow/services/auth/auth_exceptions.dart';
import 'package:FocusFlow/services/auth/auth_provider.dart';
import 'package:FocusFlow/services/auth/auth_user.dart';
import 'package:test/test.dart';

void main() {
  group(mockAuthProvider(), () {
    final provider = mockAuthProvider();
    test('Should not be initialized to begin with ', () {
      expect(provider.isinitialized, false);
    });

    test('Cannot log out if not initialized', () {
      expect(
        provider.Logout(),
        throwsA(const TypeMatcher<notInitializedexception>()),
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
        email: 'foo@bar.com',
        password: 'foobarbaz',
      );
      expect(provider.currentUser, user);
      expect(user.isEmailVeified, false);
    });

    test('Logged i user should be able to get verified ', (){
      provider.sendEmailVerification();
      final user = provider.currentUser;
      expect(user, isNotNull);
      expect(user!.isEmailVeified,true);
    });

    test('Should be able to log out and log in agian',()async{
      await provider.Logout();
      await provider.logIn(email: 'foo@bar.com', password: 'foobarbaz');
    });

    final user = provider.currentUser;
    expect(user, isNotNull);
  });
}

class notInitializedexception implements Exception {}

class mockAuthProvider implements AuthProvider {
  AuthUser? _user;
  var _isinitialized = false;
  bool get isinitialized => isinitialized;
  @override
  Future<void> Logout() async {
    if (!isinitialized) throw notInitializedexception();
    if (_user == null) throw UserNotFoundException();
    await Future.delayed(Duration(seconds: 1));
    _user = null;
  }

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) async {
    if (!isinitialized) throw notInitializedexception();
    await Future.delayed(Duration(seconds: 1));
    return logIn(email: email, password: password);
  }

  @override
  // TODO: implement currentUser
  AuthUser? get currentUser => _user;

  @override
  Future<AuthUser> getupdateduser() {
    // TODO: implement getupdateduser
    throw UnimplementedError();
  }

  @override
  Future<void> initialize() async {
    await Future.delayed(Duration(seconds: 1));
    _isinitialized = true;
  }

  @override
  Future<AuthUser> logIn({required String email, required String password}) {
    if (!isinitialized) throw notInitializedexception();
    if (email == 'foo@bar.com') throw UserNotLoggedinException();
    if (password == 'foobar') throw WrongPassAuthException();
    const user = AuthUser(isEmailVeified: false);
    _user = user;
    return Future.value(user);
  }

  @override
  Future<void> sendEmailVerification() async {
    if (!isinitialized) throw notInitializedexception();
    final user = _user;
    if (user == null) throw UserNotFoundException();
    const newuser = AuthUser(isEmailVeified: true);
    _user = newuser;
  }
}
