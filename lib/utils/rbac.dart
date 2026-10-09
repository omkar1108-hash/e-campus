import '../models/app_user.dart';

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
  static bool canManageBooks(AppUser u) => _is(u, {
    UserRole.teacher,
    UserRole.libraryStaff,
    UserRole.adminStaff,
    UserRole.admin,
  });

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
          UserRole.libraryStaff,
          UserRole.teacher,
          UserRole.student,
          UserRole.busDriver,
        ];
      case UserRole.adminStaff:
        return const [
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
            UserRole.libraryStaff,
            UserRole.busDriver,
          ];
    return {...base, target.role}.toList();
  }

  /// Teachers pick the class representatives of their own department.
  static bool canAssignClassReps(AppUser u) => u.role == UserRole.teacher;
}
