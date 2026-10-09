import 'package:e_campus/models/app_user.dart';
import 'package:e_campus/models/book.dart';
import 'package:e_campus/services/demo_backend.dart';
import 'package:e_campus/utils/rbac.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _u(String uid, UserRole role) => AppUser(
  uid: uid,
  email: '$uid@x.y',
  name: uid,
  department: 'MCA',
  role: role,
);

Book _book({
  String by = 'u-teacher',
  BookStatus status = BookStatus.pending,
  String id = 'b',
}) => Book(
  id: id,
  title: 'T',
  author: 'A',
  category: 'C',
  url: 'https://x.y',
  status: status,
  uploadedBy: by,
);

void main() {
  group('Rbac for books', () {
    test('who may add, who is approved straight away', () {
      for (final r in UserRole.values) {
        expect(
          Rbac.canManageBooks(_u('x', r)),
          {
            UserRole.teacher,
            UserRole.hod,
            UserRole.libraryStaff,
            UserRole.adminStaff,
            UserRole.admin,
          }.contains(r),
          reason: r.name,
        );
      }
      expect(
        Rbac.initialBookStatus(_u('x', UserRole.teacher)),
        BookStatus.pending,
      );
      for (final r in [
        UserRole.libraryStaff,
        UserRole.adminStaff,
        UserRole.admin,
      ]) {
        expect(Rbac.initialBookStatus(_u('x', r)), BookStatus.approved);
      }
    });

    test('only library staff verify', () {
      for (final r in UserRole.values) {
        expect(
          Rbac.canVerifyBooks(_u('x', r)),
          r == UserRole.libraryStaff,
          reason: r.name,
        );
      }
    });

    test('who sees unapproved books', () {
      for (final r in UserRole.values) {
        expect(
          Rbac.canSeeUnapprovedBooks(_u('x', r)),
          {
            UserRole.teacher,
            UserRole.hod,
            UserRole.libraryStaff,
            UserRole.adminStaff,
            UserRole.admin,
          }.contains(r),
          reason: r.name,
        );
      }
    });

    test('delete: uploader and the library team only', () {
      final mine = _book(by: 'u-teacher');
      expect(
        Rbac.canDeleteBook(_u('u-teacher', UserRole.teacher), mine),
        isTrue,
      );
      expect(Rbac.canDeleteBook(_u('other', UserRole.teacher), mine), isFalse);
      for (final r in [
        UserRole.libraryStaff,
        UserRole.adminStaff,
        UserRole.admin,
      ]) {
        expect(Rbac.canDeleteBook(_u('x', r), mine), isTrue, reason: r.name);
      }
      expect(Rbac.canDeleteBook(_u('x', UserRole.student), mine), isFalse);
      // Old books without an uploader are not "mine" to anybody.
      expect(
        Rbac.canDeleteBook(_u('', UserRole.teacher), _book(by: '')),
        isFalse,
      );
    });

    test('edit: staff always, a teacher only until the book is approved', () {
      final teacher = _u('u-teacher', UserRole.teacher);
      expect(Rbac.canEditBook(teacher, _book()), isTrue);
      expect(
        Rbac.canEditBook(teacher, _book(status: BookStatus.rejected)),
        isTrue,
      );
      expect(
        Rbac.canEditBook(teacher, _book(status: BookStatus.approved)),
        isFalse,
      );
      expect(Rbac.canEditBook(_u('o', UserRole.teacher), _book()), isFalse);
      expect(
        Rbac.canEditBook(
          _u('x', UserRole.libraryStaff),
          _book(status: BookStatus.approved),
        ),
        isTrue,
      );
    });
  });

  group('demo backend books', () {
    late DemoBackend backend;
    setUp(() => backend = DemoBackend());
    tearDown(() => backend.dispose());

    Future<List<Book>> books(AppUser u) => backend.watchBooks(u).first;
    final student = _u('u-student', UserRole.student);
    final teacher = _u('u-teacher', UserRole.teacher);
    final otherTeacher = _u('u-teacher-mba', UserRole.teacher);
    final library = _u('u-library', UserRole.libraryStaff);

    test('students see approved books only', () async {
      final seen = await books(student);
      expect(seen.every((b) => b.status == BookStatus.approved), isTrue);
      expect(seen.any((b) => b.title == 'Data Mining Notes'), isFalse);
    });

    test(
      'a teacher sees approved books plus their own, not another teacher\'s',
      () async {
        expect(
          (await books(teacher)).any((b) => b.title == 'Data Mining Notes'),
          isTrue,
        );
        expect(
          (await books(otherTeacher))
              .any((b) => b.title == 'Data Mining Notes'),
          isFalse,
        );
      },
    );

    test('library staff see everything', () async {
      expect(
        (await books(library)).any((b) => b.status == BookStatus.pending),
        isTrue,
      );
    });

    test('approve makes a book visible to students', () async {
      await backend.reviewBook('b4', approve: true);
      final b = (await books(student)).firstWhere((b) => b.id == 'b4');
      expect(b.status, BookStatus.approved);
      expect(b.rejectReason, '');
    });

    test('reject keeps the reason and hides it from students', () async {
      await backend.reviewBook('b4', approve: false, reason: 'link is broken');
      expect((await books(student)).any((b) => b.id == 'b4'), isFalse);
      final mine = (await books(teacher)).firstWhere((b) => b.id == 'b4');
      expect(mine.status, BookStatus.rejected);
      expect(mine.rejectReason, 'link is broken');
    });

    test(
      'editing a rejected book with resubmit sends it back for review',
      () async {
        await backend.reviewBook('b4', approve: false, reason: 'bad');
        final rejected = (await books(teacher)).firstWhere((b) => b.id == 'b4');
        await backend.updateBook(
          rejected.copyWith(title: 'Fixed'),
          resubmit: true,
        );
        final b = (await books(teacher)).firstWhere((b) => b.id == 'b4');
        expect(b.title, 'Fixed');
        expect(b.status, BookStatus.pending);
        expect(b.rejectReason, '');
        expect(b.uploadedBy, 'u-teacher', reason: 'owner never changes');
      },
    );

    test('editing without resubmit keeps the status', () async {
      final approved = (await books(library)).firstWhere((b) => b.id == 'b1');
      await backend.updateBook(approved.copyWith(title: 'New title'));
      final b = (await books(library)).firstWhere((b) => b.id == 'b1');
      expect(b.title, 'New title');
      expect(b.status, BookStatus.approved);
    });

    test('a new book keeps cover, isbn and uploader', () async {
      await backend.addBook(
        const Book(
          id: '',
          title: 'N',
          author: 'A',
          category: 'C',
          url: 'https://x.y',
          isbn: '9780262046305',
          cover: 'abc',
          status: BookStatus.pending,
          uploadedBy: 'u-teacher',
          uploadedByName: 'Prof. Rao',
        ),
      );
      final b = (await books(teacher)).firstWhere((b) => b.title == 'N');
      expect(b.cover, 'abc');
      expect(b.isbn, '9780262046305');
      expect(b.status, BookStatus.pending);
      expect(b.uploadedByName, 'Prof. Rao');
    });
  });
}
