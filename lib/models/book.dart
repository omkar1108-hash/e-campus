/// Where a book is in the approval process.
///
/// Books added by teachers start as [pending] until library staff approve
/// them. Books added by library staff, admin staff or admin are
/// [approved] straight away.
enum BookStatus {
  pending('Waiting for verification'),
  approved('Approved'),
  rejected('Rejected');

  const BookStatus(this.label);
  final String label;

  static BookStatus fromName(String? name) => BookStatus.values.firstWhere(
    (s) => s.name == name,
    // Books added before approvals existed count as approved.
    orElse: () => BookStatus.approved,
  );
}

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.url,
    this.isbn = '',
    this.cover,
    this.status = BookStatus.approved,
    this.uploadedBy = '',
    this.uploadedByName = '',
    this.rejectReason = '',
    this.createdAt,
  });

  final String id;
  final String title;
  final String author;
  final String category;

  /// Link to the downloadable / readable copy (PDF or web page).
  final String url;

  /// Optional; used to fetch the cover from Open Library.
  final String isbn;

  /// Optional cover picture picked from the gallery (base64 JPEG).
  final String? cover;

  final BookStatus status;
  final String uploadedBy;
  final String uploadedByName;

  /// Why library staff rejected the book (shown to the teacher).
  final String rejectReason;
  final DateTime? createdAt;

  /// ISBN with spaces and dashes removed.
  String get cleanIsbn => isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');

  /// Open Library cover for the ISBN. `default=false` makes the service
  /// answer 404 when it has no cover, so the app can show a placeholder.
  String? get coverUrl => cleanIsbn.isEmpty
      ? null
      : 'https://covers.openlibrary.org/b/isbn/$cleanIsbn-M.jpg?default=false';

  Book copyWith({
    String? title,
    String? author,
    String? category,
    String? url,
    String? isbn,
    String? cover,
    bool clearCover = false,
    BookStatus? status,
    String? rejectReason,
  }) => Book(
    id: id,
    title: title ?? this.title,
    author: author ?? this.author,
    category: category ?? this.category,
    url: url ?? this.url,
    isbn: isbn ?? this.isbn,
    cover: clearCover ? null : (cover ?? this.cover),
    status: status ?? this.status,
    uploadedBy: uploadedBy,
    uploadedByName: uploadedByName,
    rejectReason: rejectReason ?? this.rejectReason,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'author': author,
    'category': category,
    'url': url,
    'isbn': isbn,
    if (cover != null) 'cover': cover,
    'status': status.name,
    'uploadedBy': uploadedBy,
    'uploadedByName': uploadedByName,
    'rejectReason': rejectReason,
    'createdAt': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
  };

  factory Book.fromMap(String id, Map<String, dynamic> map) => Book(
    id: id,
    title: (map['title'] ?? '') as String,
    author: (map['author'] ?? '') as String,
    category: (map['category'] ?? 'General') as String,
    url: (map['url'] ?? '') as String,
    isbn: (map['isbn'] ?? '') as String,
    cover: map['cover'] as String?,
    status: BookStatus.fromName(map['status'] as String?),
    uploadedBy: (map['uploadedBy'] ?? '') as String,
    uploadedByName: (map['uploadedByName'] ?? '') as String,
    rejectReason: (map['rejectReason'] ?? '') as String,
    createdAt: map['createdAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
  );
}
