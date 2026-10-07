import '../models/app_user.dart';
import '../models/book.dart';
import '../models/bus_location.dart';
import '../models/chat_message.dart';
import '../models/news_item.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Everything the UI needs from a data source. Implemented by
/// [FirebaseBackend] (production) and [DemoBackend] (offline demo).
abstract class Backend {
  /// True when running against in-memory demo data.
  bool get isDemo;

  // ---- Auth -------------------------------------------------------------
  /// Creates the account and its student profile, then sends a verification
  /// email. The user is signed out afterwards and must verify before logging in.
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String department,
  });

  /// Signs in and returns the profile. Throws [AuthException] for bad
  /// credentials or an unverified email.
  Future<AppUser> signIn(String email, String password);

  Future<void> sendPasswordReset(String email);

  /// Profile of the signed-in user (restores session on app start).
  Future<AppUser?> restoreSession();

  Future<void> signOut();

  // ---- Users / RBAC -----------------------------------------------------
  Stream<List<AppUser>> watchUsers();
  Future<void> setUserRole(String uid, UserRole role);

  // ---- E-Library --------------------------------------------------------
  Stream<List<Book>> watchBooks();
  Future<void> addBook(Book book);
  Future<void> deleteBook(String id);

  // ---- Tech news --------------------------------------------------------
  Stream<List<NewsItem>> watchNews(String department);
  Future<void> addNews(NewsItem item);
  Future<void> deleteNews(String id);

  // ---- Chat -------------------------------------------------------------
  Stream<List<ChatMessage>> watchMessages(String chatId);
  Future<void> sendMessage(String chatId, ChatMessage message);

  // ---- Bus tracking -----------------------------------------------------
  Stream<BusLocation?> watchBus();
  Future<void> updateBus(BusLocation location);
}

/// Deterministic id for a one-to-one chat between two users.
String chatIdFor(String a, String b) {
  final ids = [a, b]..sort();
  return ids.join('_');
}
