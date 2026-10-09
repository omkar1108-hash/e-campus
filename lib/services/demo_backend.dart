import 'dart:async';

import '../models/app_user.dart';
import '../models/book.dart';
import '../models/bus.dart';
import '../models/chat_message.dart';
import '../models/news_item.dart';
import '../utils/rbac.dart';
import 'backend.dart';

/// In-memory backend so the app can be demoed without Firebase.
///
/// Demo accounts (password is always [demoPassword]):
///   admin@ / staff@ / library@ / teacher@ / rep@ / student@ / driver@
///   ecampus.demo. Accounts created in the app are active immediately.
class DemoBackend implements Backend {
  DemoBackend() {
    _seed();
  }

  static const demoPassword = 'demo1234';

  final Map<String, AppUser> _usersByUid = {};
  final Map<String, String> _uidByEmail = {};
  final Map<String, String> _passwords = {};
  final List<Book> _books = [];
  final List<NewsItem> _news = [];
  final Map<String, List<ChatMessage>> _chats = {};
  final Map<String, ChatSummary> _summaries = {};
  final Map<String, Map<String, DateTime>> _reads = {};
  final Map<String, Bus> _buses = {};

  final _usersCtl = StreamController<void>.broadcast();
  final _booksCtl = StreamController<void>.broadcast();
  final _newsCtl = StreamController<void>.broadcast();
  final _chatCtl = StreamController<String>.broadcast();
  final _inboxCtl = StreamController<void>.broadcast();
  final _busCtl = StreamController<void>.broadcast();

  String? _signedInUid;
  int _idCounter = 0;
  String _nextId() => 'd${_idCounter++}';

  @override
  bool get isDemo => true;

  void _seed() {
    void user(
      String uid,
      String email,
      String name,
      UserRole role, {
      Gender? gender,
    }) {
      _usersByUid[uid] = AppUser(
        uid: uid,
        email: email,
        name: name,
        department: 'MCA',
        role: role,
        gender: gender,
      );
      _uidByEmail[email] = uid;
      _passwords[uid] = demoPassword;
    }

    user('u-admin', 'admin@ecampus.demo', 'Asha Admin', UserRole.admin);
    user('u-staff', 'staff@ecampus.demo', 'Sunil Staff', UserRole.adminStaff);
    user(
      'u-library',
      'library@ecampus.demo',
      'Lata Library',
      UserRole.libraryStaff,
    );
    user('u-teacher', 'teacher@ecampus.demo', 'Prof. Rao', UserRole.teacher);
    user(
      'u-rep',
      'rep@ecampus.demo',
      'Ravi (CR)',
      UserRole.classRep,
      gender: Gender.male,
    );
    user(
      'u-student',
      'student@ecampus.demo',
      'Sneha Student',
      UserRole.student,
      gender: Gender.female,
    );
    user(
      'u-student2',
      'student2@ecampus.demo',
      'Arjun Student',
      UserRole.student,
      gender: Gender.male,
    );
    user(
      'u-student3',
      'student3@ecampus.demo',
      'Kabir Student',
      UserRole.student,
      gender: Gender.male,
    );
    _usersByUid['u-student-mba'] = const AppUser(
      uid: 'u-student-mba',
      email: 'meena@ecampus.demo',
      name: 'Meena MBA',
      department: 'MBA',
      role: UserRole.student,
      gender: Gender.female,
    );
    _uidByEmail['meena@ecampus.demo'] = 'u-student-mba';
    _passwords['u-student-mba'] = demoPassword;
    _usersByUid['u-teacher-mba'] = const AppUser(
      uid: 'u-teacher-mba',
      email: 'iyer@ecampus.demo',
      name: 'Prof. Iyer',
      department: 'MBA',
      role: UserRole.teacher,
    );
    _uidByEmail['iyer@ecampus.demo'] = 'u-teacher-mba';
    _passwords['u-teacher-mba'] = demoPassword;
    user(
      'u-driver',
      'driver@ecampus.demo',
      'Dinesh Driver',
      UserRole.busDriver,
    );

    _books.addAll([
      const Book(
        id: 'b1',
        title: 'Flutter in Action',
        author: 'Eric Windmill',
        category: 'Mobile',
        url: 'https://docs.flutter.dev/',
        isbn: '9781617296147',
      ),
      const Book(
        id: 'b2',
        title: 'Introduction to Algorithms',
        author: 'Cormen et al.',
        category: 'Computer Science',
        url: 'https://mitpress.mit.edu/9780262046305/',
        isbn: '978-0-262-04630-5',
      ),
      const Book(
        id: 'b3',
        title: 'Computer Networks',
        author: 'Andrew Tanenbaum',
        category: 'Networking',
        url: 'https://www.pearson.com/',
      ),
      Book(
        id: 'b4',
        title: 'Data Mining Notes',
        author: 'Prof. Rao',
        category: 'Data Science',
        url: 'https://example.com/data-mining',
        status: BookStatus.pending,
        uploadedBy: 'u-teacher',
        uploadedByName: 'Prof. Rao',
        createdAt: DateTime.now(),
      ),
    ]);

    _news.addAll([
      NewsItem(
        id: 'n1',
        title: 'Flutter 3.47 released',
        body:
            'The new stable release brings faster builds and improved '
            'Material components.',
        department: 'MCA',
        authorName: 'Ravi (CR)',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      NewsItem(
        id: 'n2',
        title: 'Hackathon registrations open',
        body:
            'Inter-college 24h hackathon this month. Register with your '
            'class representative.',
        department: 'MCA',
        authorName: 'Prof. Rao',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);

    _buses['bus1'] = const Bus(
      id: 'bus1',
      name: 'Bus 1 - North route',
      plate: 'MH 04 AB 1234',
      driverUid: 'u-driver',
      departments: ['MCA', 'MBA'],
    );
    _buses['bus2'] = const Bus(
      id: 'bus2',
      name: 'Bus 2 - South route',
      plate: 'MH 04 CD 5678',
      departments: ['Civil', 'Mechanical'],
    );
  }

  void dispose() {}

  // ---- Auth -------------------------------------------------------------
  @override
  Future<AppUser> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final uid = _uidByEmail[email.trim().toLowerCase()];
    if (uid == null || _passwords[uid] != password) {
      throw const AuthException('Incorrect email or password.');
    }
    final user = _usersByUid[uid]!;
    if (!user.active) {
      throw const AuthException(
        'Your account has been disabled. Please contact an administrator.',
      );
    }
    _signedInUid = uid;
    return user;
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<AppUser?> restoreSession() async {
    final user = _signedInUid == null ? null : _usersByUid[_signedInUid];
    return (user != null && user.active) ? user : null;
  }

  @override
  Future<void> signOut() async => _signedInUid = null;

  // ---- Accounts ---------------------------------------------------------
  @override
  Future<void> createAccount({
    required String email,
    required String name,
    required String department,
    required UserRole role,
    Gender? gender,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final key = email.trim().toLowerCase();
    if (_uidByEmail.containsKey(key)) {
      throw const AuthException('An account with this email already exists.');
    }
    final uid = 'u-${_nextId()}';
    _usersByUid[uid] = AppUser(
      uid: uid,
      email: key,
      name: name,
      department: department,
      role: role,
      gender: gender,
    );
    _uidByEmail[key] = uid;
    _passwords[uid] = demoPassword;
    _usersCtl.add(null);
  }

  @override
  Stream<List<AppUser>> watchUsers() => _live(
    _usersCtl.stream,
    () => _usersByUid.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
  );

  @override
  Future<void> updateUser(AppUser user) async {
    if (!_usersByUid.containsKey(user.uid)) return;
    _usersByUid[user.uid] = _usersByUid[user.uid]!.copyWith(
      name: user.name,
      department: user.department,
      role: user.role,
      gender: user.gender,
    );
    _usersCtl.add(null);
  }

  @override
  Future<void> setUserActive(String uid, bool active) async {
    final u = _usersByUid[uid];
    if (u == null) return;
    _usersByUid[uid] = u.copyWith(active: active);
    _usersCtl.add(null);
  }

  @override
  Future<void> setUserRole(String uid, UserRole role) async {
    final u = _usersByUid[uid];
    if (u == null) return;
    _usersByUid[uid] = u.copyWith(role: role);
    _usersCtl.add(null);
  }

  Stream<T> _live<T>(Stream<void> trigger, T Function() read) async* {
    yield read();
    await for (final _ in trigger) {
      yield read();
    }
  }

  // ---- Books ------------------------------------------------------------
  bool _canSeeBook(AppUser viewer, Book b) =>
      Rbac.seesAllBooks(viewer) ||
      b.status == BookStatus.approved ||
      (viewer.role == UserRole.teacher && b.uploadedBy == viewer.uid);

  @override
  Stream<List<Book>> watchBooks(AppUser viewer) => _live(
    _booksCtl.stream,
    () =>
        _books.where((b) => _canSeeBook(viewer, b)).toList()
          ..sort((a, b) => a.title.compareTo(b.title)),
  );

  void _replaceBook(String id, Book Function(Book b) change) {
    final i = _books.indexWhere((b) => b.id == id);
    if (i < 0) return;
    _books[i] = change(_books[i]);
    _booksCtl.add(null);
  }

  @override
  Future<void> addBook(Book book) async {
    _books.add(
      Book(
        id: _nextId(),
        title: book.title,
        author: book.author,
        category: book.category,
        url: book.url,
        isbn: book.isbn,
        cover: book.cover,
        status: book.status,
        uploadedBy: book.uploadedBy,
        uploadedByName: book.uploadedByName,
        createdAt: DateTime.now(),
      ),
    );
    _booksCtl.add(null);
  }

  @override
  Future<void> updateBook(Book book, {bool resubmit = false}) async =>
      _replaceBook(
        book.id,
        (old) => Book(
          id: old.id,
          title: book.title,
          author: book.author,
          category: book.category,
          url: book.url,
          isbn: book.isbn,
          cover: book.cover,
          status: resubmit ? BookStatus.pending : old.status,
          uploadedBy: old.uploadedBy,
          uploadedByName: old.uploadedByName,
          rejectReason: resubmit ? '' : old.rejectReason,
          createdAt: old.createdAt,
        ),
      );

  @override
  Future<void> reviewBook(
    String id, {
    required bool approve,
    String reason = '',
  }) async => _replaceBook(
    id,
    (b) => b.copyWith(
      status: approve ? BookStatus.approved : BookStatus.rejected,
      rejectReason: approve ? '' : reason,
    ),
  );

  @override
  Future<void> deleteBook(String id) async {
    _books.removeWhere((b) => b.id == id);
    _booksCtl.add(null);
  }

  @override
  Future<int> approveLegacyBooks() async => 0;

  // ---- News -------------------------------------------------------------
  @override
  Stream<List<NewsItem>> watchNews(String department) => _live(
    _newsCtl.stream,
    () =>
        _news.where((n) => n.department == department).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  @override
  Future<void> addNews(NewsItem item) async {
    _news.add(
      NewsItem(
        id: _nextId(),
        title: item.title,
        body: item.body,
        department: item.department,
        authorName: item.authorName,
        createdAt: item.createdAt,
        image: item.image,
      ),
    );
    _newsCtl.add(null);
  }

  @override
  Future<void> deleteNews(String id) async {
    _news.removeWhere((n) => n.id == id);
    _newsCtl.add(null);
  }

  // ---- Chat -------------------------------------------------------------
  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) async* {
    yield List.of(_chats[chatId] ?? const []);
    await for (final id in _chatCtl.stream) {
      if (id == chatId) yield List.of(_chats[chatId] ?? const []);
    }
  }

  @override
  Future<void> sendMessage(String chatId, ChatMessage message) async {
    _chats
        .putIfAbsent(chatId, () => [])
        .add(
          ChatMessage(
            id: _nextId(),
            senderId: message.senderId,
            text: message.text,
            sentAt: message.sentAt,
          ),
        );
    _summaries[chatId] = ChatSummary(
      chatId: chatId,
      participants: chatId.split('_'),
      lastText: message.text,
      lastMessageAt: message.sentAt,
      lastSenderId: message.senderId,
    );
    _chatCtl.add(chatId);
    _inboxCtl.add(null);
  }

  void _changeMessage(
    String chatId,
    String messageId,
    ChatMessage Function(ChatMessage m) change,
  ) {
    final list = _chats[chatId];
    if (list == null) return;
    final i = list.indexWhere((m) => m.id == messageId);
    if (i < 0) return;
    list[i] = change(list[i]);
    _chatCtl.add(chatId);
  }

  void _setPreview(String chatId, String text) {
    final s = _summaries[chatId];
    if (s == null) return;
    _summaries[chatId] = ChatSummary(
      chatId: chatId,
      participants: s.participants,
      lastText: text,
      lastMessageAt: s.lastMessageAt,
      lastSenderId: s.lastSenderId,
    );
    _inboxCtl.add(null);
  }

  @override
  Future<void> editMessage(
    String chatId,
    String messageId,
    String text, {
    bool isLast = false,
  }) async {
    _changeMessage(
      chatId,
      messageId,
      (m) => ChatMessage(
        id: m.id,
        senderId: m.senderId,
        text: text,
        sentAt: m.sentAt,
        editedAt: DateTime.now(),
        deleted: m.deleted,
        pinned: m.pinned,
      ),
    );
    if (isLast) _setPreview(chatId, text);
  }

  @override
  Future<void> deleteMessage(
    String chatId,
    String messageId, {
    bool isLast = false,
  }) async {
    _changeMessage(
      chatId,
      messageId,
      (m) => ChatMessage(
        id: m.id,
        senderId: m.senderId,
        text: '',
        sentAt: m.sentAt,
        editedAt: m.editedAt,
        deleted: true,
      ),
    );
    if (isLast) _setPreview(chatId, 'Message deleted');
  }

  @override
  Future<void> setPinned(String chatId, String messageId, bool pinned) async =>
      _changeMessage(
        chatId,
        messageId,
        (m) => ChatMessage(
          id: m.id,
          senderId: m.senderId,
          text: m.text,
          sentAt: m.sentAt,
          editedAt: m.editedAt,
          deleted: m.deleted,
          pinned: pinned && !m.deleted,
        ),
      );

  @override
  Stream<List<ChatSummary>> watchChats(String uid) => _live(
    _inboxCtl.stream,
    () => _summaries.values.where((c) => c.participants.contains(uid)).toList(),
  );

  @override
  Stream<Map<String, DateTime>> watchReadMarkers(String uid) =>
      _live(_inboxCtl.stream, () => Map.of(_reads[uid] ?? const {}));

  @override
  Future<void> markRead(String uid, String chatId, {DateTime? at}) async {
    _reads.putIfAbsent(uid, () => {})[chatId] = at ?? DateTime.now();
    _inboxCtl.add(null);
  }

  // ---- Buses ------------------------------------------------------------
  List<Bus> _busesFor(AppUser viewer) {
    bool visible(Bus b) {
      switch (viewer.role) {
        case UserRole.admin:
        case UserRole.adminStaff:
        case UserRole.teacher:
        case UserRole.libraryStaff:
          return true;
        case UserRole.busDriver:
          return b.driverUid == viewer.uid;
        case UserRole.student:
        case UserRole.classRep:
          return b.departments.contains(viewer.department);
      }
    }

    return _buses.values.where(visible).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Stream<List<Bus>> watchBuses(AppUser viewer) =>
      _live(_busCtl.stream, () => _busesFor(viewer));

  @override
  Future<void> saveBus(Bus bus) async {
    if (bus.id.isEmpty) {
      final id = 'bus${_nextId()}';
      _buses[id] = Bus(
        id: id,
        name: bus.name,
        plate: bus.plate,
        driverUid: bus.driverUid,
        departments: bus.departments,
      );
    } else {
      final old = _buses[bus.id];
      if (old == null) return;
      _buses[bus.id] = Bus(
        id: bus.id,
        name: bus.name,
        plate: bus.plate,
        driverUid: bus.driverUid,
        departments: bus.departments,
        active: old.active,
        lat: old.lat,
        lng: old.lng,
        updatedAt: old.updatedAt,
        tripStartedAt: old.tripStartedAt,
      );
    }
    _busCtl.add(null);
  }

  @override
  Future<void> deleteBus(String id) async {
    _buses.remove(id);
    _busCtl.add(null);
  }

  Bus _withTrip(
    Bus b, {
    required bool active,
    double? lat,
    double? lng,
    DateTime? started,
  }) => Bus(
    id: b.id,
    name: b.name,
    plate: b.plate,
    driverUid: b.driverUid,
    departments: b.departments,
    active: active,
    lat: lat ?? b.lat,
    lng: lng ?? b.lng,
    updatedAt: lat == null ? b.updatedAt : DateTime.now(),
    tripStartedAt: started ?? b.tripStartedAt,
  );

  @override
  Future<void> startTrip(String busId, double lat, double lng) async {
    final b = _buses[busId];
    if (b == null) return;
    _buses[busId] = _withTrip(
      b,
      active: true,
      lat: lat,
      lng: lng,
      started: DateTime.now(),
    );
    _busCtl.add(null);
  }

  @override
  Future<void> updateTripLocation(String busId, double lat, double lng) async {
    final b = _buses[busId];
    if (b == null) return;
    _buses[busId] = _withTrip(b, active: b.active, lat: lat, lng: lng);
    _busCtl.add(null);
  }

  @override
  Future<void> endTrip(String busId) async {
    final b = _buses[busId];
    if (b == null) return;
    _buses[busId] = _withTrip(b, active: false);
    _busCtl.add(null);
  }
}
