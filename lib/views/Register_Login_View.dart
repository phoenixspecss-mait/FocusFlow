import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:FocusFlow/services/auth/auth_exceptions.dart';
import 'package:FocusFlow/services/auth/auth_service.dart';

class Register_Login_View extends StatefulWidget {
  const Register_Login_View({super.key});
  @override
  State<Register_Login_View> createState() => _FocusFlowState();
}

class _FocusFlowState extends State<Register_Login_View> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _loading = false;

  @override
  void initState() {
    _name     = TextEditingController();
    _email    = TextEditingController();
    _password = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SingleChildScrollView(
        child: Column(children: [
          Image.asset('assets/images/ic_launcher_foreground.png'),
          const Padding(padding: EdgeInsets.all(22)),
          const Text(
            "'Your future self is watching'",
            style: TextStyle(
                fontFamily: 'medifont2', fontSize: 20,
                color: Colors.white, fontStyle: FontStyle.italic),
          ),
          const Padding(padding: EdgeInsets.all(7)),
          const Text("Welcome. Leave the noise outside",
              style: TextStyle(color: Colors.white, fontFamily: "medifont2")),
          const Padding(padding: EdgeInsets.all(15)),
          Row(children: [
            Expanded(child: Divider(color: Colors.white, thickness: 1, indent: 10, endIndent: 10)),
            const Text("Login or Sign Up", style: TextStyle(color: Colors.white)),
            Expanded(child: Divider(color: Colors.white, thickness: 1, indent: 10, endIndent: 10)),
          ]),
          const Padding(padding: EdgeInsets.all(10)),
          // ── Name field (new) ──
          _buildField(controller: _name,    hint: 'Your name',         icon: Icons.person_outline),
          const Padding(padding: EdgeInsets.all(6)),
          _buildField(controller: _email,   hint: 'Enter your email',  icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress),
          const Padding(padding: EdgeInsets.all(6)),
          _buildField(controller: _password, hint: 'Enter password',   icon: Icons.lock_outline,
              obscureText: true),
          const Padding(padding: EdgeInsets.all(20)),
          _loading
              ? const CircularProgressIndicator(color: Color(0xFF4F8EF7))
              : TextButton(
                  onPressed: _handleSubmit,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF4F8EF7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Log In / Sign Up',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return SizedBox(
      width: 350,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.white54, size: 20),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white, width: 1.5),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final email    = _email.text.trim();
    final password = _password.text;
    final name     = _name.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack("Please enter email and password", Colors.red);
      return;
    }

    setState(() => _loading = true);

    try {
      // Try registering first
      await AuthService.firebase().createUser(email: email, password: password);

      // Save name to Firebase if provided
      final uid = AuthService.firebase().currentUser?.id;
      if (uid != null && name.isNotEmpty) {
        await FirebaseDatabase.instance.ref()
            .child("users/$uid")
            .update({"name": name});
      }

      await AuthService.firebase().sendEmailVerification();
      _showSnack("Verification email sent!", Colors.green);
      if (mounted) {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VerifyEmailView()));
      }
    } on EmailAlreadyInUseException {
      // Already registered → try login
      try {
        await AuthService.firebase().logIn(email: email, password: password);
        final user = await AuthService.firebase().getupdateduser();
        if (user.isEmailVeified) {
          _showSnack("Welcome back!", Colors.green);
          if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
        } else {
          await AuthService.firebase().Logout();
          _showSnack("Please verify your email first", Colors.orange);
        }
      } on WrongPassAuthException {
        _showSnack("Incorrect password. Try again.", Colors.red);
      } catch (_) {
        _showSnack("Something went wrong. Try again.", Colors.red);
      }
    } on WeakPassowrdExcetion {
      _showSnack("Password must be at least 6 characters", Colors.red);
    } on InvalidEmailException {
      _showSnack("Please enter a valid email", Colors.red);
    } catch (_) {
      _showSnack("Something went wrong. Try again.", Colors.red);
    }

    if (mounted) setState(() => _loading = false);
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }
}

// ── Email verify screen (unchanged) ──────────────────────────────────────────
class VerifyEmailView extends StatefulWidget {
  const VerifyEmailView({super.key});
  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _check() async {
    final user = AuthService.firebase().currentUser;
    await AuthService.firebase().getupdateduser();
    if (user?.isEmailVeified ?? false) {
      _timer?.cancel();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed('/home');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Verify Email', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF4F8EF7)),
          SizedBox(height: 24),
          Text('Checking your verification status...',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text('Please click the link in the email we sent you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      )),
    );
  }
}