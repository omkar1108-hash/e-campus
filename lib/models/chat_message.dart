class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'text': text,
    'sentAt': sentAt.millisecondsSinceEpoch,
  };

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) =>
      ChatMessage(
        id: id,
        senderId: (map['senderId'] ?? '') as String,
        text: (map['text'] ?? '') as String,
        sentAt: DateTime.fromMillisecondsSinceEpoch(
          (map['sentAt'] ?? 0) as int,
        ),
      );
}
