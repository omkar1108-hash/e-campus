import 'package:e_campus/models/app_user.dart';
import 'package:e_campus/utils/rbac.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _u(UserRole r, {String dept = 'MCA'}) => AppUser(
  uid: r.name,
  email: 'x@y.z',
  name: r.name,
  department: dept,
  role: r,
);

void main() {
  test('students only consume content', () {
    final s = _u(UserRole.student);
    expect(Rbac.canUseLibrary(s), isTrue);
    expect(Rbac.canPostNews(s), isFalse);
    expect(Rbac.canManageBooks(s), isFalse);
    expect(Rbac.canShareBusLocation(s), isFalse);
    expect(Rbac.canManageUsers(s), isFalse);
  });

  test('class rep can post news but not manage books/users', () {
    final cr = _u(UserRole.classRep);
    expect(Rbac.canPostNews(cr), isTrue);
    expect(Rbac.canManageBooks(cr), isFalse);
    expect(Rbac.canManageUsers(cr), isFalse);
  });

  test('teacher can post news and manage books', () {
    final t = _u(UserRole.teacher);
    expect(Rbac.canPostNews(t), isTrue);
    expect(Rbac.canManageBooks(t), isTrue);
    expect(Rbac.canManageUsers(t), isFalse);
  });

  test('admin can do everything', () {
    final a = _u(UserRole.admin);
    expect(Rbac.canPostNews(a), isTrue);
    expect(Rbac.canManageBooks(a), isTrue);
    expect(Rbac.canShareBusLocation(a), isTrue);
    expect(Rbac.canManageUsers(a), isTrue);
    expect(Rbac.canDeleteNews(a, 'MBA'), isTrue);
  });

  test('non-admins only delete news of their own department', () {
    final cr = _u(UserRole.classRep);
    expect(Rbac.canDeleteNews(cr, 'MCA'), isTrue);
    expect(Rbac.canDeleteNews(cr, 'MBA'), isFalse);
  });

  test('unknown role name falls back to student', () {
    expect(UserRole.fromName('bogus'), UserRole.student);
    expect(UserRole.fromName(null), UserRole.student);
  });
}
