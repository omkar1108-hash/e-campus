import 'package:e_campus/models/campus.dart';
import 'package:e_campus/services/demo_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<void> signOut(WidgetTester t) async {
  await openDrawer(t);
  await t.tap(find.text('Sign out'));
  await t.pumpAndSettle();
}

Future<void> typeInto(WidgetTester t, int index, String text) async {
  await t.enterText(find.byType(TextFormField).at(index), text);
}

Future<void> tapButton(WidgetTester t, String label) async {
  await t.tap(find.widgetWithText(FilledButton, label));
  await t.pumpAndSettle(const Duration(seconds: 1));
}

void main() {
  audienceTests();
  assignmentAccessTests();
  backTests();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('opening page', () {
    testWidgets(
      'shows the college, public notices and contacts before sign-in',
      (t) async {
        await startApp(t);
        expect(find.text('E-Campus'), findsOneWidget);
        expect(
          find.text('Aditya Institute of Management Technology and Research'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('public-notices')), findsOneWidget);
        expect(find.text('Semester exams from 2 November'), findsOneWidget);
        // Notices that are not public stay hidden.
        expect(find.text('Library timings extended'), findsNothing);
        expect(find.text('Contact the college'), findsOneWidget);
        expect(find.text('Sign in'), findsOneWidget);
      },
    );

    testWidgets('works on a wide desktop window too', (t) async {
      await startApp(t);
      t.view.physicalSize = const Size(1400, 900);
      await t.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
      await login(t, 'student@ecampus.demo');
      expect(find.text('Welcome, Sneha Student'), findsOneWidget);
    });
  });

  group('dashboard', () {
    testWidgets('student sees live cards for their own work', (t) async {
      await startApp(t);
      await login(t, 'student@ecampus.demo');
      expect(find.text('Welcome, Sneha Student'), findsOneWidget);
      expect(find.text("Today's classes"), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Assignments due'), findsOneWidget);
      expect(find.text('Tech news'), findsOneWidget);
      expect(find.text('Next: Build a Flutter login screen'), findsOneWidget);
      expect(
        find.text('Latest: Semester exams from 2 November'),
        findsOneWidget,
      );
      expect(find.text('Accounts'), findsNothing);
      expect(find.text('Activity log'), findsNothing);
    });

    testWidgets('a card opens its section', (t) async {
      await startApp(t);
      await login(t, 'student@ecampus.demo');
      await t.tap(find.text('Assignments due'));
      await t.pumpAndSettle();
      expect(find.text('Build a Flutter login screen'), findsOneWidget);
    });

    testWidgets('driver sees only the bus and messages', (t) async {
      await startApp(t);
      await login(t, 'driver@ecampus.demo');
      expect(find.text('Your bus'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      // Drivers read the notices aimed at them (this one is for everyone).
      expect(find.text('Notices'), findsOneWidget);
      expect(find.text('Tech news'), findsNothing);
      expect(find.text('E-Library'), findsNothing);
    });

    testWidgets('administration sees accounts, complaints and the log', (
      t,
    ) async {
      await startApp(t);
      await login(t, 'admin@ecampus.demo');
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Complaints'), findsWidgets);
      expect(find.text('Activity log'), findsOneWidget);
      await signOut(t);
      await login(t, 'staff@ecampus.demo');
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Activity log'), findsNothing);
    });

    testWidgets('library staff see the books waiting for them', (t) async {
      await startApp(t);
      await login(t, 'library@ecampus.demo');
      expect(find.text('Books to verify'), findsOneWidget);
      expect(find.text('waiting for approval'), findsOneWidget);
    });
  });

  group('complaints', () {
    testWidgets('full complaint cycle with confirmation by the complainant', (
      t,
    ) async {
      await startApp(t);
      Future<void> asUser(String email) async {
        if (find.byType(BackButton).evaluate().isNotEmpty) {
          await t.pageBack();
          await t.pumpAndSettle();
        }
        if (find.byTooltip('Open navigation menu').evaluate().isNotEmpty) {
          await signOut(t);
        }
        await login(t, email);
      }

      Future<void> open(String email) async {
        await asUser(email);
        await openMenuItem(t, 'Complaints');
        await t.tap(find.text('Broken projector'));
        await t.pumpAndSettle();
      }

      Future<void> confirm() async {
        await t.tap(find.text('Confirm'));
        await t.pumpAndSettle();
      }

      await login(t, 'student@ecampus.demo');
      await openMenuItem(t, 'Complaints');
      expect(find.textContaining('not filed any complaints'), findsOneWidget);
      await t.tap(find.text('File a complaint'));
      await t.pumpAndSettle();
      await typeInto(t, 0, 'Broken projector');
      await typeInto(t, 1, 'The projector in room 4 has not worked for a week');
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(find.textContaining('will not see your name'), findsOneWidget);
      await tapButton(t, 'Submit');
      expect(find.text('Complaint submitted'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);

      // The committee sees the complaint but not who filed it.
      await asUser('committee@ecampus.demo');
      await openMenuItem(t, 'Complaints');
      expect(find.textContaining('Anonymous'), findsOneWidget);
      expect(find.textContaining('Sneha'), findsNothing);
      await t.tap(find.text('Broken projector'));
      await t.pumpAndSettle();
      expect(find.text('Filed anonymously'), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-identity')), findsNothing);
      await t.tap(find.text('Mark Working on it'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'We are on it');
      await confirm();
      expect(find.text('We are on it'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Technician booked for Monday');
      await t.tap(find.byTooltip('Send reply'));
      await t.pumpAndSettle();
      expect(find.text('Technician booked for Monday'), findsOneWidget);
      await t.tap(find.text('Mark Resolved'));
      await t.pumpAndSettle();
      await confirm();
      // Resolved is not the end: the committee waits for the complainant.
      expect(find.text('Mark Resolved'), findsNothing);
      expect(find.text('Mark Rejected'), findsNothing);

      // The student says it is not fixed: back to "Working on it".
      await open('student@ecampus.demo');
      expect(find.text('Technician booked for Monday'), findsOneWidget);
      await t.tap(find.text('No, work on it again'));
      await t.pumpAndSettle();
      await confirm();
      expect(find.text('Yes, it is resolved'), findsNothing);
      expect(find.text('Working on it'), findsWidgets);
      await t.enterText(find.byType(TextField), 'Still flickering');
      await t.tap(find.byTooltip('Send reply'));
      await t.pumpAndSettle();
      expect(find.text('Still flickering'), findsOneWidget);
      expect(find.textContaining('Complainant'), findsWidgets);

      // The committee works again and resolves; this time it is confirmed.
      await open('committee@ecampus.demo');
      await t.tap(find.text('Mark Resolved'));
      await t.pumpAndSettle();
      await confirm();
      await open('student@ecampus.demo');
      await t.tap(find.text('Yes, it is resolved'));
      await t.pumpAndSettle();
      await confirm();
      expect(find.text('Closed'), findsWidgets);
      expect(find.byTooltip('Send reply'), findsNothing);

      // Admin staff read it too, but the name stays hidden from them.
      await open('staff@ecampus.demo');
      expect(find.text('Filed anonymously'), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-identity')), findsNothing);
      expect(find.byTooltip('Send reply'), findsNothing);
      expect(find.text('Mark Resolved'), findsNothing);

      // The administrator can see who it was, and only reads.
      await open('admin@ecampus.demo');
      expect(find.byKey(const ValueKey('admin-identity')), findsOneWidget);
      expect(find.text('Filed by Sneha Student (MCA)'), findsOneWidget);
      expect(find.byTooltip('Send reply'), findsNothing);
    });

    testWidgets(
      'a rejected complaint is closed, a resolved one waits for the complainant',
      (t) async {
        final backend = await startApp(t);
        await login(t, 'student@ecampus.demo');
        Future<String> file(String subject) => backend.fileComplaint(
          category: ComplaintCategory.library,
          subject: subject,
          description: 'Charged twice',
          anonymous: false,
        );
        final fine = await file('Late fine');
        final noise = await file('Noise');
        await signOut(t);
        await login(t, 'committee@ecampus.demo');
        await backend.setComplaintStatus(fine, ComplaintStatus.resolved);
        await backend.setComplaintStatus(noise, ComplaintStatus.rejected);
        await signOut(t);
        await login(t, 'student@ecampus.demo');
        await openMenuItem(t, 'Complaints');
        await t.tap(find.text('Late fine'));
        await t.pumpAndSettle();
        // Waiting for the complainant: may confirm, and may still reply.
        expect(find.text('Yes, it is resolved'), findsOneWidget);
        expect(find.byTooltip('Send reply'), findsOneWidget);
        await t.pageBack();
        await t.pumpAndSettle();
        await t.tap(find.text('Noise'));
        await t.pumpAndSettle();
        expect(find.text('Rejected'), findsWidgets);
        expect(find.text('Yes, it is resolved'), findsNothing);
        expect(find.byTooltip('Send reply'), findsNothing);
      },
    );

    testWidgets('the committee cannot file complaints, others can', (t) async {
      await startApp(t);
      await login(t, 'committee@ecampus.demo');
      await openMenuItem(t, 'Complaints');
      expect(find.text('File a complaint'), findsNothing);
      await signOut(t);
      await login(t, 'driver@ecampus.demo');
      await openMenuItem(t, 'Complaints');
      expect(find.text('File a complaint'), findsOneWidget);
    });
  });

  group('emergency alert', () {
    testWidgets('admin sends it, everybody sees it, admin clears it', (
      t,
    ) async {
      await startApp(t);
      await login(t, 'admin@ecampus.demo');
      await openMenuItem(t, 'Emergency Alert');
      await t.enterText(find.byType(TextField), 'Campus closed due to rain');
      await t.tap(find.text('Send alert'));
      await t.pumpAndSettle();
      await tapButton(t, 'Send alert now');
      // A pop-up appears once, then the banner stays.
      expect(find.byKey(const ValueKey('alert-dialog')), findsOneWidget);
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('alert-banner')), findsOneWidget);

      // A driver (who has hardly any other feature) gets it too. The
      // pop-up appears once per device, so it does not repeat here.
      await signOut(t);
      await login(t, 'driver@ecampus.demo');
      expect(find.byKey(const ValueKey('alert-dialog')), findsNothing);
      expect(find.byKey(const ValueKey('alert-banner')), findsOneWidget);
      expect(find.text('Campus closed due to rain'), findsOneWidget);

      // Only the administrator has the screen to send or clear.
      await openDrawer(t);
      expect(find.text('Emergency Alert'), findsNothing);
      await t.tap(find.text('Sign out'));
      await t.pumpAndSettle();
      await login(t, 'admin@ecampus.demo');
      await openMenuItem(t, 'Emergency Alert');
      await t.tap(find.text('Clear'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('alert-banner')), findsNothing);
    });

    testWidgets('only the administrator gets the alert screen', (t) async {
      await startApp(t);
      await login(t, 'staff@ecampus.demo');
      await openDrawer(t);
      expect(find.text('Emergency Alert'), findsNothing);
      expect(find.text('Activity Log'), findsNothing);
    });
  });

  group('timetable', () {
    testWidgets('admin staff add a class and the students see it', (t) async {
      await startApp(t);
      await login(t, 'staff@ecampus.demo');
      await openMenuItem(t, 'Timetable');
      expect(find.text('Mobile Computing'), findsWidgets);
      await t.tap(find.text('Add class'));
      await t.pumpAndSettle();
      await typeInto(t, 2, 'Operating Systems');
      await tapButton(t, 'Add');
      expect(find.text('Operating Systems'), findsOneWidget);

      // A bad time is refused.
      await t.tap(find.text('Add class'));
      await t.pumpAndSettle();
      await typeInto(t, 0, '9am');
      await typeInto(t, 2, 'Bad');
      await tapButton(t, 'Add');
      expect(find.text('Use 24-hour HH:mm'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();

      await signOut(t);
      await login(t, 'student@ecampus.demo');
      await openMenuItem(t, 'Timetable');
      expect(find.text('Operating Systems'), findsOneWidget);
      // Students cannot edit.
      expect(find.text('Add class'), findsNothing);
      expect(find.byTooltip('Remove class'), findsNothing);
    });

    testWidgets('a teacher sees their own classes across departments', (
      t,
    ) async {
      await startApp(t);
      await login(t, 'teacher@ecampus.demo');
      await openMenuItem(t, 'Timetable');
      await t.tap(find.text('My classes'));
      await t.pumpAndSettle();
      expect(find.text('Mobile Computing'), findsWidgets);
      expect(find.text('Add class'), findsNothing);
    });

    testWidgets('removing a class works', (t) async {
      await startApp(t);
      await login(t, 'staff@ecampus.demo');
      await openMenuItem(t, 'Timetable');
      final before = find.byTooltip('Remove class').evaluate().length;
      await t.tap(find.byTooltip('Remove class').first);
      await t.pumpAndSettle();
      expect(find.byTooltip('Remove class').evaluate().length, before - 1);
    });
  });

  group('assignments', () {
    testWidgets('teacher shares a link and the students see it', (t) async {
      await startApp(t);
      await login(t, 'teacher@ecampus.demo');
      await openMenuItem(t, 'Assignments');
      await t.tap(find.text('Share'));
      await t.pumpAndSettle();
      await typeInto(t, 0, 'Mobile Computing');
      await typeInto(t, 1, 'Unit 3 notes');
      await typeInto(t, 3, 'not a link');
      await tapButton(t, 'Share');
      expect(find.textContaining('web address'), findsOneWidget);
      await typeInto(t, 3, 'https://drive.example.com/unit3');
      await tapButton(t, 'Share');
      expect(find.text('Unit 3 notes'), findsOneWidget);
      expect(find.text('https://drive.example.com/unit3'), findsOneWidget);

      await signOut(t);
      await login(t, 'student@ecampus.demo');
      await openMenuItem(t, 'Assignments');
      expect(find.text('Unit 3 notes'), findsOneWidget);
      expect(find.text('Share'), findsNothing);
      expect(find.byTooltip('Delete'), findsNothing);

      // Another department does not see it.
      await signOut(t);
      await login(t, 'meena@ecampus.demo');
      await openMenuItem(t, 'Assignments');
      expect(find.text('Unit 3 notes'), findsNothing);
    });

    testWidgets('the author deletes their post', (t) async {
      await startApp(t);
      await login(t, 'teacher@ecampus.demo');
      await openMenuItem(t, 'Assignments');
      expect(find.text('Build a Flutter login screen'), findsOneWidget);
      await t.tap(find.byTooltip('Delete'));
      await t.pumpAndSettle();
      expect(find.text('Build a Flutter login screen'), findsNothing);
    });
  });

  group('attendance', () {
    testWidgets('teacher marks it, students see their percentage', (t) async {
      await startApp(t);
      await login(t, 'teacher@ecampus.demo');
      await openMenuItem(t, 'Attendance');
      await t.enterText(find.byType(TextField).first, 'Mobile Computing');
      await t.pumpAndSettle();
      // Arjun was absent.
      await t.tap(find.byKey(const ValueKey('att-u-student2')));
      await t.pumpAndSettle();
      await tapButton(t, 'Save attendance');
      expect(find.textContaining('Attendance saved'), findsOneWidget);

      await t.tap(find.text('History'));
      await t.pumpAndSettle();
      expect(find.text('Mobile Computing · MCA'), findsOneWidget);
      expect(find.text('3 / 4 present'), findsOneWidget);

      await signOut(t);
      await login(t, 'student@ecampus.demo');
      await openMenuItem(t, 'Attendance');
      expect(find.text('100%'), findsWidgets);
      await signOut(t);
      await login(t, 'student2@ecampus.demo');
      await openMenuItem(t, 'Attendance');
      expect(find.byKey(const ValueKey('overall-attendance')), findsOneWidget);
      expect(find.text('0%'), findsWidgets);
      expect(find.textContaining('Below the 75% minimum'), findsOneWidget);
      // Students have no marking screen.
      expect(find.text('Save attendance'), findsNothing);
    });

    testWidgets('a student with no records is told so', (t) async {
      await startApp(t);
      await login(t, 'student@ecampus.demo');
      await openMenuItem(t, 'Attendance');
      expect(find.textContaining('No attendance'), findsOneWidget);
    });
  });

  group('role badges and search', () {
    testWidgets('chat list shows each person\'s role', (t) async {
      await startApp(t);
      await login(t, 'student@ecampus.demo');
      await openMenuItem(t, 'Chat');
      expect(find.byKey(const ValueKey('badge-teacher')), findsWidgets);
      expect(find.byKey(const ValueKey('badge-classRep')), findsWidgets);
      expect(find.byKey(const ValueKey('badge-student')), findsWidgets);
      expect(find.byKey(const ValueKey('badge-admin')), findsNothing);
    });

    testWidgets('one search covers books, news and notices', (t) async {
      await startApp(t);
      await login(t, 'student@ecampus.demo');
      await openMenuItem(t, 'Search');
      expect(find.textContaining('at least two letters'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'flutter');
      await t.pumpAndSettle();
      expect(find.text('Flutter in Action'), findsOneWidget);
      expect(find.text('Flutter 3.47 released'), findsOneWidget);
      expect(find.text('Books'), findsOneWidget);
      expect(find.text('Tech news'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'exams');
      await t.pumpAndSettle();
      expect(find.text('Semester exams from 2 November'), findsOneWidget);
      expect(find.text('Flutter in Action'), findsNothing);
      await t.enterText(find.byType(TextField), 'zzzz');
      await t.pumpAndSettle();
      expect(find.textContaining('Nothing found'), findsOneWidget);
      // Opening a result jumps to its section.
      await t.enterText(find.byType(TextField), 'hackathon');
      await t.pumpAndSettle();
      await t.tap(find.text('Hackathon registrations open'));
      await t.pumpAndSettle();
      expect(find.text('Post news'), findsNothing);
      expect(find.text('Flutter 3.47 released'), findsOneWidget);
    });

    testWidgets('search hides books a student may not see', (t) async {
      await startApp(t);
      await login(t, 'student@ecampus.demo');
      await openMenuItem(t, 'Search');
      await t.enterText(find.byType(TextField), 'data mining');
      await t.pumpAndSettle();
      // That book is still waiting for library approval.
      expect(find.text('Data Mining Notes'), findsNothing);
    });

    testWidgets('drivers have no search', (t) async {
      await startApp(t);
      await login(t, 'driver@ecampus.demo');
      await openDrawer(t);
      expect(find.text('Search'), findsNothing);
    });
  });

  group('notices', () {
    testWidgets('admin staff post a notice, students read it', (t) async {
      await startApp(t);
      await login(t, 'staff@ecampus.demo');
      await openMenuItem(t, 'Notices');
      await t.tap(find.text('New notice'));
      await t.pumpAndSettle();
      await typeInto(t, 0, 'Fee deadline');
      await typeInto(
        t,
        1,
        'Pay by Friday. Details: https://college.example/fees',
      );
      await tapButton(t, 'Publish');
      expect(find.text('Fee deadline'), findsOneWidget);

      await signOut(t);
      await login(t, 'student@ecampus.demo');
      await openMenuItem(t, 'Notices');
      expect(find.text('Fee deadline'), findsOneWidget);
      expect(find.text('New notice'), findsNothing);
      expect(find.byTooltip('Delete notice'), findsNothing);
    });

    testWidgets('a notice marked public reaches the opening page', (t) async {
      final backend = await startApp(t);
      expect(find.text('Fee deadline'), findsNothing);
      await login(t, 'staff@ecampus.demo');
      await openMenuItem(t, 'Notices');
      await t.tap(find.text('New notice'));
      await t.pumpAndSettle();
      await typeInto(t, 0, 'Fee deadline');
      await typeInto(t, 1, 'Pay by Friday');
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await tapButton(t, 'Publish');
      final pub = await backend.watchPublicNotices().first;
      expect(pub.map((n) => n.title), contains('Fee deadline'));
      await signOut(t);
      expect(find.text('Fee deadline'), findsOneWidget);
    });
  });

  group('activity log', () {
    testWidgets('admin sees who disabled an account and who deleted a book', (
      t,
    ) async {
      final backend = await startApp(t);
      await login(t, 'admin@ecampus.demo');
      await backend.setUserActive('u-student3', false);
      await backend.deleteBook('b3');
      await openMenuItem(t, 'Activity Log');
      expect(
        find.text('Asha Admin disabled the account of "Kabir Student"'),
        findsOneWidget,
      );
      expect(
        find.text('Asha Admin deleted the book "Computer Networks"'),
        findsOneWidget,
      );
      await t.tap(find.widgetWithText(ChoiceChip, 'Books'));
      await t.pumpAndSettle();
      expect(find.textContaining('disabled the account'), findsNothing);
      expect(find.textContaining('deleted the book'), findsOneWidget);
    });

    testWidgets('admin staff have no activity log', (t) async {
      await startApp(t);
      await login(t, 'staff@ecampus.demo');
      await openDrawer(t);
      expect(find.text('Activity Log'), findsNothing);
    });
  });

  testWidgets('the committee account has a plain staff drawer', (t) async {
    await startApp(t);
    await login(t, 'committee@ecampus.demo');
    await openDrawer(t);
    for (final item in [
      'Complaints',
      'Notices',
      'Timetable',
      'Chat',
      'Bus Tracking',
    ]) {
      expect(
        find.descendant(of: find.byType(Drawer), matching: find.text(item)),
        findsOneWidget,
      );
    }
    for (final item in [
      'Manage Users',
      'Attendance',
      'Activity Log',
      'Emergency Alert',
    ]) {
      expect(
        find.descendant(of: find.byType(Drawer), matching: find.text(item)),
        findsNothing,
      );
    }
    expect(DemoBackend.demoPassword, isNotEmpty);
  });
}

void backTests() {
  testWidgets('back returns to the dashboard, then asks before exiting', (
    t,
  ) async {
    await startApp(t);
    await login(t, 'student@ecampus.demo');
    await openMenuItem(t, 'Notices');
    expect(find.text('Welcome, Sneha Student'), findsNothing);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Welcome, Sneha Student'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pump();
    expect(find.text('Press back again to exit'), findsOneWidget);
  });
}

void assignmentAccessTests() {
  testWidgets('administration has no assignments section', (t) async {
    await startApp(t);
    for (final who in ['admin', 'staff', 'library', 'committee', 'driver']) {
      await login(t, '$who@ecampus.demo');
      await openDrawer(t);
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Assignments'),
        ),
        findsNothing,
        reason: who,
      );
      await t.tap(find.text('Sign out'));
      await t.pumpAndSettle();
    }
  });
}

void audienceTests() {
  testWidgets('a notice for one branch and group reaches only them', (t) async {
    await startApp(t);
    await login(t, 'staff@ecampus.demo');
    await openMenuItem(t, 'Notices');
    await t.tap(find.text('New notice'));
    await t.pumpAndSettle();
    await typeInto(t, 0, 'MCA students lab test');
    await typeInto(t, 1, 'Bring ID cards');
    expect(find.text('Goes to: All branches · everyone'), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('dept-MCA')));
    await t.tap(find.byKey(const ValueKey('dept-MCA')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('group-student')));
    await t.tap(find.byKey(const ValueKey('group-student')));
    await t.pumpAndSettle();
    expect(find.text('Goes to: MCA · Students'), findsOneWidget);
    // Only notices for everybody can be shown on the opening page.
    final sw = t.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(sw.onChanged, isNull);
    await tapButton(t, 'Publish');
    expect(find.text('MCA students lab test'), findsOneWidget);
    expect(find.text('For: MCA · Students'), findsOneWidget);

    for (final (email, sees) in [
      ('student@ecampus.demo', true),
      ('rep@ecampus.demo', true),
      ('meena@ecampus.demo', false), // MBA student
      ('teacher@ecampus.demo', false),
      ('driver@ecampus.demo', false),
    ]) {
      await signOut(t);
      await login(t, email);
      await openMenuItem(t, 'Notices');
      expect(
        find.text('MCA students lab test'),
        sees ? findsOneWidget : findsNothing,
        reason: email,
      );
    }
  });

  testWidgets('a notice for bus drivers is readable by drivers', (t) async {
    await startApp(t);
    await login(t, 'admin@ecampus.demo');
    await openMenuItem(t, 'Notices');
    await t.tap(find.text('New notice'));
    await t.pumpAndSettle();
    await typeInto(t, 0, 'Diesel rates');
    await typeInto(t, 1, 'Fill at the college pump');
    await t.ensureVisible(find.byKey(const ValueKey('group-driver')));
    await t.tap(find.byKey(const ValueKey('group-driver')));
    await tapButton(t, 'Publish');
    await signOut(t);
    await login(t, 'driver@ecampus.demo');
    await openMenuItem(t, 'Notices');
    expect(find.text('Diesel rates'), findsOneWidget);
    await signOut(t);
    await login(t, 'student@ecampus.demo');
    await openMenuItem(t, 'Notices');
    expect(find.text('Diesel rates'), findsNothing);
  });

  testWidgets('an alert for students only does not reach drivers', (t) async {
    await startApp(t);
    await login(t, 'admin@ecampus.demo');
    await openMenuItem(t, 'Emergency Alert');
    await t.enterText(find.byType(TextField), 'Exam hall changed');
    await t.ensureVisible(find.byKey(const ValueKey('group-student')));
    await t.tap(find.byKey(const ValueKey('group-student')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Send alert'));
    await t.tap(find.text('Send alert'));
    await t.pumpAndSettle();
    expect(find.textContaining('Students will see'), findsOneWidget);
    await tapButton(t, 'Send alert now');
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();

    await signOut(t);
    await login(t, 'driver@ecampus.demo');
    expect(find.byKey(const ValueKey('alert-banner')), findsNothing);
    await signOut(t);
    await login(t, 'meena@ecampus.demo');
    expect(find.byKey(const ValueKey('alert-banner')), findsOneWidget);
  });

  testWidgets('students and class reps cannot post notices or alerts', (
    t,
  ) async {
    await startApp(t);
    for (final who in ['student', 'rep']) {
      await login(t, '$who@ecampus.demo');
      await openMenuItem(t, 'Notices');
      expect(find.text('New notice'), findsNothing);
      await openDrawer(t);
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Emergency Alert'),
        ),
        findsNothing,
      );
      await t.tap(find.text('Sign out'));
      await t.pumpAndSettle();
    }
  });
}
