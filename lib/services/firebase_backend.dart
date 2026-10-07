import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/book.dart';
import '../models/bus_location.dart';
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
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String department,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user!;
      try {
        // New accounts are always students; an admin promotes them later.
        await _users
            .doc(user.uid)
            .set(
              AppUser(
                uid: user.uid,
                email: email,
                name: name,
                department: department,
                role: UserRole.student,
              ).toMap(),
            );
        await user.sendEmailVerification();
      } catch (_) {
        // Don't leave an account without a profile behind.
        await user.delete();
        rethrow;
      }
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authMessage(e));
    }
  }

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
    return _profileOf(user.uid);
  }

  Future<AppUser?> _profileOf(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? AppUser.fromMap(uid, doc.data()!) : null;
  }

  @override
  Future<void> signOut() => _auth.signOut();

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

  // ---- Users ------------------------------------------------------------
  @override
  Stream<List<AppUser>> watchUsers() => _users.snapshots().map(
    (s) =>
        s.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
  );

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

  // ---- Bus --------------------------------------------------------------
  DocumentReference<Map<String, dynamic>> get _bus =>
      _db.collection('bus').doc('current');

  @override
  Stream<BusLocation?> watchBus() => _bus.snapshots().map((d) {
    final data = d.data();
    return data == null ? null : BusLocation.fromMap(data);
  });

  @override
  Future<void> updateBus(BusLocation location) => _bus.set(location.toMap());
}
