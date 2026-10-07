import 'dart:async';

import '../models/app_user.dart';
import '../models/book.dart';
import '../models/bus_location.dart';
import '../models/chat_message.dart';
import '../models/news_item.dart';
import 'backend.dart';

/// In-memory backend so the app can be demoed without Firebase.
///
/// Demo accounts (OTP is always [demoOtp]):
///   9000000001 Admin · 9000000002 Teacher · 9000000003 Class Rep ·
///   9000000004 Student. Any other number registers as a new student.
class DemoBackend implements Backend {
  DemoBackend({bool simulateBus = true}) {
    _seed();
    if (simulateBus) _startBusSimulation();
  }

  static const demoOtp = '123456';

  final Map<String, AppUser> _usersByUid = {};
  final Map<String, String> _uidByPhone = {};
  final List<Book> _books = [];
  final List<NewsItem> _news = [];
  final Map<String, List<ChatMessage>> _chats = {};
  BusLocation? _bus;

  final _usersCtl = StreamController<void>.broadcast();
  final _booksCtl = StreamController<void>.broadcast();
  final _newsCtl = StreamController<void>.broadcast();
  final _chatCtl = StreamController<String>.broadcast();
  final _busCtl = StreamController<BusLocation?>.broadcast();

  String? _signedInUid;
  String? _pendingPhone;
  int _idCounter = 0;
  String _nextId() => 'd${_idCounter++}';

  @override
  bool get isDemo => true;

  void _seed() {
    void user(String uid, String phone, String name, String dept, UserRole r) {
      _usersByUid[uid] = AppUser(
        uid: uid,
        phone: phone,
        name: name,
        department: dept,
        role: r,
      );
      _uidByPhone[phone] = uid;
    }

    user('u-admin', '+919000000001', 'Asha Admin', 'MCA', UserRole.admin);
    user('u-teacher', '+919000000002', 'Prof. Rao', 'MCA', UserRole.teacher);
    user('u-rep', '+919000000003', 'Ravi (CR)', 'MCA', UserRole.classRep);
    user(
      'u-student',
      '+919000000004',
      'Sneha Student',
      'MCA',
      UserRole.student,
    );

    _books.addAll(const [
      Book(
        id: 'b1',
        title: 'Flutter in Action',
        author: 'Eric Windmill',
        category: 'Mobile',
        url: 'https://docs.flutter.dev/',
      ),
      Book(
        id: 'b2',
        title: 'Introduction to Algorithms',
        author: 'Cormen et al.',
        category: 'Computer Science',
        url: 'https://mitpress.mit.edu/9780262046305/',
      ),
      Book(
        id: 'b3',
        title: 'Computer Networks',
        author: 'Andrew Tanenbaum',
        category: 'Networking',
        url: 'https://www.pearson.com/',
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

    _bus = BusLocation(
      latitude: _route.first.$1,
      longitude: _route.first.$2,
      updatedAt: DateTime.now(),
    );
  }

  // A small loop of points near Visakhapatnam used to simulate the bus.
  static const _route = <(double, double)>[
    (17.7231, 83.3013),
    (17.7260, 83.3055),
    (17.7295, 83.3098),
    (17.7330, 83.3140),
    (17.7300, 83.3190),
    (17.7260, 83.3150),
    (17.7235, 83.3070),
  ];
  int _routeIndex = 0;
  Timer? _busTimer;

  void _startBusSimulation() {
    _busTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _routeIndex = (_routeIndex + 1) % _route.length;
      final p = _route[_routeIndex];
      _bus = BusLocation(
        latitude: p.$1,
        longitude: p.$2,
        updatedAt: DateTime.now(),
      );
      _busCtl.add(_bus);
    });
  }

  void dispose() => _busTimer?.cancel();

  // ---- Auth -------------------------------------------------------------
  @override
  Future<OtpSession> sendOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _pendingPhone = phone;
    return OtpSession(phone: phone, verificationId: 'demo');
  }

  @override
  Future<AppUser?> verifyOtp(OtpSession session, String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (code != demoOtp) {
      throw const AuthException('Incorrect OTP. Demo OTP is $demoOtp.');
    }
    final uid = _uidByPhone[session.phone];
    if (uid == null) {
      _signedInUid = 'pending-${session.phone}';
      return null;
    }
    _signedInUid = uid;
    return _usersByUid[uid];
  }

  @override
  Future<AppUser?> restoreSession() async =>
      _signedInUid == null ? null : _usersByUid[_signedInUid];

  @override
  Future<AppUser> registerProfile({
    required String name,
    required String department,
  }) async {
    final phone = _pendingPhone ?? '';
    final uid = 'u-${_nextId()}';
    final user = AppUser(
      uid: uid,
      phone: phone,
      name: name,
      department: department,
      role: UserRole.student,
    );
    _usersByUid[uid] = user;
    _uidByPhone[phone] = uid;
    _signedInUid = uid;
    _usersCtl.add(null);
    return user;
  }

  @override
  Future<void> signOut() async => _signedInUid = null;

  // ---- Users ------------------------------------------------------------
  Stream<T> _live<T>(Stream<void> trigger, T Function() read) async* {
    yield read();
    await for (final _ in trigger) {
      yield read();
    }
  }

  @override
  Stream<List<AppUser>> watchUsers() => _live(
    _usersCtl.stream,
    () => _usersByUid.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
  );

  @override
  Future<void> setUserRole(String uid, UserRole role) async {
    final u = _usersByUid[uid];
    if (u == null) return;
    _usersByUid[uid] = u.copyWith(role: role);
    _usersCtl.add(null);
  }

  // ---- Books ------------------------------------------------------------
  @override
  Stream<List<Book>> watchBooks() =>
      _live(_booksCtl.stream, () => List.of(_books));

  @override
  Future<void> addBook(Book book) async {
    _books.add(
      Book(
        id: _nextId(),
        title: book.title,
        author: book.author,
        category: book.category,
        url: book.url,
      ),
    );
    _booksCtl.add(null);
  }

  @override
  Future<void> deleteBook(String id) async {
    _books.removeWhere((b) => b.id == id);
    _booksCtl.add(null);
  }

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
    _chatCtl.add(chatId);
  }

  // ---- Bus --------------------------------------------------------------
  @override
  Stream<BusLocation?> watchBus() async* {
    yield _bus;
    yield* _busCtl.stream;
  }

  @override
  Future<void> updateBus(BusLocation location) async {
    _bus = location;
    _busCtl.add(location);
  }
}
