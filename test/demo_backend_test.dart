import 'package:e_campus/models/app_user.dart';
import 'package:e_campus/models/book.dart';
import 'package:e_campus/models/chat_message.dart';
import 'package:e_campus/models/news_item.dart';
import 'package:e_campus/services/backend.dart';
import 'package:e_campus/services/demo_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DemoBackend backend;
  setUp(() => backend = DemoBackend());
  tearDown(() => backend.dispose());

  test('rejects wrong password, accepts demo password', () async {
    await expectLater(
      () => backend.signIn('teacher@ecampus.demo', 'nope'),
      throwsA(isA<AuthException>()),
    );
    final user = await backend.signIn(
      'teacher@ecampus.demo',
      DemoBackend.demoPassword,
    );
    expect(user.role, UserRole.teacher);
    expect((await backend.restoreSession())?.uid, user.uid);
  });

  test('created accounts can sign in and duplicates are rejected', () async {
    await backend.createAccount(
      email: 'New@Kid.com',
      name: 'New Kid',
      department: 'MBA',
      role: UserRole.libraryStaff,
    );
    final user = await backend.signIn('new@kid.com', DemoBackend.demoPassword);
    expect(user.role, UserRole.libraryStaff);
    expect(user.department, 'MBA');
    await expectLater(
      () => backend.createAccount(
        email: 'new@kid.com',
        name: 'Dup',
        department: 'MBA',
        role: UserRole.student,
      ),
      throwsA(isA<AuthException>()),
    );
    await backend.signOut();
    expect(await backend.restoreSession(), isNull);
  });

  test('a disabled account cannot sign in until re-enabled', () async {
    await backend.setUserActive('u-student', false);
    await expectLater(
      () => backend.signIn('student@ecampus.demo', DemoBackend.demoPassword),
      throwsA(isA<AuthException>()),
    );
    await backend.setUserActive('u-student', true);
    final u = await backend.signIn(
      'student@ecampus.demo',
      DemoBackend.demoPassword,
    );
    expect(u.uid, 'u-student');
  });

  test('disabling a signed-in user ends their restored session', () async {
    await backend.signIn('student@ecampus.demo', DemoBackend.demoPassword);
    await backend.setUserActive('u-student', false);
    expect(await backend.restoreSession(), isNull);
  });

  test('updateUser changes profile fields', () async {
    final u = (await backend.watchUsers().first).firstWhere(
      (u) => u.uid == 'u-student',
    );
    await backend.updateUser(
      u.copyWith(name: 'Renamed', department: 'MBA', role: UserRole.teacher),
    );
    final after = (await backend.watchUsers().first).firstWhere(
      (u) => u.uid == 'u-student',
    );
    expect(after.name, 'Renamed');
    expect(after.department, 'MBA');
    expect(after.role, UserRole.teacher);
  });

  test('books can be added and removed', () async {
    const admin = AppUser(
      uid: 'a',
      email: 'a@x.y',
      name: 'a',
      department: 'MCA',
      role: UserRole.admin,
    );
    final before = (await backend.watchBooks(admin).first).length;
    await backend.addBook(
      const Book(
        id: '',
        title: 'T',
        author: 'A',
        category: 'C',
        url: 'https://x.y',
      ),
    );
    final after = await backend.watchBooks(admin).first;
    expect(after.length, before + 1);
    await backend.deleteBook(after.firstWhere((b) => b.title == 'T').id);
    expect((await backend.watchBooks(admin).first).length, before);
  });

  test('news is scoped to department', () async {
    await backend.addNews(
      NewsItem(
        id: '',
        title: 'MBA only',
        body: 'b',
        department: 'MBA',
        authorName: 'x',
        createdAt: DateTime.now(),
      ),
    );
    final mca = await backend.watchNews('MCA').first;
    final mba = await backend.watchNews('MBA').first;
    expect(mca.any((n) => n.title == 'MBA only'), isFalse);
    expect(mba.single.title, 'MBA only');
  });

  test('chat messages are delivered on the shared chat id', () async {
    final id = chatIdFor('b', 'a');
    expect(id, chatIdFor('a', 'b'));
    await backend.sendMessage(
      id,
      ChatMessage(id: '', senderId: 'a', text: 'hello', sentAt: DateTime.now()),
    );
    expect((await backend.watchMessages(id).first).single.text, 'hello');
  });

  test('admin can change roles', () async {
    await backend.setUserRole('u-student', UserRole.classRep);
    final users = await backend.watchUsers().first;
    expect(
      users.firstWhere((u) => u.uid == 'u-student').role,
      UserRole.classRep,
    );
  });
}
