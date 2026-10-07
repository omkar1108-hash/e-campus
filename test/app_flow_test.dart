import 'package:e_campus/app.dart';
import 'package:e_campus/services/demo_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _login(WidgetTester tester, String phone) async {
  await tester.enterText(find.byType(TextFormField), phone);
  await tester.tap(find.text('Send OTP'));
  await tester.pumpAndSettle(const Duration(seconds: 1));
  await tester.enterText(find.byType(TextField), DemoBackend.demoOtp);
  await tester.tap(find.text('Verify'));
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login validates the phone number', (tester) async {
    final backend = DemoBackend(simulateBus: false);
    addTearDown(backend.dispose);
    await tester.pumpWidget(ECampusApp(backend: backend));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '123');
    await tester.tap(find.text('Send OTP'));
    await tester.pump();
    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
  });

  testWidgets('student drawer hides admin entries', (tester) async {
    final backend = DemoBackend(simulateBus: false);
    addTearDown(backend.dispose);
    await tester.pumpWidget(ECampusApp(backend: backend));
    await tester.pumpAndSettle();
    await _login(tester, '9000000004');
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
    await _login(tester, '9000000001');
    await _openDrawer(tester);
    expect(find.text('Manage Users'), findsOneWidget);
  });

  testWidgets('class rep sees Post news and department news', (tester) async {
    final backend = DemoBackend(simulateBus: false);
    addTearDown(backend.dispose);
    await tester.pumpWidget(ECampusApp(backend: backend));
    await tester.pumpAndSettle();
    await _login(tester, '9000000003');
    await _openDrawer(tester);
    await tester.tap(find.text('Tech News'));
    await tester.pumpAndSettle();
    expect(find.text('Post news'), findsOneWidget);
    expect(find.text('Flutter 3.47 released'), findsOneWidget);
  });
}
