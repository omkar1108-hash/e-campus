import 'package:e_campus/models/chat_message.dart';
import 'package:e_campus/services/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'helpers.dart';

class FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

ChatMessage _msg(String from, String text) => ChatMessage(
  id: '',
  senderId: from,
  text: text,
  sentAt: DateTime.now().add(const Duration(seconds: 1)),
);

Future<void> _dismissBanner(WidgetTester t) async {
  // Let the banner finish sliding in before touching it.
  await t.pump(const Duration(milliseconds: 300));
  if (find.byKey(const ValueKey('message-banner')).evaluate().isNotEmpty) {
    await t.tap(find.byTooltip('Dismiss'));
    await t.pumpAndSettle();
  }
}

Future<void> _openChatWith(WidgetTester t, String name) async {
  await _dismissBanner(t);
  await openMenuItem(t, 'Chat');
  await t.tap(find.text(name));
  await t.pumpAndSettle();
}

Future<void> _send(WidgetTester t, String text) async {
  await t.enterText(find.widgetWithText(TextField, 'Message'), text);
  await t.tap(find.byTooltip('Send'));
  await t.pumpAndSettle();
}

void main() {
  group('who appears in the chat list', () {
    testWidgets('a student sees students and teachers of their department', (
      t,
    ) async {
      await startApp(t);
      await login(t, 'student@ecampus.demo'); // MCA
      await openMenuItem(t, 'Chat');
      for (final name in [
        'Arjun Student',
        'Kabir Student',
        'Ravi (CR)',
        'Meena MBA',
        'Prof. Rao',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      for (final name in [
        'Prof. Iyer', // MBA teacher
        'Lata Library',
        'Sunil Staff',
        'Asha Admin',
        'Dinesh Driver',
      ]) {
        expect(find.text(name), findsNothing, reason: name);
      }
    });

    testWidgets('a bus driver only sees staff', (t) async {
      await startApp(t);
      await login(t, 'driver@ecampus.demo');
      await openMenuItem(t, 'Chat');
      for (final name in [
        'Prof. Rao',
        'Prof. Iyer',
        'Lata Library',
        'Sunil Staff',
        'Asha Admin',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('Sneha Student'), findsNothing);
      expect(find.text('Meena MBA'), findsNothing);
    });

    testWidgets('the department filter narrows the list', (t) async {
      await startApp(t);
      await login(t, 'student@ecampus.demo');
      await openMenuItem(t, 'Chat');
      await t.tap(find.widgetWithText(ChoiceChip, 'MBA'));
      await t.pumpAndSettle();
      expect(find.text('Meena MBA'), findsOneWidget);
      expect(find.text('Arjun Student'), findsNothing);
      expect(find.text('Prof. Rao'), findsNothing);
      await t.tap(find.widgetWithText(ChoiceChip, 'MCA'));
      await t.pumpAndSettle();
      expect(find.text('Meena MBA'), findsNothing);
      expect(find.text('Arjun Student'), findsOneWidget);
      expect(find.text('Prof. Rao'), findsOneWidget);
      await t.tap(find.widgetWithText(ChoiceChip, 'All departments'));
      await t.pumpAndSettle();
      expect(find.text('Meena MBA'), findsOneWidget);
      expect(find.text('Arjun Student'), findsOneWidget);
    });
  });

  group('sending and the chat list', () {
    testWidgets('a sent message shows in the chat and as a preview', (t) async {
      await startApp(t);
      await login(t, 'student@ecampus.demo');
      await _openChatWith(t, 'Ravi (CR)');
      await _send(t, 'hello Ravi');
      expect(find.text('hello Ravi'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('You: hello Ravi'), findsOneWidget);
    });
  });

  group('new messages while the app is open', () {
    testWidgets('banner, drawer badge and unread dot', (t) async {
      final backend = await startApp(t);
      await login(t, 'student@ecampus.demo');
      await backend.sendMessage(
        chatIdFor('u-rep', 'u-student'),
        _msg('u-rep', 'meeting at 5'),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('message-banner')), findsOneWidget);
      final banner = find.byKey(const ValueKey('message-banner'));
      expect(
        find.descendant(of: banner, matching: find.text('Ravi (CR)')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: banner, matching: find.text('meeting at 5')),
        findsOneWidget,
      );
      // The menu icon carries a badge with the number of unread chats.
      expect(find.text('1'), findsWidgets);

      // "Open" on the banner jumps straight into that conversation.
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(find.text('meeting at 5'), findsOneWidget);
      expect(find.byKey(const ValueKey('message-banner')), findsNothing);

      // Back on the list, a new message shows a banner again, and a banner
      // that nobody touches disappears by itself.
      await t.pageBack();
      await t.pumpAndSettle();
      await backend.sendMessage(
        chatIdFor('u-rep', 'u-student'),
        _msg('u-rep', 'second'),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('message-banner')), findsOneWidget);
      await t.pump(const Duration(seconds: 7));
      expect(find.byKey(const ValueKey('message-banner')), findsNothing);
    });

    testWidgets('the unread dot clears once the chat is opened', (t) async {
      final backend = await startApp(t);
      await login(t, 'student@ecampus.demo');
      await backend.sendMessage(
        chatIdFor('u-rep', 'u-student'),
        _msg('u-rep', 'ping'),
      );
      await t.pump();
      await _dismissBanner(t);
      await openMenuItem(t, 'Chat');
      expect(find.byKey(const ValueKey('unread-u-rep')), findsOneWidget);
      await t.tap(find.text('Ravi (CR)'));
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('unread-u-rep')), findsNothing);
    });

    testWidgets('no banner for the chat you are looking at', (t) async {
      final backend = await startApp(t);
      await login(t, 'student@ecampus.demo');
      await _openChatWith(t, 'Ravi (CR)');
      await backend.sendMessage(
        chatIdFor('u-rep', 'u-student'),
        _msg('u-rep', 'live message'),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('live message'), findsOneWidget);
      expect(find.byKey(const ValueKey('message-banner')), findsNothing);
    });
  });

  group('message actions', () {
    testWidgets('edit shows an "edited" label', (t) async {
      await startApp(t);
      await login(t, 'student@ecampus.demo');
      await _openChatWith(t, 'Ravi (CR)');
      await _send(t, 'helo');
      await t.longPress(find.text('helo'));
      await t.pumpAndSettle();
      await t.tap(find.text('Edit'));
      await t.pumpAndSettle();
      expect(find.text('Editing message'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Message'), 'hello');
      await t.tap(find.byTooltip('Save'));
      await t.pumpAndSettle();
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('helo'), findsNothing);
      expect(find.textContaining('edited ·'), findsOneWidget);
      expect(find.text('Editing message'), findsNothing);
    });

    testWidgets('delete leaves "This message was deleted"', (t) async {
      await startApp(t);
      await login(t, 'student@ecampus.demo');
      await _openChatWith(t, 'Ravi (CR)');
      await _send(t, 'oops wrong chat');
      await t.longPress(find.text('oops wrong chat'));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete for everyone'));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(find.text('oops wrong chat'), findsNothing);
      expect(find.text('This message was deleted'), findsOneWidget);
    });

    testWidgets('only the sender sees edit and delete, both can pin', (
      t,
    ) async {
      final backend = await startApp(t);
      await login(t, 'student@ecampus.demo');
      await backend.sendMessage(
        chatIdFor('u-rep', 'u-student'),
        _msg('u-rep', 'from ravi'),
      );
      await t.pump();
      await _openChatWith(t, 'Ravi (CR)');
      await t.longPress(find.text('from ravi'));
      await t.pumpAndSettle();
      expect(find.text('Copy text'), findsOneWidget);
      expect(find.text('Pin'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete for everyone'), findsNothing);
    });

    testWidgets('pin shows a bar at the top, unpin removes it', (t) async {
      await startApp(t);
      await login(t, 'student@ecampus.demo');
      await _openChatWith(t, 'Ravi (CR)');
      await _send(t, 'exam on friday');
      expect(find.byKey(const ValueKey('pinned-bar')), findsNothing);
      await t.longPress(find.text('exam on friday'));
      await t.pumpAndSettle();
      await t.tap(find.text('Pin'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('pinned-bar')), findsOneWidget);
      await t.longPress(find.text('exam on friday').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Unpin'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('pinned-bar')), findsNothing);
    });
  });

  group('links', () {
    late FakeUrlLauncher launcher;
    setUp(() {
      launcher = FakeUrlLauncher();
      UrlLauncherPlatform.instance = launcher;
    });

    testWidgets('tapping a link in a message opens it', (t) async {
      await startApp(t);
      await login(t, 'student@ecampus.demo');
      await _openChatWith(t, 'Ravi (CR)');
      await _send(t, 'https://example.com/notes');
      await t.tap(find.text('https://example.com/notes'));
      await t.pumpAndSettle();
      expect(launcher.launched, ['https://example.com/notes']);
    });

    testWidgets('a message with a link offers "Copy link"', (t) async {
      await startApp(t);
      await login(t, 'student@ecampus.demo');
      await _openChatWith(t, 'Ravi (CR)');
      await _send(t, 'notes: https://example.com/n');
      await t.longPress(find.textContaining('notes:'));
      await t.pumpAndSettle();
      expect(find.text('Copy link'), findsOneWidget);
    });
  });
}
