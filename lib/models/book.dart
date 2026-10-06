class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.url,
  });

  final String id;
  final String title;
  final String author;
  final String category;

  /// Link to the downloadable / readable copy (PDF or web page).
  final String url;

  Map<String, dynamic> toMap() => {
    'title': title,
    'author': author,
    'category': category,
    'url': url,
  };

  factory Book.fromMap(String id, Map<String, dynamic> map) => Book(
    id: id,
    title: (map['title'] ?? '') as String,
    author: (map['author'] ?? '') as String,
    category: (map['category'] ?? 'General') as String,
    url: (map['url'] ?? '') as String,
  );
}
