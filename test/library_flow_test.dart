import 'package:e_campus/models/app_user.dart';
import 'package:e_campus/models/book.dart';
import 'package:e_campus/widgets/book_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'helpers.dart';

Future<void> _openLibrary(
  WidgetTester t,
  String email, {
  FakeImagePicker? picker,
}) async {
  await startApp(t, imagePicker: picker);
  await login(t, email);
  await openMenuItem(t, 'E-Library');
}

Future<void> _fillBook(
  WidgetTester t, {
  String title = 'Operating Systems',
  String author = 'Silberschatz',
  String url = 'https://example.com/os.pdf',
  String isbn = '',
}) async {
  // Fields in order: title, author, category, isbn, link.
  final fields = find.byType(TextFormField);
  await t.enterText(fields.at(0), title);
  await t.enterText(fields.at(1), author);
  await t.enterText(fields.at(3), isbn);
  await t.enterText(fields.at(4), url);
}

const _teacher = AppUser(
  uid: 'u-teacher',
  email: 't@x.y',
  name: 'Prof. Rao',
  department: 'MCA',
  role: UserRole.teacher,
);
const _student = AppUser(
  uid: 'u-student',
  email: 's@x.y',
  name: 'Sneha',
  department: 'MCA',
  role: UserRole.student,
);

void main() {
  group('students', () {
    testWidgets('see approved books only, with no extra tabs', (t) async {
      await _openLibrary(t, 'student@ecampus.demo');
      expect(find.text('Flutter in Action'), findsOneWidget);
      expect(find.text('Computer Networks'), findsOneWidget);
      expect(find.text('Data Mining Notes'), findsNothing);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Add book'), findsNothing);
    });

    testWidgets('search narrows the list', (t) async {
      await _openLibrary(t, 'student@ecampus.demo');
      await t.enterText(find.byType(TextField).first, 'tanenbaum');
      await t.pumpAndSettle();
      expect(find.text('Computer Networks'), findsOneWidget);
      expect(find.text('Flutter in Action'), findsNothing);
    });

    testWidgets('a book shows its cover, or a placeholder without ISBN', (
      t,
    ) async {
      await _openLibrary(t, 'student@ecampus.demo');
      // Two demo books have an ISBN (cover fetched), one has none.
      expect(find.byType(BookCover), findsNWidgets(3));
      expect(find.byIcon(Icons.menu_book), findsWidgets);
    });
  });

  group('teachers', () {
    testWidgets('see approved books and their own uploads with status', (
      t,
    ) async {
      await _openLibrary(t, 'teacher@ecampus.demo');
      expect(find.text('Flutter in Action'), findsOneWidget);
      expect(find.text('My uploads (1)'), findsOneWidget);
      await t.tap(find.text('My uploads (1)'));
      await t.pumpAndSettle();
      expect(find.text('Data Mining Notes'), findsOneWidget);
      expect(find.text('Waiting for verification'), findsOneWidget);
    });

    testWidgets('a new book goes to verification, not to the library', (
      t,
    ) async {
      await _openLibrary(t, 'teacher@ecampus.demo');
      await t.tap(find.text('Add book'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Library staff will verify this book'),
        findsOneWidget,
      );
      await _fillBook(t);
      await t.tap(find.widgetWithText(FilledButton, 'Add'));
      await t.pumpAndSettle();
      expect(
        find.text('Sent to the library staff for verification'),
        findsOneWidget,
      );
      // Not visible in the public tab ...
      expect(find.text('Operating Systems'), findsNothing);
      // ... but in "My uploads", waiting.
      await t.tap(find.text('My uploads (2)'));
      await t.pumpAndSettle();
      expect(find.text('Operating Systems'), findsOneWidget);
      expect(find.text('Waiting for verification'), findsNWidgets(2));
    });

    testWidgets('the form checks the ISBN and the link', (t) async {
      await _openLibrary(t, 'teacher@ecampus.demo');
      await t.tap(find.text('Add book'));
      await t.pumpAndSettle();
      await _fillBook(t, isbn: '12345', url: 'not a link');
      await t.tap(find.widgetWithText(FilledButton, 'Add'));
      await t.pumpAndSettle();
      expect(find.text('An ISBN has 10 or 13 digits'), findsOneWidget);
      expect(find.text('Enter a full http(s) link'), findsOneWidget);
      // A valid ISBN with dashes is fine.
      await _fillBook(t, isbn: '978-0-262-04630-5');
      await t.tap(find.widgetWithText(FilledButton, 'Add'));
      await t.pumpAndSettle();
      expect(
        find.text('Sent to the library staff for verification'),
        findsOneWidget,
      );
    });

    testWidgets('a cover picked from the gallery is previewed and saved', (
      t,
    ) async {
      final picker = FakeImagePicker(tinyPicture());
      final backend = await startApp(t, imagePicker: picker);
      await login(t, 'teacher@ecampus.demo');
      await openMenuItem(t, 'E-Library');
      await t.tap(find.text('Add book'));
      await t.pumpAndSettle();
      await _fillBook(t);
      expect(find.byKey(const ValueKey('image-preview')), findsNothing);
      await t.tap(find.text('Add cover picture'));
      await t.pumpAndSettle();
      expect(picker.picks, 1);
      expect(find.byKey(const ValueKey('image-preview')), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Add'));
      await t.pumpAndSettle();
      final stored = (await backend.watchBooks(_teacher).first).firstWhere(
        (b) => b.title == 'Operating Systems',
      );
      expect(stored.cover, isNotNull);
      expect(stored.status, BookStatus.pending);
      expect(stored.uploadedBy, 'u-teacher');
    });

    testWidgets('the cover can be removed again', (t) async {
      final picker = FakeImagePicker(tinyPicture());
      await startApp(t, imagePicker: picker);
      await login(t, 'teacher@ecampus.demo');
      await openMenuItem(t, 'E-Library');
      await t.tap(find.text('Add book'));
      await t.pumpAndSettle();
      await t.tap(find.text('Add cover picture'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('image-preview')), findsOneWidget);
      await t.tap(find.text('Remove'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('image-preview')), findsNothing);
    });

    testWidgets('a picture problem is reported, the form stays usable', (
      t,
    ) async {
      final picker = FakeImagePicker()
        ..failWith = const ImageErrorForTest(
          'That file is not a picture we can read.',
        );
      await startApp(t, imagePicker: picker);
      await login(t, 'teacher@ecampus.demo');
      await openMenuItem(t, 'E-Library');
      await t.tap(find.text('Add book'));
      await t.pumpAndSettle();
      await t.tap(find.text('Add cover picture'));
      await t.pumpAndSettle();
      expect(find.textContaining('Could not load the picture'), findsOneWidget);
      expect(find.byKey(const ValueKey('image-preview')), findsNothing);
    });

    testWidgets('can delete their own pending book', (t) async {
      await _openLibrary(t, 'teacher@ecampus.demo');
      await t.tap(find.text('My uploads (1)'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('delete-b4')));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await t.pumpAndSettle();
      expect(find.text('Data Mining Notes'), findsNothing);
    });

    testWidgets('cannot delete or edit an approved book', (t) async {
      await _openLibrary(t, 'teacher@ecampus.demo');
      expect(find.byKey(const ValueKey('delete-b1')), findsNothing);
      expect(find.byKey(const ValueKey('edit-b1')), findsNothing);
    });
  });

  group('library staff', () {
    testWidgets('see a to-verify queue and can approve', (t) async {
      final backend = await startApp(t);
      await login(t, 'library@ecampus.demo');
      await openMenuItem(t, 'E-Library');
      expect(find.text('To verify (1)'), findsOneWidget);
      await t.tap(find.text('To verify (1)'));
      await t.pumpAndSettle();
      expect(find.text('Data Mining Notes'), findsOneWidget);
      expect(find.textContaining('Added by Prof. Rao'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('approve-b4')));
      await t.pumpAndSettle();
      expect(
        find.text('No books are waiting for verification.'),
        findsOneWidget,
      );
      // It is now part of the public library.
      await t.tap(find.text('Library'));
      await t.pumpAndSettle();
      expect(find.text('Data Mining Notes'), findsOneWidget);
      final b = (await backend.watchBooks(_student).first).any(
        (b) => b.id == 'b4',
      );
      expect(b, isTrue, reason: 'students see it now');
    });

    testWidgets('rejecting needs a reason, and the teacher sees it', (t) async {
      await startApp(t);
      await login(t, 'library@ecampus.demo');
      await openMenuItem(t, 'E-Library');
      await t.tap(find.text('To verify (1)'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('reject-b4')));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Reject'));
      await t.pumpAndSettle();
      expect(find.text('Please give a short reason'), findsOneWidget);
      await t.enterText(find.byType(TextField).last, 'The link does not open');
      await t.tap(find.widgetWithText(FilledButton, 'Reject'));
      await t.pumpAndSettle();
      expect(
        find.text('No books are waiting for verification.'),
        findsOneWidget,
      );
    });

    testWidgets('their own books are added without verification', (t) async {
      await _openLibrary(t, 'library@ecampus.demo');
      await t.tap(find.text('Add book'));
      await t.pumpAndSettle();
      expect(find.textContaining('will verify this book'), findsNothing);
      await _fillBook(t);
      await t.tap(find.widgetWithText(FilledButton, 'Add'));
      await t.pumpAndSettle();
      expect(find.text('Book added'), findsOneWidget);
      expect(find.text('Operating Systems'), findsOneWidget);
    });

    testWidgets('can delete any book', (t) async {
      await _openLibrary(t, 'library@ecampus.demo');
      await t.tap(find.byKey(const ValueKey('delete-b1')));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await t.pumpAndSettle();
      expect(find.text('Flutter in Action'), findsNothing);
    });
  });

  group('rejected books', () {
    testWidgets('the teacher sees the reason, fixes the book and resubmits', (
      t,
    ) async {
      final backend = await startApp(t);
      await backend.reviewBook(
        'b4',
        approve: false,
        reason: 'The link does not open',
      );
      await login(t, 'teacher@ecampus.demo');
      await openMenuItem(t, 'E-Library');
      await t.tap(find.text('My uploads (1)'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Rejected - The link does not open'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('edit-b4')));
      await t.pumpAndSettle();
      expect(find.textContaining('Library staff will verify'), findsOneWidget);
      await t.enterText(
        find.byType(TextFormField).at(4),
        'https://example.com/fixed',
      );
      await t.tap(find.widgetWithText(FilledButton, 'Save'));
      await t.pumpAndSettle();
      expect(find.text('Sent for verification again'), findsOneWidget);
      expect(find.text('Waiting for verification'), findsOneWidget);
      expect(find.textContaining('Rejected'), findsNothing);
    });
  });

  group('admin staff and admin', () {
    testWidgets('see non-approved books but cannot verify them', (t) async {
      await _openLibrary(t, 'staff@ecampus.demo');
      expect(find.text('Not approved (1)'), findsOneWidget);
      await t.tap(find.text('Not approved (1)'));
      await t.pumpAndSettle();
      expect(find.text('Data Mining Notes'), findsOneWidget);
      expect(find.byKey(const ValueKey('approve-b4')), findsNothing);
      expect(find.byKey(const ValueKey('reject-b4')), findsNothing);
      expect(find.byKey(const ValueKey('delete-b4')), findsOneWidget);
    });
  });
}

class ImageErrorForTest implements Exception {
  const ImageErrorForTest(this.message);
  final String message;
  @override
  String toString() => message;
}
