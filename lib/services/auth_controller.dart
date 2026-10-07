import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'backend.dart';

enum AuthStatus { loading, signedOut, signedIn }

/// Holds the signed-in user and drives sign-in / sign-up.
class AuthController extends ChangeNotifier {
  AuthController(this.backend);

  final Backend backend;

  AuthStatus _status = AuthStatus.loading;
  AppUser? _user;

  AuthStatus get status => _status;
  AppUser? get user => _user;

  Future<void> init() async {
    try {
      _user = await backend.restoreSession();
    } catch (_) {
      _user = null;
    }
    _status = _user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    _user = await backend.signIn(email.trim(), password);
    _status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String department,
  }) => backend.signUp(
    email: email.trim(),
    password: password,
    name: name,
    department: department,
  );

  Future<void> sendPasswordReset(String email) =>
      backend.sendPasswordReset(email.trim());

  Future<void> signOut() async {
    await backend.signOut();
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }
}
