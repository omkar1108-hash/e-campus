import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/auth_controller.dart';
import 'services/backend.dart';
import 'services/chatbot_service.dart';

class ECampusApp extends StatelessWidget {
  const ECampusApp({super.key, required this.backend});

  final Backend backend;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Backend>.value(value: backend),
        Provider<ChatbotService>(create: (_) => ChatbotService()),
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(backend)..init(),
        ),
      ],
      child: MaterialApp(
        title: 'E-Campus',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B4B9B)),
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

/// Chooses the screen from the current authentication state.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    switch (auth.status) {
      case AuthStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.needsProfile:
        return const RegisterScreen();
      case AuthStatus.signedIn:
        return const HomeScreen();
    }
  }
}
