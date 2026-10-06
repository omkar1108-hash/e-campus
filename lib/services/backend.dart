import '../models/app_user.dart';
import '../models/book.dart';
import '../models/bus_location.dart';
import '../models/chat_message.dart';
import '../models/news_item.dart';

/// Handle for an OTP that has been sent and is waiting to be verified.
class OtpSession {
  const OtpSession({required this.phone, required this.verificationId});
  final String phone;
  final String verificationId;
}

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
  Future<OtpSession> sendOtp(String phone);

  /// Signs in with the OTP. Returns the stored profile, or null when this
  /// phone number has not completed registration yet.
  Future<AppUser?> verifyOtp(OtpSession session, String code);

  /// Profile of the signed-in user (restores session on app start).
  Future<AppUser?> restoreSession();

  Future<AppUser> registerProfile({
    required String name,
    required String department,
  });

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
