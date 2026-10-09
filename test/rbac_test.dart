import 'package:e_campus/models/app_user.dart';
import 'package:e_campus/utils/class_rep_policy.dart';
import 'package:e_campus/utils/rbac.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _u(
  UserRole r, {
  String dept = 'MCA',
  String? uid,
  Gender? gender,
  bool active = true,
}) => AppUser(
  uid: uid ?? r.name,
  email: '${r.name}@y.z',
  name: r.name,
  department: dept,
  role: r,
  gender: gender,
  active: active,
);

void main() {
  group('everyday features', () {
    test('bus driver only gets chat and bus', () {
      final d = _u(UserRole.busDriver);
      expect(Rbac.canChat(d), isTrue);
      expect(Rbac.canTrackBus(d), isTrue);
      expect(Rbac.canShareBusLocation(d), isTrue);
      expect(Rbac.canUseLibrary(d), isFalse);
      expect(Rbac.canUseChatbot(d), isFalse);
      expect(Rbac.canReadNews(d), isFalse);
    });

    test('everyone else gets library, chatbot, news and chat', () {
      for (final r in UserRole.values.where((r) => r != UserRole.busDriver)) {
        final u = _u(r);
        expect(Rbac.canUseLibrary(u), isTrue, reason: r.name);
        expect(Rbac.canUseChatbot(u), isTrue, reason: r.name);
        expect(Rbac.canReadNews(u), isTrue, reason: r.name);
      }
    });

    test('only drivers share the bus location', () {
      for (final r in UserRole.values) {
        expect(
          Rbac.canShareBusLocation(_u(r)),
          r == UserRole.busDriver,
          reason: r.name,
        );
      }
    });
  });

  group('news', () {
    test('who can post', () {
      expect(Rbac.canPostNews(_u(UserRole.student)), isFalse);
      expect(Rbac.canPostNews(_u(UserRole.libraryStaff)), isFalse);
      expect(Rbac.canPostNews(_u(UserRole.busDriver)), isFalse);
      expect(Rbac.canPostNews(_u(UserRole.classRep)), isTrue);
      expect(Rbac.canPostNews(_u(UserRole.teacher)), isTrue);
      expect(Rbac.canPostNews(_u(UserRole.adminStaff)), isTrue);
      expect(Rbac.canPostNews(_u(UserRole.admin)), isTrue);
    });

    test('delete scope', () {
      expect(Rbac.canDeleteNews(_u(UserRole.admin), 'MBA'), isTrue);
      expect(Rbac.canDeleteNews(_u(UserRole.adminStaff), 'MBA'), isTrue);
      expect(Rbac.canDeleteNews(_u(UserRole.classRep), 'MCA'), isTrue);
      expect(Rbac.canDeleteNews(_u(UserRole.classRep), 'MBA'), isFalse);
      expect(Rbac.canDeleteNews(_u(UserRole.teacher), 'MBA'), isFalse);
      expect(Rbac.canDeleteNews(_u(UserRole.student), 'MCA'), isFalse);
    });
  });

  test('book managers', () {
    for (final r in UserRole.values) {
      expect(
        Rbac.canManageBooks(_u(r)),
        {
          UserRole.teacher,
          UserRole.hod,
          UserRole.libraryStaff,
          UserRole.adminStaff,
          UserRole.admin,
        }.contains(r),
        reason: r.name,
      );
    }
  });

  group('accounts', () {
    test('admin creates every role except class rep', () {
      final roles = Rbac.rolesCreatableBy(_u(UserRole.admin));
      expect(roles, contains(UserRole.admin));
      expect(roles, contains(UserRole.adminStaff));
      expect(roles, contains(UserRole.busDriver));
      expect(roles, isNot(contains(UserRole.classRep)));
    });

    test('admin staff cannot create admins or admin staff', () {
      final roles = Rbac.rolesCreatableBy(_u(UserRole.adminStaff));
      expect(roles.toSet(), {
        UserRole.grievanceCommittee,
        UserRole.libraryStaff,
        UserRole.hod,
        UserRole.teacher,
        UserRole.student,
        UserRole.busDriver,
      });
    });

    test('other roles create nothing', () {
      for (final r in [
        UserRole.student,
        UserRole.classRep,
        UserRole.teacher,
        UserRole.libraryStaff,
        UserRole.busDriver,
      ]) {
        expect(Rbac.rolesCreatableBy(_u(r)), isEmpty, reason: r.name);
        expect(Rbac.canManageUsers(_u(r)), isFalse, reason: r.name);
      }
    });

    test('admin staff cannot edit administrators, admin can edit anyone', () {
      final staff = _u(UserRole.adminStaff, uid: 'staff');
      final admin = _u(UserRole.admin, uid: 'admin');
      final other = _u(UserRole.admin, uid: 'admin2');
      expect(Rbac.canEditUser(staff, other), isFalse);
      expect(Rbac.canEditUser(admin, other), isTrue);
      expect(Rbac.canEditUser(admin, _u(UserRole.adminStaff)), isTrue);
      expect(Rbac.canEditUser(staff, _u(UserRole.teacher)), isTrue);
    });

    test('nobody edits themselves', () {
      final admin = _u(UserRole.admin, uid: 'me');
      expect(Rbac.canEditUser(admin, admin), isFalse);
    });

    test('admin staff cannot promote anyone to admin tiers', () {
      final staff = _u(UserRole.adminStaff, uid: 'staff');
      final roles = Rbac.rolesAssignableBy(staff, _u(UserRole.teacher));
      expect(roles, isNot(contains(UserRole.admin)));
      expect(roles, isNot(contains(UserRole.adminStaff)));
    });
  });

  group('class reps', () {
    List<AppUser> reps(int girls, int boys, {String dept = 'MCA'}) => [
      for (var i = 0; i < girls; i++)
        _u(UserRole.classRep, uid: 'g$i', gender: Gender.female, dept: dept),
      for (var i = 0; i < boys; i++)
        _u(UserRole.classRep, uid: 'b$i', gender: Gender.male, dept: dept),
    ];

    test('only the head of department assigns class reps', () {
      expect(Rbac.canAssignClassReps(_u(UserRole.hod)), isTrue);
      expect(Rbac.canAssignClassReps(_u(UserRole.teacher)), isFalse);
      expect(Rbac.canAssignClassReps(_u(UserRole.classRep)), isFalse);
      expect(Rbac.canAssignClassReps(_u(UserRole.admin)), isFalse);
    });

    test('limit is two girls and two boys per department', () {
      final girl = _u(UserRole.student, uid: 's', gender: Gender.female);
      final boy = _u(UserRole.student, uid: 's2', gender: Gender.male);
      expect(ClassRepPolicy.canPromote(reps(1, 2), girl), isNull);
      expect(ClassRepPolicy.canPromote(reps(2, 0), girl), isNotNull);
      expect(ClassRepPolicy.canPromote(reps(2, 0), boy), isNull);
      expect(ClassRepPolicy.canPromote(reps(0, 2), boy), isNotNull);
    });

    test('other departments do not count', () {
      final girl = _u(UserRole.student, uid: 's', gender: Gender.female);
      expect(ClassRepPolicy.canPromote(reps(2, 2, dept: 'MBA'), girl), isNull);
    });

    test('disabled representatives do not count', () {
      final girl = _u(UserRole.student, uid: 's', gender: Gender.female);
      final all = [
        ...reps(1, 0),
        _u(UserRole.classRep, uid: 'x', gender: Gender.female, active: false),
      ];
      expect(ClassRepPolicy.canPromote(all, girl), isNull);
    });

    test('student without gender cannot be promoted', () {
      expect(
        ClassRepPolicy.canPromote([], _u(UserRole.student, uid: 'n')),
        isNotNull,
      );
    });
  });

  test('unknown role name falls back to student', () {
    expect(UserRole.fromName('bogus'), UserRole.student);
    expect(UserRole.fromName(null), UserRole.student);
  });

  test('profiles written before gender/active existed still parse', () {
    final u = AppUser.fromMap('x', {
      'email': 'a@b.c',
      'name': 'Old',
      'department': 'MCA',
      'role': 'admin',
    });
    expect(u.active, isTrue);
    expect(u.gender, isNull);
    expect(u.role, UserRole.admin);
  });
}
