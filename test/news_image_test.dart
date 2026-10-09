import 'package:e_campus/widgets/post_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'helpers.dart';

Future<void> _openNews(WidgetTester t, FakeImagePicker picker) async {
  await startApp(t, imagePicker: picker);
  await login(t, 'rep@ecampus.demo'); // class representative, MCA
  await openMenuItem(t, 'Tech News');
}

Future<void> _startPost(WidgetTester t) async {
  await t.tap(find.text('Post news'));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextFormField).at(0), 'Tech fest on Friday');
  await t.enterText(
    find.byType(TextFormField).at(1),
    'Details: https://example.com/fest',
  );
}

void main() {
  testWidgets('existing posts without a picture show no poster', (t) async {
    await _openNews(t, FakeImagePicker());
    expect(find.text('Flutter 3.47 released'), findsOneWidget);
    expect(find.byType(PostImage), findsNothing);
  });

  testWidgets('a post with a picture shows the poster above the headline', (
    t,
  ) async {
    final picker = FakeImagePicker(tinyPicture());
    await _openNews(t, picker);
    await _startPost(t);
    expect(find.byKey(const ValueKey('image-preview')), findsNothing);
    await t.tap(find.text('Add poster / image'));
    await t.pumpAndSettle();
    expect(picker.picks, 1);
    expect(find.byKey(const ValueKey('image-preview')), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Post'));
    await t.pumpAndSettle();
    expect(find.text('Tech fest on Friday'), findsOneWidget);
    expect(find.byType(PostImage), findsOneWidget);
    // The poster sits above its headline.
    expect(
      t.getTopLeft(find.byType(PostImage)).dy,
      lessThan(t.getTopLeft(find.text('Tech fest on Friday')).dy),
    );
  });

  testWidgets('tapping a poster opens it full screen', (t) async {
    await _openNews(t, FakeImagePicker(tinyPicture()));
    await _startPost(t);
    await t.tap(find.text('Add poster / image'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Post'));
    await t.pumpAndSettle();
    await t.tap(find.byType(PostImage));
    await t.pumpAndSettle();
    expect(find.byType(FullScreenImage), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.byType(FullScreenImage), findsNothing);
  });

  testWidgets('a post without a picture is still fine', (t) async {
    await _openNews(t, FakeImagePicker(tinyPicture()));
    await _startPost(t);
    await t.tap(find.widgetWithText(FilledButton, 'Post'));
    await t.pumpAndSettle();
    expect(find.text('Tech fest on Friday'), findsOneWidget);
    expect(find.byType(PostImage), findsNothing);
  });

  testWidgets('cancelling the gallery adds nothing; Remove clears the choice', (
    t,
  ) async {
    final picker = FakeImagePicker(); // returns null = user cancelled
    await _openNews(t, picker);
    await _startPost(t);
    await t.tap(find.text('Add poster / image'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('image-preview')), findsNothing);

    picker.next = tinyPicture();
    await t.tap(find.text('Add poster / image'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('image-preview')), findsOneWidget);
    await t.tap(find.text('Remove'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('image-preview')), findsNothing);
    await t.tap(find.widgetWithText(FilledButton, 'Post'));
    await t.pumpAndSettle();
    expect(find.byType(PostImage), findsNothing);
  });

  testWidgets('Change image replaces the picture', (t) async {
    final picker = FakeImagePicker(tinyPicture());
    await _openNews(t, picker);
    await _startPost(t);
    await t.tap(find.text('Add poster / image'));
    await t.pumpAndSettle();
    expect(find.text('Change image'), findsOneWidget);
    await t.tap(find.text('Change image'));
    await t.pumpAndSettle();
    expect(picker.picks, 2);
    expect(find.byKey(const ValueKey('image-preview')), findsOneWidget);
  });

  testWidgets('links in a news post are still clickable text', (t) async {
    await _openNews(t, FakeImagePicker());
    await _startPost(t);
    await t.tap(find.widgetWithText(FilledButton, 'Post'));
    await t.pumpAndSettle();
    expect(find.textContaining('example.com/fest'), findsOneWidget);
  });
}
