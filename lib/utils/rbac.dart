import '../models/app_user.dart';
import '../models/book.dart';

/// Central place for Role-Based Access Control decisions.
///
/// Every screen and drawer entry asks this class instead of comparing roles
/// directly, so the permission matrix lives in a single file. The same rules
/// are enforced on the server in `firestore.rules`.
class Rbac {
  const Rbac._();

  static bool _is(AppUser u, Set<UserRole> roles) => roles.contains(u.role);

  // ---- Everyday features ------------------------------------------------
  /// Bus drivers only get chat and their trip controls.
  static bool canUseLibrary(AppUser u) => u.role != UserRole.busDriver;
  static bool canUseChatbot(AppUser u) => u.role != UserRole.busDriver;
  static bool canReadNews(AppUser u) => u.role != UserRole.busDriver;
  static bool canChat(AppUser u) => true;
  static bool canTrackBus(AppUser u) => true;

  // ---- News -------------------------------------------------------------
  static bool canPostNews(AppUser u) => _is(u, {
    UserRole.classRep,
    UserRole.teacher,
    UserRole.adminStaff,
    UserRole.admin,
  });

  /// Admin and admin staff may delete any news item; class reps and
  /// teachers only items of their own department.
  static bool canDeleteNews(AppUser u, String department) {
    if (_is(u, {UserRole.admin, UserRole.adminStaff})) return true;
    return canPostNews(u) && u.department == department;
  }

  // ---- Library ----------------------------------------------------------
  /// Who may add books. Teachers' books wait for library staff to verify.
  static bool canManageBooks(AppUser u) => _is(u, {
    UserRole.teacher,
    UserRole.libraryStaff,
    UserRole.adminStaff,
    UserRole.admin,
  });

  /// Library staff, admin staff and admin: no approval needed, and they can
  /// see, edit and delete every book.
  static bool seesAllBooks(AppUser u) =>
      _is(u, {UserRole.libraryStaff, UserRole.adminStaff, UserRole.admin});

  static BookStatus initialBookStatus(AppUser u) =>
      u.role == UserRole.teacher ? BookStatus.pending : BookStatus.approved;

  /// Only library staff approve or reject teachers' books.
  static bool canVerifyBooks(AppUser u) => u.role == UserRole.libraryStaff;

  /// Teachers see their own unapproved books; staff see all of them.
  static bool canSeeUnapprovedBooks(AppUser u) =>
      u.role == UserRole.teacher || seesAllBooks(u);

  /// The uploader, library staff, admin staff and admin may delete a book.
  static bool canDeleteBook(AppUser u, Book b) =>
      seesAllBooks(u) || (b.uploadedBy.isNotEmpty && b.uploadedBy == u.uid);

  /// Staff edit any book. An uploader may fix their own book until it is
  /// approved (editing sends it back for verification).
  static bool canEditBook(AppUser u, Book b) =>
      seesAllBooks(u) ||
      (b.uploadedBy == u.uid && b.status != BookStatus.approved);

  // ---- Bus --------------------------------------------------------------
  /// Only drivers start and end trips (and so publish the location).
  static bool canShareBusLocation(AppUser u) => u.role == UserRole.busDriver;

  /// Admin and admin staff create buses, assign drivers and departments.
  static bool canManageBuses(AppUser u) =>
      _is(u, {UserRole.admin, UserRole.adminStaff});

  // ---- Accounts ---------------------------------------------------------
  static bool canManageUsers(AppUser u) =>
      _is(u, {UserRole.admin, UserRole.adminStaff});

  /// Roles [actor] may give to a newly created account.
  static List<UserRole> rolesCreatableBy(AppUser actor) {
    switch (actor.role) {
      case UserRole.admin:
        return const [
          UserRole.admin,
          UserRole.adminStaff,
          UserRole.grievanceCommittee,
          UserRole.libraryStaff,
          UserRole.teacher,
          UserRole.student,
          UserRole.busDriver,
        ];
      case UserRole.adminStaff:
        return const [
          UserRole.grievanceCommittee,
          UserRole.libraryStaff,
          UserRole.teacher,
          UserRole.student,
          UserRole.busDriver,
        ];
      default:
        return const [];
    }
  }

  /// Whether [actor] may open [target] for editing / disabling.
  /// Nobody manages their own account here, and admin staff can never
  /// touch administrators.
  static bool canEditUser(AppUser actor, AppUser target) {
    if (actor.uid == target.uid) return false;
    if (actor.role == UserRole.admin) return true;
    if (actor.role == UserRole.adminStaff) return target.role != UserRole.admin;
    return false;
  }

  /// Roles [actor] may set on [target] (always includes the current role).
  static List<UserRole> rolesAssignableBy(AppUser actor, AppUser target) {
    if (!canEditUser(actor, target)) return [target.role];
    final base = actor.role == UserRole.admin
        ? UserRole.values.toList()
        : const [
            UserRole.student,
            UserRole.classRep,
            UserRole.teacher,
            UserRole.grievanceCommittee,
            UserRole.libraryStaff,
            UserRole.busDriver,
          ];
    return {...base, target.role}.toList();
  }

  /// Teachers pick the class representatives of their own department.
  static bool canAssignClassReps(AppUser u) => u.role == UserRole.teacher;

  // ---- Campus features ----------------------------------------------------
  static bool isStudent(AppUser u) =>
      u.role == UserRole.student || u.role == UserRole.classRep;

  static bool _isAdminSide(AppUser u) =>
      _is(u, {UserRole.admin, UserRole.adminStaff});

  /// Notices, timetable, assignments, search: everybody except bus drivers.
  static bool canReadNotices(AppUser u) => u.role != UserRole.busDriver;
  static bool canPostNotices(AppUser u) => _isAdminSide(u);
  static bool canViewTimetable(AppUser u) => u.role != UserRole.busDriver;
  static bool canEditTimetable(AppUser u) => _isAdminSide(u);
  static bool canSearch(AppUser u) => u.role != UserRole.busDriver;

  /// Teachers mark attendance and post assignments / notes; students see
  /// their own attendance percentage and their department's work.
  static bool canMarkAttendance(AppUser u) => u.role == UserRole.teacher;
  static bool canViewOwnAttendance(AppUser u) => isStudent(u);
  static bool canPostAssignments(AppUser u) => u.role == UserRole.teacher;
  static bool canViewAssignments(AppUser u) =>
      isStudent(u) || u.role == UserRole.teacher || _isAdminSide(u);
  static bool canDeleteAssignment(AppUser u, String createdBy) =>
      _isAdminSide(u) || (canPostAssignments(u) && u.uid == createdBy);

  /// Complaints: everybody files them, except the committee that handles
  /// them. The committee sees every complaint; only the administrator can
  /// see who filed an anonymous one.
  static bool canFileComplaint(AppUser u) =>
      u.role != UserRole.grievanceCommittee;
  static bool canViewAllComplaints(AppUser u) =>
      _is(u, {UserRole.grievanceCommittee, UserRole.admin});
  static bool canHandleComplaints(AppUser u) =>
      u.role == UserRole.grievanceCommittee;
  static bool canSeeComplaintIdentity(AppUser u) => u.role == UserRole.admin;

  /// Emergency alerts: only the administrator sends them.
  static bool canSendAlert(AppUser u) => u.role == UserRole.admin;

  static bool canViewActivityLog(AppUser u) => u.role == UserRole.admin;
}
