import '../models/app_user.dart';
import '../models/book.dart';
import '../models/campus.dart';
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
  /// Books [viewer] may see: approved ones for everybody, plus the viewer's
  /// own unapproved books (teachers), or every book (library staff, admin
  /// staff, admin).
  Stream<List<Book>> watchBooks(AppUser viewer);

  /// The caller sets uploader and status (see `Rbac.initialBookStatus`).
  Future<void> addBook(Book book);

  /// Edits a book. With [resubmit] the book goes back to "waiting for
  /// verification" and any rejection reason is cleared.
  Future<void> updateBook(Book book, {bool resubmit = false});

  /// Library staff: approve, or reject with a [reason].
  Future<void> reviewBook(String id, {required bool approve, String reason});
  Future<void> deleteBook(String id);

  /// Marks books added before approvals existed as approved. Returns how many.
  Future<int> approveLegacyBooks();

  // ---- Tech news --------------------------------------------------------
  Stream<List<NewsItem>> watchNews(String department);
  Future<void> addNews(NewsItem item);
  Future<void> deleteNews(String id);

  // ---- Chat -------------------------------------------------------------
  Stream<List<ChatMessage>> watchMessages(String chatId);

  /// Sends a message and updates the conversation summary.
  Future<void> sendMessage(String chatId, ChatMessage message);

  /// Sender only. Pass [isLast] when this is the newest message, so the
  /// chat list preview stays correct.
  Future<void> editMessage(
    String chatId,
    String messageId,
    String text, {
    bool isLast = false,
  });

  /// Sender only. The message stays as "This message was deleted".
  Future<void> deleteMessage(
    String chatId,
    String messageId, {
    bool isLast = false,
  });

  /// Either person in the chat may pin or unpin.
  Future<void> setPinned(String chatId, String messageId, bool pinned);

  /// Conversations [uid] takes part in (latest message of each).
  Stream<List<ChatSummary>> watchChats(String uid);

  /// When [uid] last opened each chat: chat id -> time.
  Stream<Map<String, DateTime>> watchReadMarkers(String uid);

  /// [at] defaults to now; the inbox passes the newest message's time so a
  /// sender whose phone clock runs ahead cannot leave a chat looking unread.
  Future<void> markRead(String uid, String chatId, {DateTime? at});

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

  /// Driver: switch between the outbound and return leg of the route
  /// (done automatically on arrival at a stop).
  Future<void> setBusLeg(String busId, String leg);

  // ---- Notices ----------------------------------------------------------
  /// Notices aimed at [viewer], newest first (admin and admin staff see all).
  Stream<List<Notice>> watchNotices(AppUser viewer);

  /// Notices marked public: readable before sign-in (opening page).
  Stream<List<Notice>> watchPublicNotices();
  Future<void> addNotice(Notice notice);
  Future<void> deleteNotice(String id);

  // ---- Emergency alerts ---------------------------------------------------
  /// Alerts that have not been cleared, newest first: those aimed at
  /// [viewer] (the administrator sees all of them).
  Stream<List<EmergencyAlert>> watchActiveAlerts(AppUser viewer);
  Future<void> sendAlert(
    String message, {
    Audience audience = Audience.everyone,
  });
  Future<void> clearAlert(String id);

  // ---- Timetable --------------------------------------------------------
  /// Timetable slots keyed by department: the viewer's own department for
  /// students and teachers, every department for admin and admin staff.
  Stream<Map<String, List<TimetableSlot>>> watchTimetables(AppUser viewer);

  /// Head of department of [department] only.
  Future<void> saveTimetable(String department, List<TimetableSlot> slots);

  // ---- Assignments & notes ------------------------------------------------
  /// Students: their department's items. Teachers: the ones they posted.
  /// Admin and admin staff: everything.
  Stream<List<Assignment>> watchAssignments(AppUser viewer);
  Future<void> addAssignment(Assignment item);
  Future<void> deleteAssignment(String id);

  // ---- Attendance -------------------------------------------------------
  /// Saves (or corrects) one lecture's attendance in a single step.
  Future<void> saveAttendance(List<AttendanceRecord> records);

  /// A student's own records.
  Stream<List<AttendanceRecord>> watchMyAttendance(String studentUid);

  /// Records a teacher marked.
  Stream<List<AttendanceRecord>> watchMarkedAttendance(String teacherUid);

  // ---- Complaints -------------------------------------------------------
  /// The filer's own complaints (works for anonymous ones too).
  Stream<List<ComplaintIdentity>> watchMyComplaints(String uid);

  /// Committee and admin: every complaint. Anonymous ones carry no identity.
  Stream<List<Complaint>> watchAllComplaints();
  Stream<Complaint?> watchComplaint(String id);

  /// Administrator only: who filed complaint [id].
  Future<ComplaintIdentity?> getComplaintIdentity(String id);

  /// Files a complaint and returns its id. The identity is stored apart
  /// from the complaint, so an anonymous one stays anonymous to the committee.
  Future<String> fileComplaint({
    required ComplaintCategory category,
    required String subject,
    required String description,
    required bool anonymous,
  });
  Stream<List<ComplaintReply>> watchReplies(String complaintId);

  /// A reply by the committee or by the person who filed the complaint.
  Future<void> addReply(String complaintId, String text);

  /// Committee: moves a complaint along its status flow, with an optional note.
  Future<void> setComplaintStatus(
    String id,
    ComplaintStatus status, {
    String note = '',
  });

  // ---- Activity log -----------------------------------------------------
  /// Admin only: newest 200 entries.
  Stream<List<ActivityEntry>> watchActivity();
}

/// Deterministic id for a one-to-one chat between two users.
String chatIdFor(String a, String b) {
  final ids = [a, b]..sort();
  return ids.join('_');
}
