import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/book.dart';
import '../models/bus_location.dart';
import '../models/chat_message.dart';
import '../models/news_item.dart';
import 'backend.dart';

/// Production backend: Firebase Auth (phone OTP) + Cloud Firestore.
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
  Future<OtpSession> sendOtp(String phone) {
    final completer = Completer<OtpSession>();
    _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Android may auto-retrieve the SMS; sign in straight away.
        try {
          await _auth.signInWithCredential(credential);
        } catch (_) {}
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.completeError(
            AuthException(e.message ?? 'Could not send OTP (${e.code})'),
          );
        }
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) {
          completer.complete(
            OtpSession(phone: phone, verificationId: verificationId),
          );
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  @override
  Future<AppUser?> verifyOtp(OtpSession session, String code) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: session.verificationId,
        smsCode: code,
      );
      await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        e.code == 'invalid-verification-code'
            ? 'Incorrect OTP. Please try again.'
            : e.message ?? 'Verification failed',
      );
    }
    return restoreSession();
  }

  @override
  Future<AppUser?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _users.doc(user.uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(user.uid, doc.data()!);
  }

  @override
  Future<AppUser> registerProfile({
    required String name,
    required String department,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('Not signed in');
    // New accounts are always students; an admin promotes them later.
    final profile = AppUser(
      uid: user.uid,
      phone: user.phoneNumber ?? '',
      name: name,
      department: department,
      role: UserRole.student,
    );
    await _users.doc(user.uid).set(profile.toMap());
    return profile;
  }

  @override
  Future<void> signOut() => _auth.signOut();

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
