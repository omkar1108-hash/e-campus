import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/book.dart';
import '../models/campus.dart';
import '../models/bus.dart';
import '../models/chat_message.dart';
import '../models/news_item.dart';
import '../utils/rbac.dart';
import '../utils/stream_merge.dart';
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

  /// Profile of the signed-in user; named in activity-log entries.
  AppUser? _actor;

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
      _actor = profile;
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
    _actor = profile;
    return profile;
  }

  Future<AppUser?> _profileOf(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? AppUser.fromMap(uid, doc.data()!) : null;
  }

  @override
  Future<void> signOut() {
    _actor = null;
    return _auth.signOut();
  }

  // ---- Activity log -----------------------------------------------------
  /// Best effort: a failed log write never blocks the action itself.
  Future<void> _log(
    String action,
    String targetType,
    String targetLabel, {
    String details = '',
  }) async {
    final me = _actor;
    if (me == null) return;
    try {
      await _db
          .collection('activityLog')
          .add(
            ActivityEntry(
              id: '',
              action: action,
              actorUid: me.uid,
              actorName: me.name,
              actorRole: me.role.name,
              targetType: targetType,
              targetLabel: _clip(targetLabel, 200),
              details: _clip(details, 200),
              createdAt: DateTime.now(),
            ).toMap(),
          );
    } catch (_) {}
  }

  static String _clip(String s, int n) => s.length <= n ? s : s.substring(0, n);

  /// Reads one text field of a document (for naming it in the log).
  Future<String> _field(
    CollectionReference<Map<String, dynamic>> c,
    String id,
    String field,
  ) async {
    try {
      return ((await c.doc(id).get()).data()?[field] ?? id) as String;
    } catch (_) {
      return id;
    }
  }

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
      await _log(
        'account.created',
        'account',
        name,
        details: '${role.label}, $department',
      );
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
  Future<void> updateUser(AppUser user) async {
    await _users.doc(user.uid).update({
      'name': user.name,
      'department': user.department,
      'role': user.role.name,
      if (user.gender != null) 'gender': user.gender!.name,
    });
    await _log(
      'account.updated',
      'account',
      user.name,
      details: '${user.role.label}, ${user.department}',
    );
  }

  @override
  Future<void> setUserActive(String uid, bool active) async {
    final name = await _field(_users, uid, 'name');
    await _users.doc(uid).update({'active': active});
    await _log(
      active ? 'account.enabled' : 'account.disabled',
      'account',
      name,
    );
  }

  @override
  Future<void> setUserRole(String uid, UserRole role) =>
      _users.doc(uid).update({'role': role.name});

  // ---- Books ------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _books =>
      _db.collection('books');

  List<Book> _bookList(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => Book.fromMap(d.id, d.data())).toList();

  @override
  Stream<List<Book>> watchBooks(AppUser viewer) {
    // Each query must match what the security rules allow this role to read.
    final Stream<List<Book>> books;
    if (Rbac.seesAllBooks(viewer)) {
      books = _books.snapshots().map(_bookList);
    } else {
      final approved = _books
          .where('status', isEqualTo: BookStatus.approved.name)
          .snapshots()
          .map(_bookList);
      books = viewer.role == UserRole.teacher
          ? mergeLists(
              approved,
              _books
                  .where('uploadedBy', isEqualTo: viewer.uid)
                  .snapshots()
                  .map(_bookList),
              (b) => b.id,
            )
          : approved;
    }
    return books.map((l) => l..sort((a, b) => a.title.compareTo(b.title)));
  }

  @override
  Future<void> addBook(Book book) => _books.add(book.toMap());

  @override
  Future<void> updateBook(
    Book book, {
    bool resubmit = false,
  }) => _books.doc(book.id).update({
    'title': book.title,
    'author': book.author,
    'category': book.category,
    'url': book.url,
    'isbn': book.isbn,
    'cover': book.cover ?? FieldValue.delete(),
    if (resubmit) ...{'status': BookStatus.pending.name, 'rejectReason': ''},
  });

  @override
  Future<void> reviewBook(
    String id, {
    required bool approve,
    String reason = '',
  }) async {
    final title = await _field(_books, id, 'title');
    await _books.doc(id).update({
      'status': (approve ? BookStatus.approved : BookStatus.rejected).name,
      'rejectReason': approve ? '' : reason,
    });
    await _log(
      approve ? 'book.approved' : 'book.rejected',
      'book',
      title,
      details: approve ? '' : reason,
    );
  }

  @override
  Future<void> deleteBook(String id) async {
    final title = await _field(_books, id, 'title');
    await _books.doc(id).delete();
    await _log('book.deleted', 'book', title);
  }

  @override
  Future<int> approveLegacyBooks() async {
    final all = await _books.get();
    final old = all.docs.where((d) => !d.data().containsKey('status')).toList();
    for (var i = 0; i < old.length; i += 400) {
      final batch = _db.batch();
      for (final d in old.skip(i).take(400)) {
        batch.update(d.reference, {
          'status': BookStatus.approved.name,
          'uploadedBy': '',
        });
      }
      await batch.commit();
    }
    return old.length;
  }

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
  Future<void> deleteNews(String id) async {
    final title = await _field(_db.collection('news'), id, 'title');
    await _db.collection('news').doc(id).delete();
    await _log('news.deleted', 'news', title);
  }

  // ---- Chat -------------------------------------------------------------
  DocumentReference<Map<String, dynamic>> _chat(String chatId) =>
      _db.collection('chats').doc(chatId);

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _chat(chatId).collection('messages');

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) => _messages(chatId)
      .orderBy('sentAt')
      .snapshots()
      .map(
        (s) => s.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList(),
      );

  Map<String, dynamic> _summary(
    String chatId,
    String text,
    int at,
    String sender,
  ) => {
    'participants': chatId.split('_'),
    'lastText': text,
    'lastMessageAt': at,
    'lastSenderId': sender,
  };

  @override
  Future<void> sendMessage(String chatId, ChatMessage message) {
    final batch = _db.batch();
    batch.set(_messages(chatId).doc(), message.toMap());
    batch.set(
      _chat(chatId),
      _summary(
        chatId,
        message.text,
        message.sentAt.millisecondsSinceEpoch,
        message.senderId,
      ),
    );
    return batch.commit();
  }

  @override
  Future<void> editMessage(
    String chatId,
    String messageId,
    String text, {
    bool isLast = false,
  }) {
    final batch = _db.batch();
    batch.update(_messages(chatId).doc(messageId), {
      'text': text,
      'editedAt': DateTime.now().millisecondsSinceEpoch,
    });
    if (isLast) batch.update(_chat(chatId), {'lastText': text});
    return batch.commit();
  }

  @override
  Future<void> deleteMessage(
    String chatId,
    String messageId, {
    bool isLast = false,
  }) {
    final batch = _db.batch();
    batch.update(_messages(chatId).doc(messageId), {
      'deleted': true,
      'text': '',
      'pinned': false,
    });
    if (isLast) batch.update(_chat(chatId), {'lastText': 'Message deleted'});
    return batch.commit();
  }

  @override
  Future<void> setPinned(String chatId, String messageId, bool pinned) =>
      _messages(chatId).doc(messageId).update({'pinned': pinned});

  @override
  Stream<List<ChatSummary>> watchChats(String uid) => _db
      .collection('chats')
      .where('participants', arrayContains: uid)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => ChatSummary.fromMap(d.id, d.data())).toList(),
      );

  DocumentReference<Map<String, dynamic>> _state(String uid) =>
      _db.collection('userState').doc(uid);

  @override
  Stream<Map<String, DateTime>> watchReadMarkers(String uid) =>
      _state(uid).snapshots().map((d) {
        final raw = (d.data()?['readAt'] ?? const {}) as Map<String, dynamic>;
        return {
          for (final e in raw.entries)
            e.key: DateTime.fromMillisecondsSinceEpoch(e.value as int),
        };
      });

  @override
  Future<void> markRead(String uid, String chatId, {DateTime? at}) =>
      _state(uid).set({
        'readAt': {chatId: (at ?? DateTime.now()).millisecondsSinceEpoch},
      }, SetOptions(merge: true));

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
      case UserRole.grievanceCommittee:
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
  Future<void> deleteBus(String id) async {
    final name = await _field(_buses, id, 'name');
    await _buses.doc(id).delete();
    await _log('bus.deleted', 'bus', name);
  }

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

  // ---- Notices ----------------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _notices =>
      _db.collection('notices');

  List<Notice> _noticeList(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => Notice.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<List<Notice>> watchNotices() => _notices.snapshots().map(_noticeList);

  @override
  Stream<List<Notice>> watchPublicNotices() =>
      _notices.where('public', isEqualTo: true).snapshots().map(_noticeList);

  @override
  Future<void> addNotice(Notice notice) => _notices.add(notice.toMap());

  @override
  Future<void> deleteNotice(String id) async {
    final title = await _field(_notices, id, 'title');
    await _notices.doc(id).delete();
    await _log('notice.deleted', 'notice', title);
  }

  // ---- Emergency alerts ---------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _alerts =>
      _db.collection('alerts');

  @override
  Stream<List<EmergencyAlert>> watchActiveAlerts() => _alerts
      .where('active', isEqualTo: true)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => EmergencyAlert.fromMap(d.id, d.data())).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  @override
  Future<void> sendAlert(String message) async {
    final me = _actor!;
    await _alerts.add(
      EmergencyAlert(
        id: '',
        message: message,
        authorName: me.name,
        createdAt: DateTime.now(),
      ).toMap(),
    );
    await _log('alert.sent', 'alert', message);
  }

  @override
  Future<void> clearAlert(String id) async {
    final message = await _field(_alerts, id, 'message');
    await _alerts.doc(id).update({
      'active': false,
      'clearedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _log('alert.cleared', 'alert', message);
  }

  // ---- Timetable --------------------------------------------------------
  @override
  Stream<Map<String, List<TimetableSlot>>> watchTimetables() => _db
      .collection('timetables')
      .snapshots()
      .map(
        (s) => {
          for (final d in s.docs)
            d.id: [
              for (final m in (d.data()['slots'] ?? const []) as List)
                TimetableSlot.fromMap(Map<String, dynamic>.from(m as Map)),
            ]..sort((a, b) => a.order.compareTo(b.order)),
        },
      );

  @override
  Future<void> saveTimetable(String department, List<TimetableSlot> slots) =>
      _db.collection('timetables').doc(department).set({
        'slots': [for (final x in slots) x.toMap()],
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

  // ---- Assignments & notes ------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _assignments =>
      _db.collection('assignments');

  @override
  Stream<List<Assignment>> watchAssignments(AppUser viewer) {
    final Query<Map<String, dynamic>>? q;
    if (viewer.role == UserRole.teacher) {
      q = _assignments.where('createdBy', isEqualTo: viewer.uid);
    } else if (Rbac.isStudent(viewer)) {
      q = _assignments.where('department', isEqualTo: viewer.department);
    } else {
      q = null;
    }
    if (q == null) return Stream.value(const []);
    return q.snapshots().map(
      (s) =>
          s.docs.map((d) => Assignment.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  @override
  Future<void> addAssignment(Assignment item) => _assignments.add(item.toMap());

  @override
  Future<void> deleteAssignment(String id) => _assignments.doc(id).delete();

  // ---- Attendance -------------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _attendance =>
      _db.collection('attendanceRecords');

  @override
  Future<void> saveAttendance(List<AttendanceRecord> records) async {
    for (var i = 0; i < records.length; i += 400) {
      final batch = _db.batch();
      for (final r in records.skip(i).take(400)) {
        batch.set(_attendance.doc(r.docId), r.toMap());
      }
      await batch.commit();
    }
  }

  List<AttendanceRecord> _records(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => AttendanceRecord.fromMap(d.data())).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  @override
  Stream<List<AttendanceRecord>> watchMyAttendance(String studentUid) =>
      _attendance
          .where('studentUid', isEqualTo: studentUid)
          .snapshots()
          .map(_records);

  @override
  Stream<List<AttendanceRecord>> watchMarkedAttendance(String teacherUid) =>
      _attendance
          .where('teacherUid', isEqualTo: teacherUid)
          .snapshots()
          .map(_records);

  // ---- Complaints -------------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _complaints =>
      _db.collection('complaints');
  CollectionReference<Map<String, dynamic>> get _identities =>
      _db.collection('complaintIdentities');

  @override
  Stream<List<ComplaintIdentity>> watchMyComplaints(String uid) => _identities
      .where('filedBy', isEqualTo: uid)
      .snapshots()
      .map(
        (s) =>
            s.docs
                .map((d) => ComplaintIdentity.fromMap(d.id, d.data()))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  @override
  Stream<List<Complaint>> watchAllComplaints() => _complaints.snapshots().map(
    (s) =>
        s.docs.map((d) => Complaint.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );

  @override
  Stream<Complaint?> watchComplaint(String id) => _complaints
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Complaint.fromMap(d.id, d.data()!) : null);

  @override
  Future<ComplaintIdentity?> getComplaintIdentity(String id) async {
    final d = await _identities.doc(id).get();
    return d.exists ? ComplaintIdentity.fromMap(d.id, d.data()!) : null;
  }

  @override
  Future<String> fileComplaint({
    required ComplaintCategory category,
    required String subject,
    required String description,
    required bool anonymous,
  }) async {
    final me = _actor!;
    final ref = _complaints.doc();
    final now = DateTime.now();
    final batch = _db.batch();
    batch.set(
      _identities.doc(ref.id),
      ComplaintIdentity(
        id: ref.id,
        filedBy: me.uid,
        filedByName: me.name,
        filedByDepartment: me.department,
        anonymous: anonymous,
        category: category,
        subject: subject,
        status: ComplaintStatus.submitted,
        createdAt: now,
        updatedAt: now,
      ).toMap(),
    );
    batch.set(
      ref,
      Complaint(
        id: ref.id,
        category: category,
        subject: subject,
        description: description,
        anonymous: anonymous,
        displayName: anonymous ? 'Anonymous' : me.name,
        displayDepartment: anonymous ? '' : me.department,
        status: ComplaintStatus.submitted,
        createdAt: now,
        updatedAt: now,
      ).toMap(),
    );
    await batch.commit();
    return ref.id;
  }

  @override
  Stream<List<ComplaintReply>> watchReplies(String complaintId) => _complaints
      .doc(complaintId)
      .collection('replies')
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => ComplaintReply.fromMap(d.id, d.data())).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );

  @override
  Future<void> addReply(String complaintId, String text) async {
    final me = _actor!;
    final committee = Rbac.canHandleComplaints(me);
    var name = me.name;
    if (!committee) {
      final c = await _complaints.doc(complaintId).get();
      if ((c.data()?['anonymous'] ?? false) == true) name = 'Complainant';
    }
    await _complaints
        .doc(complaintId)
        .collection('replies')
        .add(
          ComplaintReply(
            id: '',
            kind: 'reply',
            byCommittee: committee,
            authorName: name,
            text: text,
            createdAt: DateTime.now(),
          ).toMap(),
        );
  }

  @override
  Future<void> setComplaintStatus(
    String id,
    ComplaintStatus status, {
    String note = '',
  }) async {
    final me = _actor!;
    final now = DateTime.now();
    final subject = await _field(_complaints, id, 'subject');
    final batch = _db.batch();
    final change = {
      'status': status.name,
      'updatedAt': now.millisecondsSinceEpoch,
    };
    batch.update(_complaints.doc(id), change);
    batch.update(_identities.doc(id), change);
    batch.set(
      _complaints.doc(id).collection('replies').doc(),
      ComplaintReply(
        id: '',
        kind: 'status',
        byCommittee: true,
        authorName: me.name,
        text: note.isEmpty ? 'Status changed to ${status.label}.' : note,
        createdAt: now,
      ).toMap(),
    );
    await batch.commit();
    await _log('complaint.status', 'complaint', subject, details: status.label);
  }

  // ---- Activity log -----------------------------------------------------
  @override
  Stream<List<ActivityEntry>> watchActivity() => _db
      .collection('activityLog')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => ActivityEntry.fromMap(d.id, d.data())).toList(),
      );
}
