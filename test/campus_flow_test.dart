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
      expect(find.text('Notices'), findsNothing);
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
    testWidgets(
      'anonymous complaint: committee cannot see the name, admin can',
      (t) async {
        await startApp(t);
        await login(t, 'student@ecampus.demo');
        await openMenuItem(t, 'Complaints');
        expect(find.textContaining('not filed any complaints'), findsOneWidget);
        await t.tap(find.text('File a complaint'));
        await t.pumpAndSettle();
        await typeInto(t, 0, 'Broken projector');
        await typeInto(
          t,
          1,
          'The projector in room 4 has not worked for a week',
        );
        await t.tap(find.byType(Switch));
        await t.pumpAndSettle();
        expect(find.textContaining('will not see your name'), findsOneWidget);
        await tapButton(t, 'Submit');
        expect(find.text('Complaint submitted'), findsOneWidget);
        expect(find.text('Broken projector'), findsOneWidget);
        expect(find.text('Submitted'), findsOneWidget);

        // The committee sees the complaint but not who filed it.
        await signOut(t);
        await login(t, 'committee@ecampus.demo');
        await openMenuItem(t, 'Complaints');
        expect(find.text('Broken projector'), findsOneWidget);
        expect(find.textContaining('Anonymous'), findsOneWidget);
        expect(find.textContaining('Sneha'), findsNothing);
        await t.tap(find.text('Broken projector'));
        await t.pumpAndSettle();
        expect(find.text('Filed anonymously'), findsOneWidget);
        expect(find.textContaining('Sneha'), findsNothing);
        expect(find.byKey(const ValueKey('admin-identity')), findsNothing);
        await t.tap(find.text('Mark In review'));
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField).last, 'We are on it');
        await t.tap(find.text('Confirm'));
        await t.pumpAndSettle();
        expect(find.text('In review'), findsWidgets);
        expect(find.text('We are on it'), findsOneWidget);
        await t.enterText(
          find.byType(TextField),
          'Technician booked for Monday',
        );
        await t.tap(find.byTooltip('Send reply'));
        await t.pumpAndSettle();
        expect(find.text('Technician booked for Monday'), findsOneWidget);
        await t.pageBack();
        await t.pumpAndSettle();

        // The student follows the status and answers.
        await signOut(t);
        await login(t, 'student@ecampus.demo');
        await openMenuItem(t, 'Complaints');
        expect(find.text('In review'), findsOneWidget);
        await t.tap(find.text('Broken projector'));
        await t.pumpAndSettle();
        expect(find.text('Technician booked for Monday'), findsOneWidget);
        await t.enterText(find.byType(TextField), 'Thank you');
        await t.tap(find.byTooltip('Send reply'));
        await t.pumpAndSettle();
        expect(find.text('Thank you'), findsOneWidget);
        expect(find.textContaining('Complainant'), findsOneWidget);
        await t.pageBack();
        await t.pumpAndSettle();

        // The administrator can see who it was.
        await signOut(t);
        await login(t, 'admin@ecampus.demo');
        await openMenuItem(t, 'Complaints');
        await t.tap(find.text('Broken projector'));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('admin-identity')), findsOneWidget);
        expect(find.text('Filed by Sneha Student (MCA)'), findsOneWidget);
        // ...but only reads: there is no reply box and no status button.
        expect(find.byTooltip('Send reply'), findsNothing);
        expect(find.text('Mark Resolved'), findsNothing);
      },
    );

    testWidgets('a resolved complaint is closed to further replies', (t) async {
      final backend = await startApp(t);
      await login(t, 'student@ecampus.demo');
      final id = await backend.fileComplaint(
        category: ComplaintCategory.library,
        subject: 'Late fine',
        description: 'Charged twice',
        anonymous: false,
      );
      await signOut(t);
      await login(t, 'committee@ecampus.demo');
      await backend.setComplaintStatus(id, ComplaintStatus.resolved);
      await signOut(t);
      await login(t, 'student@ecampus.demo');
      await openMenuItem(t, 'Complaints');
      await t.tap(find.text('Late fine'));
      await t.pumpAndSettle();
      expect(find.text('Resolved'), findsWidgets);
      expect(find.byTooltip('Send reply'), findsNothing);
    });

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
      await tapButton(t, 'Send to everyone');
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
