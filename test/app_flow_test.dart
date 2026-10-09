import 'package:e_campus/app.dart';
import 'package:e_campus/models/app_user.dart';
import 'package:e_campus/services/demo_backend.dart';
import 'package:e_campus/widgets/bus_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<DemoBackend> _start(WidgetTester tester) async {
  // A tall window so lazily built lists and long forms are fully visible.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final backend = DemoBackend();
  addTearDown(backend.dispose);
  await tester.pumpWidget(
    ECampusApp(backend: backend, locationSource: FakeLocation()),
  );
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

Finder _inDrawer(String title) =>
    find.descendant(of: find.byType(Drawer), matching: find.text(title));

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
}

Future<void> _openMenuItem(WidgetTester tester, String title) async {
  await _openDrawer(tester);
  await tester.tap(_inDrawer(title));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => BusMapView.debugListPlaceholder = true);
  tearDownAll(() => BusMapView.debugListPlaceholder = false);

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
    expect(_inDrawer('E-Library'), findsOneWidget);
    expect(_inDrawer('Tech News'), findsOneWidget);
    expect(_inDrawer('Manage Users'), findsNothing);
    expect(_inDrawer('Class Representatives'), findsNothing);
  });

  testWidgets('bus driver drawer is only dashboard, bus, chat and complaints', (
    t,
  ) async {
    await _start(t);
    await _login(t, 'driver@ecampus.demo');
    await _openDrawer(t);
    expect(_inDrawer('Bus Tracking'), findsOneWidget);
    expect(_inDrawer('Chat'), findsOneWidget);
    expect(_inDrawer('E-Library'), findsNothing);
    expect(_inDrawer('AI Chatbot'), findsNothing);
    expect(_inDrawer('Tech News'), findsNothing);
    expect(_inDrawer('Manage Users'), findsNothing);
  });

  testWidgets('admin and admin staff see Manage Users', (t) async {
    await _start(t);
    await _login(t, 'admin@ecampus.demo');
    await _openDrawer(t);
    expect(_inDrawer('Manage Users'), findsOneWidget);
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

  testWidgets('students track only the buses of their department', (t) async {
    await _start(t);
    await _login(t, 'student@ecampus.demo'); // MCA
    await _openMenuItem(t, 'Bus Tracking');
    expect(find.text('Bus 1 - North route'), findsOneWidget);
    expect(find.text('Bus 2 - South route'), findsNothing);
    expect(find.textContaining('Not running'), findsOneWidget);
  });

  testWidgets('driver starts a trip, students see it live, driver ends it', (
    t,
  ) async {
    final backend = await _start(t);
    await _login(t, 'driver@ecampus.demo');
    await _openMenuItem(t, 'Bus Tracking');
    expect(find.text('Bus 1 - North route'), findsOneWidget);
    expect(find.text('End trip'), findsNothing);

    await t.tap(find.text('Start trip'));
    await t.pumpAndSettle(const Duration(seconds: 1));
    expect(find.textContaining('Trip in progress'), findsOneWidget);
    expect(find.text('End trip'), findsOneWidget);
    expect(find.text('Start trip'), findsNothing);
    final seen = await backend
        .watchBuses(
          const AppUser(
            uid: 'x',
            email: 'x@y.z',
            name: 'x',
            department: 'MCA',
            role: UserRole.student,
          ),
        )
        .first;
    expect(seen.single.isLive(DateTime.now()), isTrue);

    await t.tap(find.text('End trip'));
    await t.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('No trip running'), findsOneWidget);
    expect(find.text('Start trip'), findsOneWidget);
  });

  testWidgets('a driver without a bus is told so', (t) async {
    final backend = await _start(t);
    await backend.saveBus(
      (await backend
              .watchBuses(
                const AppUser(
                  uid: 'a',
                  email: 'a@y.z',
                  name: 'a',
                  department: 'MCA',
                  role: UserRole.admin,
                ),
              )
              .first)
          .firstWhere((b) => b.id == 'bus1')
          .copyWith(clearDriver: true),
    );
    await _login(t, 'driver@ecampus.demo');
    await _openMenuItem(t, 'Bus Tracking');
    expect(find.textContaining('No bus has been assigned'), findsOneWidget);
    expect(find.text('Start trip'), findsNothing);
  });

  testWidgets('drivers cannot open management screens', (t) async {
    await _start(t);
    await _login(t, 'driver@ecampus.demo');
    await _openDrawer(t);
    expect(_inDrawer('Manage Buses'), findsNothing);
    expect(_inDrawer('Manage Users'), findsNothing);
  });

  testWidgets('admin staff adds a bus with a driver and departments', (
    t,
  ) async {
    final backend = await _start(t);
    await _login(t, 'staff@ecampus.demo');
    await _openMenuItem(t, 'Manage Buses');
    expect(find.textContaining('Bus 1 - North route'), findsOneWidget);
    await t.tap(find.text('Add bus'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'Bus 9 - West');
    await t.enterText(find.byType(TextFormField).at(1), 'ab 12 cd 3456');
    // No departments yet: saving must be refused.
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(find.text('Choose at least one department'), findsOneWidget);
    await t.tap(find.widgetWithText(FilterChip, 'Electronics'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    final all = await backend
        .watchBuses(
          const AppUser(
            uid: 'a',
            email: 'a@y.z',
            name: 'a',
            department: 'MCA',
            role: UserRole.admin,
          ),
        )
        .first;
    final bus = all.firstWhere((b) => b.name == 'Bus 9 - West');
    expect(bus.plate, 'AB 12 CD 3456');
    expect(bus.departments, ['Electronics']);
    expect(find.textContaining('Bus 9 - West'), findsOneWidget);
  });
}
