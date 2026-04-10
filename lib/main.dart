import 'package:flutter/material.dart';
import 'package:FocusFlow/services/auth/auth_service.dart';
import 'package:FocusFlow/services/streak_service.dart';
import 'package:FocusFlow/views/app_shell.dart';
import 'package:FocusFlow/views/Register_Login_View.dart';
import 'package:FocusFlow/services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.load();
  runApp(const FocusFlowApp());
}

class FocusFlowApp extends StatefulWidget {
  const FocusFlowApp({super.key});

  @override
  State<FocusFlowApp> createState() => _FocusFlowAppState();
}

class _FocusFlowAppState extends State<FocusFlowApp> {
  late final Future<void> _authInitialization;

  @override
  void initState() {
    super.initState();
    _authInitialization = AuthService.firebase().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        final isLight = SettingsService.instance.theme == 'Light';
        return MaterialApp(
          title: 'FocusFlow',
          debugShowCheckedModeBanner: false,
          theme: isLight 
            ? ThemeData.light().copyWith(
                scaffoldBackgroundColor: const Color(0xFFF5F7FA),
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF4F8EF7),
                  surface: Color(0xFFFFFFFF),
                ),
              )
            : ThemeData.dark().copyWith(
                scaffoldBackgroundColor: const Color(0xFF0D0F14),
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF4F8EF7),
                  surface: Color(0xFF161920),
                ),
              ),
          routes: {
            '/home': (context) => const AppShell(),
            '/login': (context) => const Register_Login_View(),
          },
          home: FutureBuilder(
            future: _authInitialization,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Scaffold(
                  backgroundColor: isLight ? const Color(0xFFF5F7FA) : const Color(0xFF0D0F14),
                  body: const Center(child: CircularProgressIndicator(color: Color(0xFF4F8EF7))),
                );
              }
              final user = AuthService.firebase().currentUser;
              if (user != null) {
                // Check + update streak on every app open
                StreakService.checkAndUpdate();
                return const AppShell();
              }
              return const Register_Login_View();
            },
          ),
        );
      },
    );
  }
}