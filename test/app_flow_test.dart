import 'package:e_campus/app.dart';
import 'package:e_campus/services/demo_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  testWidgets('login validates the email', (tester) async {
    final backend = DemoBackend(simulateBus: false);
    addTearDown(backend.dispose);
    await tester.pumpWidget(ECampusApp(backend: backend));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'nope');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('student drawer hides admin entries', (tester) async {
    final backend = DemoBackend(simulateBus: false);
    addTearDown(backend.dispose);
    await tester.pumpWidget(ECampusApp(backend: backend));
    await tester.pumpAndSettle();
    await _login(tester, 'student@ecampus.demo');
    await _openDrawer(tester);
    expect(find.text('E-Library'), findsOneWidget);
    expect(find.text('Tech News'), findsOneWidget);
    expect(find.text('Manage Users'), findsNothing);
  });

  testWidgets('admin drawer shows Manage Users', (tester) async {
    final backend = DemoBackend(simulateBus: false);
    addTearDown(backend.dispose);
    await tester.pumpWidget(ECampusApp(backend: backend));
    await tester.pumpAndSettle();
    await _login(tester, 'admin@ecampus.demo');
    await _openDrawer(tester);
    expect(find.text('Manage Users'), findsOneWidget);
  });

  testWidgets('class rep sees Post news and department news', (tester) async {
    final backend = DemoBackend(simulateBus: false);
    addTearDown(backend.dispose);
    await tester.pumpWidget(ECampusApp(backend: backend));
    await tester.pumpAndSettle();
    await _login(tester, 'rep@ecampus.demo');
    await _openDrawer(tester);
    await tester.tap(find.text('Tech News'));
    await tester.pumpAndSettle();
    expect(find.text('Post news'), findsOneWidget);
    expect(find.text('Flutter 3.47 released'), findsOneWidget);
  });

  testWidgets('wrong password shows an error and stays on login', (t) async {
    final backend = DemoBackend(simulateBus: false);
    addTearDown(backend.dispose);
    await t.pumpWidget(ECampusApp(backend: backend));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'admin@ecampus.demo');
    await t.enterText(find.byType(TextFormField).at(1), 'wrong');
    await t.tap(find.text('Sign in'));
    await t.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
