class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.editedAt,
    this.deleted = false,
    this.pinned = false,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;

  /// Set when the sender edited the message.
  final DateTime? editedAt;

  /// A deleted message keeps its place in the chat but loses its text.
  final bool deleted;

  /// Either person in the chat can pin a message.
  final bool pinned;

  /// Senders may edit their own messages for this long.
  static const editWindow = Duration(minutes: 15);

  bool canEdit(String uid, DateTime now) =>
      senderId == uid && !deleted && now.difference(sentAt) <= editWindow;

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'text': text,
    'sentAt': sentAt.millisecondsSinceEpoch,
    'deleted': false,
    'pinned': false,
  };

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) =>
      ChatMessage(
        id: id,
        senderId: (map['senderId'] ?? '') as String,
        text: (map['text'] ?? '') as String,
        sentAt: DateTime.fromMillisecondsSinceEpoch(
          (map['sentAt'] ?? 0) as int,
        ),
        editedAt: map['editedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['editedAt'] as int),
        deleted: (map['deleted'] ?? false) as bool,
        pinned: (map['pinned'] ?? false) as bool,
      );
}

/// The latest activity of one conversation, used for the chat list,
/// unread dots and the "new message" banner.
class ChatSummary {
  const ChatSummary({
    required this.chatId,
    required this.participants,
    required this.lastText,
    required this.lastMessageAt,
    required this.lastSenderId,
  });

  final String chatId;
  final List<String> participants;
  final String lastText;
  final DateTime lastMessageAt;
  final String lastSenderId;

  String otherUid(String me) =>
      participants.firstWhere((p) => p != me, orElse: () => me);

  factory ChatSummary.fromMap(String chatId, Map<String, dynamic> map) =>
      ChatSummary(
        chatId: chatId,
        participants: List<String>.from(
          (map['participants'] ?? const []) as List,
        ),
        lastText: (map['lastText'] ?? '') as String,
        lastMessageAt: DateTime.fromMillisecondsSinceEpoch(
          (map['lastMessageAt'] ?? 0) as int,
        ),
        lastSenderId: (map['lastSenderId'] ?? '') as String,
      );
}
