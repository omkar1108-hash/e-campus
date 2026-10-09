import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/chat_message.dart';
import 'backend.dart';

/// A message that arrived while the app was open.
class IncomingMessage {
  const IncomingMessage({
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.text,
  });

  final String chatId;
  final String senderId;
  final String senderName;
  final String text;
}

/// Tracks the signed-in user's conversations: which have unread messages
/// (for the dots and the drawer badge) and announces new messages so the
/// app can show a banner. Push notifications while the app is closed are not
/// part of this; they need a paid Firebase plan.
class InboxController extends ChangeNotifier {
  InboxController(this.backend, this.me) {
    _chatsSub = backend.watchChats(me.uid).listen(_onChats);
    _readsSub = backend.watchReadMarkers(me.uid).listen((r) {
      reads = r;
      notifyListeners();
    });
    _usersSub = backend.watchUsers().listen((list) {
      users = {for (final u in list) u.uid: u};
      notifyListeners();
    });
  }

  final Backend backend;
  final AppUser me;

  Map<String, ChatSummary> chats = {};
  Map<String, DateTime> reads = {};
  Map<String, AppUser> users = {};

  /// The chat the user is looking at right now (no banner, always read).
  String? openChatId;

  final DateTime _startedAt = DateTime.now();
  bool _firstChats = true;
  final _incoming = StreamController<IncomingMessage>.broadcast();
  late final StreamSubscription<List<ChatSummary>> _chatsSub;
  late final StreamSubscription<Map<String, DateTime>> _readsSub;
  late final StreamSubscription<List<AppUser>> _usersSub;

  Stream<IncomingMessage> get incoming => _incoming.stream;

  bool isUnread(String chatId) {
    final c = chats[chatId];
    if (c == null || c.lastSenderId == me.uid) return false;
    return c.lastMessageAt.isAfter(
      reads[chatId] ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Number of conversations with something new.
  int get unreadCount => chats.keys.where(isUnread).length;

  void _onChats(List<ChatSummary> list) {
    final next = {for (final c in list) c.chatId: c};
    final toMarkRead = <String>[];
    if (!_firstChats) {
      for (final c in list) {
        final before = chats[c.chatId];
        final isNew =
            before == null || c.lastMessageAt.isAfter(before.lastMessageAt);
        if (!isNew ||
            c.lastSenderId == me.uid ||
            !c.lastMessageAt.isAfter(_startedAt)) {
          continue;
        }
        if (c.chatId == openChatId) {
          toMarkRead.add(c.chatId);
        } else {
          _incoming.add(
            IncomingMessage(
              chatId: c.chatId,
              senderId: c.lastSenderId,
              senderName: users[c.lastSenderId]?.name ?? 'New message',
              text: c.lastText,
            ),
          );
        }
      }
    }
    _firstChats = false;
    chats = next;
    notifyListeners();
    // After `chats` is current, so the marker covers the newest message.
    for (final id in toMarkRead) {
      markRead(id);
    }
  }

  void setOpen(String? chatId) {
    openChatId = chatId;
    if (chatId != null) markRead(chatId);
  }

  Future<void> markRead(String chatId) async {
    try {
      final now = DateTime.now();
      final last = chats[chatId]?.lastMessageAt;
      await backend.markRead(
        me.uid,
        chatId,
        at: (last != null && last.isAfter(now)) ? last : now,
      );
    } catch (_) {
      // A failed read marker only leaves a dot; never break the chat.
    }
  }

  @override
  void dispose() {
    _chatsSub.cancel();
    _readsSub.cancel();
    _usersSub.cancel();
    _incoming.close();
    super.dispose();
  }
}
