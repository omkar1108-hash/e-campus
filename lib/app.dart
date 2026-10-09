import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_controller.dart';
import 'services/backend.dart';
import 'services/chatbot_service.dart';
import 'services/demo_location_source.dart';
import 'services/image_service.dart';
import 'services/location_source.dart';
import 'services/route_service.dart';
import 'services/trip_controller.dart';

class ECampusApp extends StatelessWidget {
  const ECampusApp({
    super.key,
    required this.backend,
    this.locationSource,
    this.imagePicker,
    this.routeService,
  });

  final Backend backend;

  /// Where bus GPS positions come from (a fake one is used in demo mode).
  final LocationSource? locationSource;

  /// Where gallery / camera pictures come from (a fake one in tests).
  final ImagePickerService? imagePicker;

  /// Where bus routes and travel times come from (a fake one in tests).
  final RouteService? routeService;

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
        Provider<RouteCache>(
          create: (_) => RouteCache(routeService ?? OsrmRouteService()),
        ),
        Provider<ImagePickerService>.value(
          value: imagePicker ?? DeviceImagePicker(),
        ),
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
