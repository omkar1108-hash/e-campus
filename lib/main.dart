import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/backend.dart';
import 'services/demo_backend.dart';
import 'services/firebase_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ECampusApp(backend: await _createBackend()));
}

/// Uses Firebase when the project has been configured (google-services.json
/// present); otherwise falls back to the in-memory demo backend so the app
/// still runs end to end.
Future<Backend> _createBackend() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
    return FirebaseBackend();
  } catch (e) {
    debugPrint('Firebase unavailable ($e) - running in demo mode.');
    return DemoBackend();
  }
}
