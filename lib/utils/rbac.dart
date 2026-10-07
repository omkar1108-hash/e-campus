import '../models/app_user.dart';

/// Central place for Role-Based Access Control decisions.
///
/// Every screen and drawer entry asks this class instead of comparing roles
/// directly, so the permission matrix lives in a single file.
class Rbac {
  const Rbac._();

  /// Students, class reps, teachers and admins can all use these.
  static bool canUseLibrary(AppUser u) => true;
  static bool canTrackBus(AppUser u) => true;
  static bool canChat(AppUser u) => true;
  static bool canUseChatbot(AppUser u) => true;
  static bool canReadNews(AppUser u) => true;

  /// Class representatives post news for their department; teachers and
  /// admins can post too.
  static bool canPostNews(AppUser u) => u.role != UserRole.student;

  /// Only teachers and admins curate the e-library.
  static bool canManageBooks(AppUser u) =>
      u.role == UserRole.teacher || u.role == UserRole.admin;

  /// Admin (bus driver account) publishes the live bus position.
  static bool canShareBusLocation(AppUser u) => u.role == UserRole.admin;

  static bool canManageUsers(AppUser u) => u.role == UserRole.admin;

  /// Admins may delete any news item; others only their own department.
  static bool canDeleteNews(AppUser u, String department) =>
      u.role == UserRole.admin || u.department == department;
}
