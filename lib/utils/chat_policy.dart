import '../models/app_user.dart';

/// Who may chat with whom. The same rules are enforced on the server in
/// `firestore.rules`.
///
/// * Students (and class reps) talk to **all students** and to the
///   **teachers of their own department**.
/// * Teachers talk to the students of their own department and to all staff.
/// * Staff (teachers, library, admin staff, admin, drivers) talk to each other.
/// * Students cannot chat with library staff, admin staff, admin or drivers.
class ChatPolicy {
  const ChatPolicy._();

  static bool _isStudent(UserRole r) =>
      r == UserRole.student || r == UserRole.classRep;

  static bool canChat(AppUser me, AppUser other) {
    if (me.uid == other.uid || !other.active) return false;
    final meStudent = _isStudent(me.role);
    final otherStudent = _isStudent(other.role);
    if (meStudent && otherStudent) return true;
    if (meStudent && other.role == UserRole.teacher) {
      return me.department == other.department;
    }
    if (me.role == UserRole.teacher && otherStudent) {
      return me.department == other.department;
    }
    return !meStudent && !otherStudent;
  }
}
