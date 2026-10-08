import '../models/app_user.dart';

/// Each department may have at most two girl and two boy class
/// representatives.
class ClassRepPolicy {
  const ClassRepPolicy._();

  static const maxPerGender = 2;

  static int count(Iterable<AppUser> all, String department, Gender gender) =>
      all
          .where(
            (u) =>
                u.active &&
                u.department == department &&
                u.role == UserRole.classRep &&
                u.gender == gender,
          )
          .length;

  /// Null when [student] may become a class representative, otherwise a
  /// message explaining why not.
  static String? canPromote(Iterable<AppUser> all, AppUser student) {
    if (student.role != UserRole.student) {
      return 'Only students can be class representatives.';
    }
    final gender = student.gender;
    if (gender == null) {
      return '${student.name} has no gender on their profile. Ask an '
          'administrator to set it first.';
    }
    if (count(all, student.department, gender) >= maxPerGender) {
      return '${student.department} already has $maxPerGender '
          '${gender.label.toLowerCase()} class representatives.';
    }
    return null;
  }
}
