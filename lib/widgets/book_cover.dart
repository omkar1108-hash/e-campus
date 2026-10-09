import 'package:flutter/material.dart';

import '../models/book.dart';
import 'post_image.dart';

/// Cover picture of a book: the uploaded one, else the Open Library cover
/// for its ISBN, else a book icon.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.width = 48});

  final Book book;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.4;
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder() => Container(
      width: width,
      height: height,
      color: scheme.secondaryContainer,
      child: Icon(Icons.menu_book, color: scheme.onSecondaryContainer),
    );

    final uploaded = decodeStoredImage(book.cover);
    final Widget image;
    if (uploaded != null) {
      image = Image.memory(
        uploaded,
        width: width,
        height: height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => placeholder(),
      );
    } else if (book.cleanIsbn.isNotEmpty) {
      image = Image.network(
        book.coverUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder(),
      );
    } else {
      image = placeholder();
    }
    return ClipRRect(borderRadius: BorderRadius.circular(4), child: image);
  }
}
