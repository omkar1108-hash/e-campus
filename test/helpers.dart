import 'package:e_campus/app.dart';
import 'package:e_campus/services/demo_backend.dart';
import 'package:e_campus/widgets/bus_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Starts the app on the demo backend in a tall window.
Future<DemoBackend> startApp(
  WidgetTester tester, {
  FakeImagePicker? imagePicker,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  BusMapView.debugListPlaceholder = true;
  final backend = DemoBackend();
  addTearDown(backend.dispose);
  await tester.pumpWidget(
    ECampusApp(
      backend: backend,
      locationSource: FakeLocation(),
      imagePicker: imagePicker ?? FakeImagePicker(),
    ),
  );
  await tester.pumpAndSettle();
  return backend;
}

Future<void> login(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(
    find.byType(TextFormField).at(1),
    DemoBackend.demoPassword,
  );
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
}

Future<void> openMenuItem(WidgetTester tester, String title) async {
  await openDrawer(tester);
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}
