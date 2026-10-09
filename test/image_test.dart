import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:e_campus/models/book.dart';
import 'package:e_campus/models/news_item.dart';
import 'package:e_campus/services/image_service.dart';
import 'package:e_campus/utils/stream_merge.dart';
import 'package:e_campus/widgets/post_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A photo-like picture: smooth gradients with a little noise.
Uint8List photo(int w, int h, {int noise = 12, bool png = false}) {
  final rnd = Random(1);
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      int c(int base) => (base + rnd.nextInt(noise + 1)).clamp(0, 255);
      image.setPixelRgb(
        x,
        y,
        c((x * 255 / w).round()),
        c((y * 255 / h).round()),
        c(((x + y) * 255 / (w + h)).round()),
      );
    }
  }
  return Uint8List.fromList(png ? img.encodePng(image) : img.encodeJpg(image));
}

void main() {
  group('compressImage', () {
    test('shrinks a big landscape photo to at most 800 px', () {
      final out = compressImage(photo(2400, 1600));
      final back = img.decodeJpg(out)!;
      expect(back.width, 800);
      expect(back.height, closeTo(533, 1));
      expect(out.length, lessThanOrEqualTo(300 * 1024));
    });

    test('shrinks a tall photo by its height', () {
      final back = img.decodeJpg(compressImage(photo(1200, 2000)))!;
      expect(back.height, 800);
      expect(back.width, 480);
    });

    test('does not enlarge a small picture and accepts PNG input', () {
      final back = img.decodeJpg(compressImage(photo(200, 100, png: true)))!;
      expect(back.width, 200);
      expect(back.height, 100);
    });

    test('result always fits a Firestore document with room to spare', () {
      final out = compressImage(photo(3000, 2000, noise: 120));
      // base64 is a third bigger; the rules allow 700,000 characters.
      expect(base64Encode(out).length, lessThan(700000));
    });

    test('rejects a file that is not a picture', () {
      expect(
        () => compressImage(Uint8List.fromList(utf8.encode('hello'))),
        throwsA(isA<ImageException>()),
      );
    });
  });

  group('decodeStoredImage', () {
    test('decodes valid base64, tolerates missing or broken data', () {
      expect(decodeStoredImage(base64Encode([1, 2, 3])), [1, 2, 3]);
      expect(decodeStoredImage(null), isNull);
      expect(decodeStoredImage(''), isNull);
      expect(decodeStoredImage('%%% not base64 %%%'), isNull);
    });
  });

  group('Book', () {
    test('books from before approvals count as approved', () {
      final b = Book.fromMap('1', {'title': 'T', 'author': 'A', 'url': 'u'});
      expect(b.status, BookStatus.approved);
      expect(b.uploadedBy, '');
      expect(b.cover, isNull);
    });

    test('round trips through a map', () {
      final b = Book(
        id: 'x',
        title: 'T',
        author: 'A',
        category: 'C',
        url: 'https://u',
        isbn: '978-0-262-04630-5',
        cover: 'abc',
        status: BookStatus.rejected,
        uploadedBy: 'u1',
        uploadedByName: 'Prof',
        rejectReason: 'bad link',
      );
      final back = Book.fromMap('x', b.toMap());
      expect(back.status, BookStatus.rejected);
      expect(back.rejectReason, 'bad link');
      expect(back.cover, 'abc');
      expect(back.uploadedBy, 'u1');
    });

    test('ISBN is cleaned and builds an Open Library cover link', () {
      const b = Book(
        id: 'x',
        title: 'T',
        author: 'A',
        category: 'C',
        url: 'u',
        isbn: '978-0 262-04630-5',
      );
      expect(b.cleanIsbn, '9780262046305');
      expect(
        b.coverUrl,
        'https://covers.openlibrary.org/b/isbn/9780262046305-M.jpg?default=false',
      );
      expect(
        const Book(
          id: 'x',
          title: 'T',
          author: 'A',
          category: 'C',
          url: 'u',
        ).coverUrl,
        isNull,
      );
    });

    test('a book without a cover omits the field when saved', () {
      const b = Book(id: 'x', title: 'T', author: 'A', category: 'C', url: 'u');
      expect(b.toMap().containsKey('cover'), isFalse);
    });
  });

  group('NewsItem', () {
    test('image is optional and round trips', () {
      final plain = NewsItem(
        id: '1',
        title: 't',
        body: 'b',
        department: 'MCA',
        authorName: 'a',
        createdAt: DateTime(2026),
      );
      expect(plain.toMap().containsKey('image'), isFalse);
      expect(NewsItem.fromMap('1', plain.toMap()).image, isNull);
      final withImage = NewsItem(
        id: '1',
        title: 't',
        body: 'b',
        department: 'MCA',
        authorName: 'a',
        createdAt: DateTime(2026),
        image: 'abc',
      );
      expect(NewsItem.fromMap('1', withImage.toMap()).image, 'abc');
    });
  });

  group('mergeLists', () {
    test('waits for both streams, then merges and de-duplicates', () async {
      final a = Stream.fromIterable([
        [1, 2],
        [1, 2, 3],
      ]);
      final b = Stream.fromIterable([
        [3, 4],
      ]);
      final seen = await mergeLists<int>(a, b, (i) => '$i').toList();
      expect(seen, isNotEmpty);
      expect(seen.last.toSet(), {1, 2, 3, 4});
      expect(seen.last.length, 4, reason: 'no duplicates');
    });

    test('later changes of either stream show up', () async {
      final a = Stream<List<int>>.fromFutures([
        Future.value([1]),
        Future.delayed(const Duration(milliseconds: 20), () => [1, 2]),
      ]);
      final b = Stream.value(<int>[9]);
      final seen = await mergeLists<int>(a, b, (i) => '$i').toList();
      expect(seen.last.toSet(), {1, 2, 9});
    });

    test('errors are passed on', () async {
      final a = Stream<List<int>>.error(StateError('boom'));
      final b = Stream.value(<int>[]);
      await expectLater(
        mergeLists<int>(a, b, (i) => '$i'),
        emitsError(isA<StateError>()),
      );
    });
  });
}
