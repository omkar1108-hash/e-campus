import '../models/app_user.dart';
import '../models/book.dart';
import '../models/bus.dart';
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
  /// Signs in and returns the profile. Throws [AuthException] for bad
  /// credentials, an unverified email or a disabled account.
  Future<AppUser> signIn(String email, String password);

  Future<void> sendPasswordReset(String email);

  /// Profile of the signed-in user (restores session on app start).
  Future<AppUser?> restoreSession();

  Future<void> signOut();

  // ---- Accounts / RBAC --------------------------------------------------
  /// Creates a login plus profile for someone else (admin / admin staff
  /// only) and emails them a verification link and a "set your password"
  /// link. The caller stays signed in.
  Future<void> createAccount({
    required String email,
    required String name,
    required String department,
    required UserRole role,
    Gender? gender,
  });

  Stream<List<AppUser>> watchUsers();

  /// Edits name, department, gender and role.
  Future<void> updateUser(AppUser user);

  /// Disables or re-enables an account. Disabled users cannot sign in.
  Future<void> setUserActive(String uid, bool active);

  /// Changes only the role (used by teachers for class representatives).
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

  // ---- Buses ------------------------------------------------------------
  /// Buses [viewer] may see: staff roles see all, students see buses
  /// assigned to their department, a driver sees their own bus.
  Stream<List<Bus>> watchBuses(AppUser viewer);

  /// Creates (empty id) or updates a bus's configuration. Admin / admin staff.
  Future<void> saveBus(Bus bus);
  Future<void> deleteBus(String id);

  // Driver trip controls (only the assigned driver may call these).
  Future<void> startTrip(String busId, double lat, double lng);
  Future<void> updateTripLocation(String busId, double lat, double lng);
  Future<void> endTrip(String busId);
}

/// Deterministic id for a one-to-one chat between two users.
String chatIdFor(String a, String b) {
  final ids = [a, b]..sort();
  return ids.join('_');
}
