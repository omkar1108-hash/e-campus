import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'backend.dart';

enum AuthStatus { loading, signedOut, needsProfile, signedIn }

/// Holds the signed-in user and drives the login → OTP → register flow.
class AuthController extends ChangeNotifier {
  AuthController(this.backend);

  final Backend backend;

  AuthStatus _status = AuthStatus.loading;
  AppUser? _user;

  AuthStatus get status => _status;
  AppUser? get user => _user;

  Future<void> init() async {
    _user = await backend.restoreSession();
    _status = _user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    notifyListeners();
  }

  Future<OtpSession> sendOtp(String phone) => backend.sendOtp(phone);

  Future<void> verifyOtp(OtpSession session, String code) async {
    _user = await backend.verifyOtp(session, code);
    _status = _user == null ? AuthStatus.needsProfile : AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String department,
  }) async {
    _user = await backend.registerProfile(name: name, department: department);
    _status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> signOut() async {
    await backend.signOut();
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }
}
