import 'package:e_campus/app.dart';
import 'package:e_campus/models/app_user.dart';
import 'package:e_campus/services/demo_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<DemoBackend> _start(WidgetTester tester) async {
  // A tall window so lazily built lists and long forms are fully visible.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final backend = DemoBackend(simulateBus: false);
  addTearDown(backend.dispose);
  await tester.pumpWidget(ECampusApp(backend: backend));
  await tester.pumpAndSettle();
  return backend;
}

Future<void> _login(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(
    find.byType(TextFormField).at(1),
    DemoBackend.demoPassword,
  );
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
}

Future<void> _openMenuItem(WidgetTester tester, String title) async {
  await _openDrawer(tester);
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login validates the email and has no self sign-up', (t) async {
    await _start(t);
    expect(find.text('Create an account'), findsNothing);
    await t.enterText(find.byType(TextFormField).at(0), 'nope');
    await t.tap(find.text('Sign in'));
    await t.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('wrong password shows an error and stays on login', (t) async {
    await _start(t);
    await t.enterText(find.byType(TextFormField).at(0), 'admin@ecampus.demo');
    await t.enterText(find.byType(TextFormField).at(1), 'wrong');
    await t.tap(find.text('Sign in'));
    await t.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('disabled account sees a clear message', (t) async {
    final backend = await _start(t);
    await backend.setUserActive('u-student', false);
    await _login(t, 'student@ecampus.demo');
    expect(find.textContaining('has been disabled'), findsOneWidget);
  });

  testWidgets('student drawer hides staff entries', (t) async {
    await _start(t);
    await _login(t, 'student@ecampus.demo');
    await _openDrawer(t);
    expect(find.text('E-Library'), findsOneWidget);
    expect(find.text('Tech News'), findsOneWidget);
    expect(find.text('Manage Users'), findsNothing);
    expect(find.text('Class Representatives'), findsNothing);
  });

  testWidgets('bus driver drawer is only dashboard, bus and chat', (t) async {
    await _start(t);
    await _login(t, 'driver@ecampus.demo');
    await _openDrawer(t);
    expect(find.text('Bus Tracking'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('E-Library'), findsNothing);
    expect(find.text('AI Chatbot'), findsNothing);
    expect(find.text('Tech News'), findsNothing);
    expect(find.text('Manage Users'), findsNothing);
  });

  testWidgets('admin and admin staff see Manage Users', (t) async {
    await _start(t);
    await _login(t, 'admin@ecampus.demo');
    await _openDrawer(t);
    expect(find.text('Manage Users'), findsOneWidget);
  });

  testWidgets('admin staff cannot see administrator accounts', (t) async {
    await _start(t);
    await _login(t, 'staff@ecampus.demo');
    await _openMenuItem(t, 'Manage Users');
    expect(find.text('Prof. Rao'), findsOneWidget);
    expect(find.text('Asha Admin'), findsNothing);
  });

  testWidgets('admin sees administrators too', (t) async {
    await _start(t);
    await _login(t, 'admin@ecampus.demo');
    await _openMenuItem(t, 'Manage Users');
    expect(find.text('Sunil Staff'), findsOneWidget);
    // The admin's own row exists but is not editable.
    expect(find.text('Asha Admin'), findsOneWidget);
  });

  testWidgets('admin creates a teacher account from the app', (t) async {
    final backend = await _start(t);
    await _login(t, 'admin@ecampus.demo');
    await _openMenuItem(t, 'Manage Users');
    await t.tap(find.text('Create account'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'Meera Teacher');
    await t.enterText(find.byType(TextFormField).at(1), 'meera@college.edu');
    await t.tap(find.widgetWithText(FilledButton, 'Create account'));
    await t.pumpAndSettle(const Duration(seconds: 1));
    final users = await backend.watchUsers().first;
    expect(users.any((u) => u.email == 'meera@college.edu'), isTrue);
    expect(find.textContaining('Account created'), findsOneWidget);
  });

  testWidgets('class rep post-news button follows the role', (t) async {
    await _start(t);
    await _login(t, 'rep@ecampus.demo');
    await _openMenuItem(t, 'Tech News');
    expect(find.text('Post news'), findsOneWidget);
    expect(find.text('Flutter 3.47 released'), findsOneWidget);
  });

  testWidgets('teacher assigns class reps within the 2+2 limit', (t) async {
    final backend = await _start(t);
    // Ravi already is a boy representative; make Arjun the second one.
    await backend.setUserRole('u-student2', UserRole.classRep);
    await _login(t, 'teacher@ecampus.demo');
    await _openMenuItem(t, 'Class Representatives');
    expect(find.text('Girls: 0/2   ·   Boys: 2/2'), findsOneWidget);
    // Kabir would be a third boy: promotion must be refused.
    await t.tap(find.widgetWithText(SwitchListTile, 'Kabir Student'));
    await t.pumpAndSettle();
    expect(find.textContaining('already has 2 male'), findsOneWidget);
    // Sneha is a girl: allowed.
    await t.tap(find.widgetWithText(SwitchListTile, 'Sneha Student'));
    await t.pumpAndSettle();
    expect(find.text('Girls: 1/2   ·   Boys: 2/2'), findsOneWidget);
  });
}
