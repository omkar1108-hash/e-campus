import 'package:e_campus/models/app_user.dart';
import 'package:e_campus/models/campus.dart';
import 'package:e_campus/services/demo_backend.dart';
import 'package:e_campus/utils/rbac.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _u(UserRole r, {String dept = 'MCA'}) => AppUser(
  uid: r.name,
  email: '${r.name}@y.z',
  name: r.name,
  department: dept,
  role: r,
);

Set<UserRole> _who(bool Function(AppUser) can) => {
  for (final r in UserRole.values)
    if (can(_u(r))) r,
};

AttendanceRecord _rec(String subject, String date, bool present) =>
    AttendanceRecord(
      studentUid: 's',
      studentName: 'S',
      department: 'MCA',
      subject: subject,
      date: date,
      present: present,
      teacherUid: 't',
    );

Future<DemoBackend> _signedIn(String email) async {
  final b = DemoBackend();
  await b.signIn(email, DemoBackend.demoPassword);
  return b;
}

void main() {
  group('permissions for the campus features', () {
    test('notices and timetable: admin side edits, drivers see nothing', () {
      final admins = {UserRole.admin, UserRole.adminStaff};
      expect(_who(Rbac.canPostNotices), admins);
      expect(_who(Rbac.canEditTimetable), admins);
      final noDrivers = UserRole.values.toSet()..remove(UserRole.busDriver);
      expect(_who(Rbac.canReadNotices), noDrivers);
      expect(_who(Rbac.canViewTimetable), noDrivers);
      expect(_who(Rbac.canSearch), noDrivers);
    });

    test('attendance and assignments belong to teachers', () {
      expect(_who(Rbac.canMarkAttendance), {UserRole.teacher});
      expect(_who(Rbac.canPostAssignments), {UserRole.teacher});
      expect(_who(Rbac.canViewOwnAttendance), {
        UserRole.student,
        UserRole.classRep,
      });
      expect(_who(Rbac.canViewAssignments), {
        UserRole.student,
        UserRole.classRep,
        UserRole.teacher,
      });
    });

    test('assignments are deleted only by their author', () {
      final t = _u(UserRole.teacher);
      expect(Rbac.canDeleteAssignment(t, 'teacher'), isTrue);
      expect(Rbac.canDeleteAssignment(t, 'someone-else'), isFalse);
      expect(Rbac.canDeleteAssignment(_u(UserRole.adminStaff), 'x'), isFalse);
      expect(Rbac.canDeleteAssignment(_u(UserRole.admin), 'x'), isFalse);
      expect(
        Rbac.canDeleteAssignment(_u(UserRole.student), 'student'),
        isFalse,
      );
    });

    test('complaints: committee handles, only admin sees identities', () {
      expect(
        _who(Rbac.canFileComplaint),
        UserRole.values.toSet()..remove(UserRole.grievanceCommittee),
      );
      expect(_who(Rbac.canViewAllComplaints), {
        UserRole.grievanceCommittee,
        UserRole.admin,
      });
      expect(_who(Rbac.canHandleComplaints), {UserRole.grievanceCommittee});
      expect(_who(Rbac.canSeeComplaintIdentity), {UserRole.admin});
    });

    test('alerts and the activity log are administrator only', () {
      expect(_who(Rbac.canSendAlert), {UserRole.admin});
      expect(_who(Rbac.canViewActivityLog), {UserRole.admin});
    });

    test('admin and admin staff may create the committee role', () {
      expect(
        Rbac.rolesCreatableBy(_u(UserRole.admin)),
        contains(UserRole.grievanceCommittee),
      );
      expect(
        Rbac.rolesCreatableBy(_u(UserRole.adminStaff)),
        contains(UserRole.grievanceCommittee),
      );
      expect(
        Rbac.rolesCreatableBy(_u(UserRole.teacher)),
        isNot(contains(UserRole.grievanceCommittee)),
      );
    });
  });

  group('models', () {
    test('attendance percentages per subject and overall', () {
      final rs = [
        _rec('Maths', '2026-01-01', true),
        _rec('Maths', '2026-01-02', false),
        _rec('Maths', '2026-01-03', true),
        _rec('Maths', '2026-01-04', true),
        _rec('Java', '2026-01-01', false),
      ];
      final s = summarizeAttendance(rs);
      expect(s.map((e) => e.subject), ['Java', 'Maths']);
      expect(s[1].percent, 75);
      expect(s[0].percent, 0);
      expect(overallAttendance(rs), 60);
      expect(overallAttendance(const []), 0);
    });

    test('attendance record ids are stable and safe', () {
      final r = _rec('Data Mining / Lab', '2026-01-05', true);
      expect(r.docId, 'MCA_Data-Mining---Lab_2026-01-05_s');
      expect(r.docId, isNot(contains('/')));
    });

    test('timetable times and ordering', () {
      expect(TimetableSlot.validTime('09:30'), isTrue);
      expect(TimetableSlot.validTime('9:30'), isFalse);
      expect(TimetableSlot.validTime('24:00'), isFalse);
      expect(TimetableSlot.validTime('12:60'), isFalse);
      const a = TimetableSlot(
        day: 'Mon',
        start: '10:00',
        end: '11:00',
        subject: 'a',
      );
      const b = TimetableSlot(
        day: 'Mon',
        start: '09:00',
        end: '10:00',
        subject: 'b',
      );
      const c = TimetableSlot(
        day: 'Tue',
        start: '08:00',
        end: '09:00',
        subject: 'c',
      );
      final sorted = [c, a, b]..sort((x, y) => x.order.compareTo(y.order));
      expect(sorted.map((s) => s.subject), ['b', 'a', 'c']);
      expect(weekDayName(DateTime(2026, 1, 5)), 'Mon');
      expect(weekDayName(DateTime(2026, 1, 11)), isNull); // Sunday
    });

    test('complaint status flow only moves forward and ends', () {
      expect(ComplaintStatus.submitted.next, [
        ComplaintStatus.inReview,
        ComplaintStatus.resolved,
        ComplaintStatus.rejected,
      ]);
      expect(ComplaintStatus.inReview.next, [
        ComplaintStatus.resolved,
        ComplaintStatus.rejected,
      ]);
      expect(ComplaintStatus.resolved.next, isEmpty);
      expect(ComplaintStatus.rejected.next, isEmpty);
      expect(ComplaintStatus.resolved.isFinal, isTrue);
      expect(ComplaintStatus.inReview.isFinal, isFalse);
    });

    test('activity entries read as plain sentences', () {
      final e = ActivityEntry(
        id: '1',
        action: 'book.deleted',
        actorUid: 'u',
        actorName: 'Lata',
        actorRole: 'libraryStaff',
        targetType: 'book',
        targetLabel: 'Algorithms',
        createdAt: DateTime(2026),
      );
      expect(e.sentence, 'Lata deleted the book "Algorithms"');
    });
  });

  group('demo backend', () {
    test('an anonymous complaint hides the filer from the committee', () async {
      final student = await _signedIn('student@ecampus.demo');
      final id = await student.fileComplaint(
        category: ComplaintCategory.library,
        subject: 'Noise',
        description: 'Too loud',
        anonymous: true,
      );
      final seen = (await student.watchAllComplaints().first).single;
      expect(seen.displayName, 'Anonymous');
      expect(seen.displayDepartment, isEmpty);
      expect(seen.filedBy, isEmpty);
      // The filer still finds it, and the administrator can look it up.
      final mine = await student.watchMyComplaints('u-student').first;
      expect(mine.single.id, id);
      final identity = await student.getComplaintIdentity(id);
      expect(identity!.filedByName, 'Sneha Student');
    });

    test('a named complaint shows the real name', () async {
      final student = await _signedIn('student@ecampus.demo');
      await student.fileComplaint(
        category: ComplaintCategory.other,
        subject: 'S',
        description: 'D',
        anonymous: false,
      );
      final c = (await student.watchAllComplaints().first).single;
      expect(c.displayName, 'Sneha Student');
      expect(c.displayDepartment, 'MCA');
    });

    test('status changes leave a note and a log entry', () async {
      final b = DemoBackend();
      await b.signIn('student@ecampus.demo', DemoBackend.demoPassword);
      final id = await b.fileComplaint(
        category: ComplaintCategory.transport,
        subject: 'Bus late',
        description: 'Always late',
        anonymous: true,
      );
      await b.signIn('committee@ecampus.demo', DemoBackend.demoPassword);
      await b.addReply(id, 'We are looking into it');
      await b.setComplaintStatus(
        id,
        ComplaintStatus.inReview,
        note: 'Assigned to transport office',
      );
      final replies = await b.watchReplies(id).first;
      expect(replies.map((r) => r.kind), ['reply', 'status']);
      expect(replies.every((r) => r.byCommittee), isTrue);
      expect(
        (await b.watchComplaint(id).first)!.status,
        ComplaintStatus.inReview,
      );
      final mine = await b.watchMyComplaints('u-student').first;
      expect(mine.single.status, ComplaintStatus.inReview);
      // The filer replies under a neutral name.
      await b.signIn('student@ecampus.demo', DemoBackend.demoPassword);
      await b.addReply(id, 'Thank you');
      final last = (await b.watchReplies(id).first).last;
      expect(last.byCommittee, isFalse);
      expect(last.authorName, 'Complainant');
      final log = await b.watchActivity().first;
      expect(log.first.action, 'complaint.status');
    });

    test('the activity log records accounts, books and news', () async {
      final b = await _signedIn('admin@ecampus.demo');
      await b.createAccount(
        email: 'new@x.y',
        name: 'Neha',
        department: 'MCA',
        role: UserRole.teacher,
      );
      await b.setUserActive('u-student', false);
      await b.setUserActive('u-student', true);
      await b.deleteBook('b1');
      await b.deleteNews('n1');
      final log = await b.watchActivity().first;
      expect(log.map((e) => e.action), [
        'news.deleted',
        'book.deleted',
        'account.enabled',
        'account.disabled',
        'account.created',
      ]);
      expect(log[1].targetLabel, 'Flutter in Action');
      expect(log.last.targetLabel, 'Neha');
      expect(log.every((e) => e.actorName == 'Asha Admin'), isTrue);
      expect(log.every((e) => e.actorRole == 'admin'), isTrue);
    });

    test('alerts can be sent and cleared', () async {
      final b = await _signedIn('admin@ecampus.demo');
      expect(await b.watchActiveAlerts().first, isEmpty);
      await b.sendAlert('Fire drill');
      final active = await b.watchActiveAlerts().first;
      expect(active.single.message, 'Fire drill');
      await b.clearAlert(active.single.id);
      expect(await b.watchActiveAlerts().first, isEmpty);
    });

    test('only public notices are offered before sign-in', () async {
      final b = DemoBackend();
      final pub = await b.watchPublicNotices().first;
      expect(pub.map((n) => n.id), ['no1']);
      expect((await b.watchNotices().first).length, 2);
    });

    test('attendance is corrected, not duplicated', () async {
      final b = await _signedIn('teacher@ecampus.demo');
      await b.saveAttendance([_rec('Maths', '2026-01-01', true)]);
      await b.saveAttendance([_rec('Maths', '2026-01-01', false)]);
      final marked = await b.watchMarkedAttendance('t').first;
      expect(marked.length, 1);
      expect(marked.single.present, isFalse);
      expect(await b.watchMyAttendance('s').first, hasLength(1));
      expect(await b.watchMyAttendance('someone-else').first, isEmpty);
    });

    test('assignments are visible by department and author', () async {
      final teacher = await _signedIn('teacher@ecampus.demo');
      final student = await _signedIn('student@ecampus.demo');
      final mba = await _signedIn('meena@ecampus.demo');
      final other = await _signedIn('iyer@ecampus.demo');
      final me = (await teacher.restoreSession())!;
      final s = (await student.restoreSession())!;
      expect((await student.watchAssignments(s).first).length, 1);
      expect((await teacher.watchAssignments(me).first).length, 1);
      expect(
        await mba.watchAssignments((await mba.restoreSession())!).first,
        isEmpty,
      );
      expect(
        await other.watchAssignments((await other.restoreSession())!).first,
        isEmpty,
      );
      final lib = await _signedIn('library@ecampus.demo');
      expect(
        await lib.watchAssignments((await lib.restoreSession())!).first,
        isEmpty,
      );
    });
  });
}
