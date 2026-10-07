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
    expect(
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

  test('sign up creates a student and rejects duplicate email', () async {
    await backend.signUp(
      email: 'New@Kid.com',
      password: 'secret1',
      name: 'New Kid',
      department: 'MBA',
    );
    final user = await backend.signIn('new@kid.com', 'secret1');
    expect(user.role, UserRole.student);
    expect(user.department, 'MBA');
    expect(
      () => backend.signUp(
        email: 'new@kid.com',
        password: 'x12345',
        name: 'Dup',
        department: 'MBA',
      ),
      throwsA(isA<AuthException>()),
    );
    await backend.signOut();
    expect(await backend.restoreSession(), isNull);
  });

  test('books can be added and removed', () async {
    final before = (await backend.watchBooks().first).length;
    await backend.addBook(
      const Book(
        id: '',
        title: 'T',
        author: 'A',
        category: 'C',
        url: 'https://x.y',
      ),
    );
    final after = await backend.watchBooks().first;
    expect(after.length, before + 1);
    await backend.deleteBook(after.firstWhere((b) => b.title == 'T').id);
    expect((await backend.watchBooks().first).length, before);
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
