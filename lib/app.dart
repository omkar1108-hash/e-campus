import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_controller.dart';
import 'services/backend.dart';
import 'services/chatbot_service.dart';
import 'services/demo_location_source.dart';
import 'services/location_source.dart';
import 'services/trip_controller.dart';

class ECampusApp extends StatelessWidget {
  const ECampusApp({super.key, required this.backend, this.locationSource});

  final Backend backend;

  /// Where bus GPS positions come from (a fake one is used in demo mode).
  final LocationSource? locationSource;

  @override
  Widget build(BuildContext context) {
    final location =
        locationSource ??
        (backend.isDemo
            ? DemoLocationSource()
            : const GeolocatorLocationSource());
    return MultiProvider(
      providers: [
        Provider<Backend>.value(value: backend),
        Provider<LocationSource>.value(value: location),
        ChangeNotifierProvider<TripController>(
          create: (_) => TripController(backend, location),
        ),
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
      case AuthStatus.signedIn:
        return const HomeScreen();
    }
  }
}
