class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.body,
    required this.department,
    required this.authorName,
    required this.createdAt,
    this.image,
  });

  final String id;
  final String title;
  final String body;
  final String department;
  final String authorName;
  final DateTime createdAt;

  /// Optional poster picture (base64 JPEG, picked from the gallery).
  final String? image;

  Map<String, dynamic> toMap() => {
    'title': title,
    'body': body,
    'department': department,
    'authorName': authorName,
    'createdAt': createdAt.millisecondsSinceEpoch,
    if (image != null) 'image': image,
  };

  factory NewsItem.fromMap(String id, Map<String, dynamic> map) => NewsItem(
    id: id,
    title: (map['title'] ?? '') as String,
    body: (map['body'] ?? '') as String,
    department: (map['department'] ?? '') as String,
    authorName: (map['authorName'] ?? '') as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (map['createdAt'] ?? 0) as int,
    ),
    image: map['image'] as String?,
  );
}
