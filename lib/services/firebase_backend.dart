import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/book.dart';
import '../models/bus.dart';
import '../models/chat_message.dart';
import '../models/news_item.dart';
import 'backend.dart';

/// Production backend: Firebase Auth (email + password) + Cloud Firestore.
class FirebaseBackend implements Backend {
  FirebaseBackend({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  bool get isDemo => false;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // ---- Auth -------------------------------------------------------------
  @override
  Future<AppUser> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user!;
      await user.reload();
      final fresh = _auth.currentUser ?? user;
      if (!fresh.emailVerified) {
        try {
          await fresh.sendEmailVerification();
        } catch (_) {}
        await _auth.signOut();
        throw AuthException(
          'Your email is not verified yet. We sent a new verification link '
          'to $email - open it, then sign in again.',
        );
      }
      final profile = await _profileOf(fresh.uid);
      if (profile == null) {
        await _auth.signOut();
        throw const AuthException(
          'No profile found for this account. Please contact an administrator.',
        );
      }
      if (!profile.active) {
        await _auth.signOut();
        throw const AuthException(
          'Your account has been disabled. Please contact an administrator.',
        );
      }
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authMessage(e));
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authMessage(e));
    }
  }

  @override
  Future<AppUser?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) return null;
    final profile = await _profileOf(user.uid);
    if (profile == null || !profile.active) {
      await _auth.signOut();
      return null;
    }
    return profile;
  }

  Future<AppUser?> _profileOf(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? AppUser.fromMap(uid, doc.data()!) : null;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  // ---- Accounts ---------------------------------------------------------
  /// A second Firebase app instance is used to create the login, because
  /// creating a user on the default instance would sign the admin out.
  Future<FirebaseAuth> _creatorAuth() async {
    const name = 'account-creator';
    FirebaseApp app;
    try {
      app = Firebase.app(name);
    } catch (_) {
      app = await Firebase.initializeApp(
        name: name,
        options: Firebase.app().options,
      );
    }
    return FirebaseAuth.instanceFor(app: app);
  }

  static String _randomPassword() {
    const chars =
        'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#%';
    final rnd = Random.secure();
    return List.generate(24, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  @override
  Future<void> createAccount({
    required String email,
    required String name,
    required String department,
    required UserRole role,
    Gender? gender,
  }) async {
    final address = email.trim().toLowerCase();
    final creator = await _creatorAuth();
    User? created;
    try {
      // The new person never learns this password; they set their own
      // through the emailed link.
      final cred = await creator.createUserWithEmailAndPassword(
        email: address,
        password: _randomPassword(),
      );
      created = cred.user!;
      try {
        await _users
            .doc(created.uid)
            .set(
              AppUser(
                uid: created.uid,
                email: address,
                name: name,
                department: department,
                role: role,
                gender: gender,
              ).toMap(),
            );
      } catch (_) {
        // Don't leave a login without a profile behind.
        await created.delete();
        created = null;
        rethrow;
      }
      try {
        await created.sendEmailVerification();
        await creator.sendPasswordResetEmail(email: address);
      } catch (_) {
        throw const AuthException(
          'The account was created, but the emails could not be sent. '
          'Open the user and tap "Resend setup email".',
        );
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authMessage(e));
    } finally {
      await creator.signOut();
    }
  }

  static String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak - use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }

  @override
  Stream<List<AppUser>> watchUsers() => _users.snapshots().map(
    (s) =>
        s.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
  );

  @override
  Future<void> updateUser(AppUser user) => _users.doc(user.uid).update({
    'name': user.name,
    'department': user.department,
    'role': user.role.name,
    if (user.gender != null) 'gender': user.gender!.name,
  });

  @override
  Future<void> setUserActive(String uid, bool active) =>
      _users.doc(uid).update({'active': active});

  @override
  Future<void> setUserRole(String uid, UserRole role) =>
      _users.doc(uid).update({'role': role.name});

  // ---- Books ------------------------------------------------------------
  @override
  Stream<List<Book>> watchBooks() => _db
      .collection('books')
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => Book.fromMap(d.id, d.data())).toList()
              ..sort((a, b) => a.title.compareTo(b.title)),
      );

  @override
  Future<void> addBook(Book book) => _db.collection('books').add(book.toMap());

  @override
  Future<void> deleteBook(String id) =>
      _db.collection('books').doc(id).delete();

  // ---- News -------------------------------------------------------------
  @override
  Stream<List<NewsItem>> watchNews(String department) => _db
      .collection('news')
      .where('department', isEqualTo: department)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => NewsItem.fromMap(d.id, d.data())).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  @override
  Future<void> addNews(NewsItem item) =>
      _db.collection('news').add(item.toMap());

  @override
  Future<void> deleteNews(String id) => _db.collection('news').doc(id).delete();

  // ---- Chat -------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _db.collection('chats').doc(chatId).collection('messages');

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) => _messages(chatId)
      .orderBy('sentAt')
      .snapshots()
      .map(
        (s) => s.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList(),
      );

  @override
  Future<void> sendMessage(String chatId, ChatMessage message) =>
      _messages(chatId).add(message.toMap());

  // ---- Buses ------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _buses =>
      _db.collection('buses');

  @override
  Stream<List<Bus>> watchBuses(AppUser viewer) {
    // The query must match what the security rules allow this role to read.
    final Query<Map<String, dynamic>> query;
    switch (viewer.role) {
      case UserRole.admin:
      case UserRole.adminStaff:
      case UserRole.teacher:
      case UserRole.libraryStaff:
        query = _buses;
      case UserRole.busDriver:
        query = _buses.where('driverUid', isEqualTo: viewer.uid);
      case UserRole.student:
      case UserRole.classRep:
        query = _buses.where('departments', arrayContains: viewer.department);
    }
    return query.snapshots().map(
      (s) =>
          s.docs.map((d) => Bus.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  @override
  Future<void> saveBus(Bus bus) async {
    if (bus.id.isEmpty) {
      await _buses.add({...bus.configMap(), 'active': false});
    } else {
      await _buses.doc(bus.id).update(bus.configMap());
    }
  }

  @override
  Future<void> deleteBus(String id) => _buses.doc(id).delete();

  @override
  Future<void> startTrip(String busId, double lat, double lng) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _buses.doc(busId).update({
      'active': true,
      'lat': lat,
      'lng': lng,
      'updatedAt': now,
      'tripStartedAt': now,
    });
  }

  @override
  Future<void> updateTripLocation(String busId, double lat, double lng) =>
      _buses.doc(busId).update({
        'lat': lat,
        'lng': lng,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

  @override
  Future<void> endTrip(String busId) =>
      _buses.doc(busId).update({'active': false});
}
