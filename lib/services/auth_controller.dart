import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'backend.dart';

enum AuthStatus { loading, signedOut, signedIn }

/// Holds the signed-in user and drives sign-in. Accounts are created by
/// administrators (see the Manage Users screen), not by users themselves.
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

  Future<void> sendPasswordReset(String email) =>
      backend.sendPasswordReset(email.trim());

  Future<void> signOut() async {
    await backend.signOut();
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }
}
