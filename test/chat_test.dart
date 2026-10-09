import 'package:e_campus/models/app_user.dart';
import 'package:e_campus/models/chat_message.dart';
import 'package:e_campus/services/backend.dart';
import 'package:e_campus/services/demo_backend.dart';
import 'package:e_campus/services/inbox_controller.dart';
import 'package:e_campus/utils/chat_policy.dart';
import 'package:e_campus/widgets/link_text.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _u(
  String uid,
  UserRole role, {
  String dept = 'MCA',
  bool active = true,
}) => AppUser(
  uid: uid,
  email: '$uid@x.y',
  name: uid,
  department: dept,
  role: role,
  active: active,
);

ChatMessage _m(String sender, String text, {DateTime? at}) => ChatMessage(
  id: '',
  senderId: sender,
  text: text,
  sentAt: at ?? DateTime.now(),
);

void main() {
  group('ChatPolicy', () {
    final student = _u('s', UserRole.student);
    final rep = _u('r', UserRole.classRep, dept: 'MBA');
    final teacher = _u('t', UserRole.teacher);
    final teacherMba = _u('t2', UserRole.teacher, dept: 'MBA');

    test('students talk to every student, whatever the department', () {
      expect(ChatPolicy.canChat(student, rep), isTrue);
      expect(ChatPolicy.canChat(rep, student), isTrue);
    });

    test('students talk only to teachers of their own department', () {
      expect(ChatPolicy.canChat(student, teacher), isTrue);
      expect(ChatPolicy.canChat(teacher, student), isTrue);
      expect(ChatPolicy.canChat(student, teacherMba), isFalse);
      expect(ChatPolicy.canChat(teacherMba, student), isFalse);
    });

    test('students cannot chat with other staff', () {
      for (final r in [
        UserRole.libraryStaff,
        UserRole.adminStaff,
        UserRole.admin,
        UserRole.busDriver,
      ]) {
        expect(
          ChatPolicy.canChat(student, _u('x', r)),
          isFalse,
          reason: r.name,
        );
        expect(
          ChatPolicy.canChat(_u('x', r), student),
          isFalse,
          reason: r.name,
        );
      }
    });

    test('staff talk to each other', () {
      final staff = [
        UserRole.teacher,
        UserRole.libraryStaff,
        UserRole.adminStaff,
        UserRole.admin,
        UserRole.busDriver,
      ];
      for (final a in staff) {
        for (final b in staff) {
          expect(
            ChatPolicy.canChat(_u('a', a), _u('b', b)),
            isTrue,
            reason: '${a.name} -> ${b.name}',
          );
        }
      }
    });

    test('nobody chats with themselves or with a disabled account', () {
      expect(ChatPolicy.canChat(student, student), isFalse);
      expect(
        ChatPolicy.canChat(student, _u('x', UserRole.student, active: false)),
        isFalse,
      );
    });
  });

  group('splitLinks', () {
    List<String?> links(String t) =>
        splitLinks(t).map((p) => p.link?.toString()).toList();

    test('plain text has no links', () {
      expect(splitLinks('hello world'), hasLength(1));
      expect(splitLinks('hello world').single.link, isNull);
    });

    test('finds http, https and www addresses', () {
      expect(links('see https://a.com/x and http://b.org then www.c.in/page'), [
        null,
        'https://a.com/x',
        null,
        'http://b.org',
        null,
        'https://www.c.in/page',
      ]);
    });

    test('keeps the text around a link and drops trailing punctuation', () {
      final parts = splitLinks('Read (https://a.com/doc), it is good.');
      expect(
        parts.map((p) => p.text).join(),
        'Read (https://a.com/doc), it is good.',
      );
      expect(
        parts.where((p) => p.link != null).single.text,
        'https://a.com/doc',
      );
      expect(
        splitLinks('go to https://a.com.')
            .firstWhere((p) => p.link != null)
            .text,
        'https://a.com',
      );
    });

    test('keeps query strings and fragments', () {
      expect(
        splitLinks('https://a.com/s?q=1&r=2#top').single.link.toString(),
        'https://a.com/s?q=1&r=2#top',
      );
    });

    test('ignores things that are not web links', () {
      expect(links('mail me at a@b.com or ftp://x.y or javascript:alert(1)'), [
        null,
      ]);
      expect(links('http:// nothing'), [null]);
    });
  });

  group('ChatMessage', () {
    test('only the sender can edit, and only for 15 minutes', () {
      final sent = DateTime(2026, 1, 1, 10);
      final msg = ChatMessage(id: 'x', senderId: 'a', text: 't', sentAt: sent);
      expect(msg.canEdit('a', sent.add(const Duration(minutes: 14))), isTrue);
      expect(msg.canEdit('a', sent.add(const Duration(minutes: 16))), isFalse);
      expect(msg.canEdit('b', sent), isFalse);
      expect(
        ChatMessage(
          id: 'x',
          senderId: 'a',
          text: '',
          sentAt: sent,
          deleted: true,
        ).canEdit('a', sent),
        isFalse,
      );
    });

    test('old messages without the new fields still load', () {
      final m = ChatMessage.fromMap('1', {
        'senderId': 'a',
        'text': 'hi',
        'sentAt': 5,
      });
      expect(m.deleted, isFalse);
      expect(m.pinned, isFalse);
      expect(m.editedAt, isNull);
    });
  });

  group('demo backend chat', () {
    late DemoBackend backend;
    setUp(() => backend = DemoBackend());
    tearDown(() => backend.dispose());
    final chat = chatIdFor('a', 'b');

    Future<List<ChatMessage>> messages() => backend.watchMessages(chat).first;

    test('send creates the message and the conversation summary', () async {
      await backend.sendMessage(chat, _m('a', 'hello'));
      expect((await messages()).single.text, 'hello');
      final s = (await backend.watchChats('b').first).single;
      expect(s.lastText, 'hello');
      expect(s.lastSenderId, 'a');
      expect(s.otherUid('b'), 'a');
      expect(await backend.watchChats('someone-else').first, isEmpty);
    });

    test(
      'edit changes text, marks it edited and updates the preview',
      () async {
        await backend.sendMessage(chat, _m('a', 'helo'));
        final id = (await messages()).single.id;
        await backend.editMessage(chat, id, 'hello', isLast: true);
        final m = (await messages()).single;
        expect(m.text, 'hello');
        expect(m.editedAt, isNotNull);
        expect((await backend.watchChats('a').first).single.lastText, 'hello');
      },
    );

    test('delete keeps a stub, clears the text and the pin', () async {
      await backend.sendMessage(chat, _m('a', 'secret'));
      final id = (await messages()).single.id;
      await backend.setPinned(chat, id, true);
      await backend.deleteMessage(chat, id, isLast: true);
      final m = (await messages()).single;
      expect(m.deleted, isTrue);
      expect(m.text, '');
      expect(m.pinned, isFalse);
      expect(
        (await backend.watchChats('a').first).single.lastText,
        'Message deleted',
      );
    });

    test('pin and unpin', () async {
      await backend.sendMessage(chat, _m('a', 'important'));
      final id = (await messages()).single.id;
      await backend.setPinned(chat, id, true);
      expect((await messages()).single.pinned, isTrue);
      await backend.setPinned(chat, id, false);
      expect((await messages()).single.pinned, isFalse);
    });

    test('read markers are stored per person', () async {
      await backend.markRead('a', chat);
      expect((await backend.watchReadMarkers('a').first).keys, [chat]);
      expect(await backend.watchReadMarkers('b').first, isEmpty);
    });
  });

  group('InboxController', () {
    late DemoBackend backend;
    late InboxController inbox;
    final me = _u('u-student', UserRole.student);
    final chat = chatIdFor('u-student', 'u-rep');
    final future = DateTime.now().add(const Duration(seconds: 5));

    setUp(() async {
      backend = DemoBackend();
      inbox = InboxController(backend, me);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    tearDown(() {
      inbox.dispose();
      backend.dispose();
    });

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    test(
      'a message from someone else is unread until the chat is opened',
      () async {
        await backend.sendMessage(chat, _m('u-rep', 'hi', at: future));
        await settle();
        expect(inbox.isUnread(chat), isTrue);
        expect(inbox.unreadCount, 1);
        inbox.setOpen(chat);
        await settle();
        expect(inbox.isUnread(chat), isFalse);
        expect(inbox.unreadCount, 0);
      },
    );

    test('my own messages are never unread', () async {
      await backend.sendMessage(chat, _m('u-student', 'hi', at: future));
      await settle();
      expect(inbox.isUnread(chat), isFalse);
    });

    test('announces new messages, but not own ones or the open chat', () async {
      final seen = <IncomingMessage>[];
      final sub = inbox.incoming.listen(seen.add);
      await backend.sendMessage(chat, _m('u-rep', 'first', at: future));
      await backend.sendMessage(chat, _m('u-student', 'mine', at: future));
      await settle();
      expect(seen.map((m) => m.text), ['first']);
      expect(seen.single.chatId, chat);

      inbox.setOpen(chat);
      await backend.sendMessage(
        chat,
        _m('u-rep', 'second', at: future.add(const Duration(seconds: 1))),
      );
      await settle();
      expect(seen, hasLength(1), reason: 'no banner for the open chat');
      expect(inbox.isUnread(chat), isFalse, reason: 'open chat stays read');
      await sub.cancel();
    });

    test('messages older than the app start do not trigger a banner', () async {
      final seen = <IncomingMessage>[];
      final sub = inbox.incoming.listen(seen.add);
      await backend.sendMessage(
        chat,
        _m(
          'u-rep',
          'old',
          at: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );
      await settle();
      expect(seen, isEmpty);
      expect(inbox.isUnread(chat), isTrue, reason: 'still counts as unread');
      await sub.cancel();
    });
  });
}
