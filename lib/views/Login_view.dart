import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:FocusFlow/firebase_options.dart';

class Login_view extends StatefulWidget {
  const Login_view({super.key});

  @override
  State<Login_view> createState() => _Login_viewState();
}

class _Login_viewState extends State<Login_view> {
  late final TextEditingController _email;
  late final TextEditingController _password;

  @override
  void initState() {
    _email = TextEditingController();
    _password = TextEditingController();

    super.initState();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Login'),
      ),
      body: FutureBuilder(
        future: Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform
        ),
        builder: (context, asyncSnapshot) {
          return Column(
            children: [
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(hintText: 'Enter the email here'),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(hintText: 'Enter the password here'),
              ),
              TextButton(
                onPressed: () async {
                  final email = _email.text;
                  final password = _password.text;
                  try {
                    final credentials = await FirebaseAuth.instance
    .signInWithEmailAndPassword(email: email, password: password);
print(credentials);
if (context.mounted) {
  Navigator.of(context).pushNamedAndRemoveUntil(
    '/home',
    (route) => false,
  );
}
                  } on FirebaseAuthException catch (e) {
                    if (e.code == 'invalid-credential') {
                      print('User not found');
                    } else {
                      print('Something has happened');
                      print(e.code);
                    }
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Login'),
              ),
            ],
          );
        }
      ),
    );
  }
}
