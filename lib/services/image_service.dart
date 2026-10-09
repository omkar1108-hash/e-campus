import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class ImageException implements Exception {
  const ImageException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Shrinks a picked photo so it can be stored inside a Firestore document
/// (a document may not exceed 1 MB, and the text form of the image is a third
/// bigger than the bytes).
///
/// Pure Dart so it runs on every platform. Tries a few smaller sizes and
/// qualities until the JPEG is small enough.
/// The picture formats the app accepts, recognised by their first bytes.
/// (The decoder alone is too forgiving and would "read" random files.)
bool _looksLikeImage(Uint8List b) {
  bool starts(List<int> sig, [int offset = 0]) {
    if (b.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[offset + i] != sig[i]) return false;
    }
    return true;
  }

  return starts([0xFF, 0xD8, 0xFF]) || // JPEG
      starts([0x89, 0x50, 0x4E, 0x47]) || // PNG
      starts([0x47, 0x49, 0x46, 0x38]) || // GIF
      starts([0x42, 0x4D]) || // BMP
      (starts([0x52, 0x49, 0x46, 0x46]) &&
          starts([0x57, 0x45, 0x42, 0x50], 8)); // WebP
}

Uint8List compressImage(Uint8List bytes) {
  const steps = <(int, int)>[
    (800, 75),
    (800, 60),
    (640, 60),
    (640, 45),
    (480, 45),
    (480, 35),
  ];
  const goodEnough = 300 * 1024;
  const hardLimit = 500 * 1024;

  final decoded = _looksLikeImage(bytes) ? img.decodeImage(bytes) : null;
  if (decoded == null) {
    throw const ImageException('That file is not a picture we can read.');
  }
  final upright = img.bakeOrientation(decoded);

  Uint8List? best;
  for (final (maxSide, quality) in steps) {
    final scaled = upright.width >= upright.height
        ? (upright.width > maxSide
              ? img.copyResize(upright, width: maxSide)
              : upright)
        : (upright.height > maxSide
              ? img.copyResize(upright, height: maxSide)
              : upright);
    final jpg = Uint8List.fromList(img.encodeJpg(scaled, quality: quality));
    if (best == null || jpg.length < best.length) best = jpg;
    if (jpg.length <= goodEnough) return jpg;
  }
  if (best != null && best.length <= hardLimit) return best;
  throw const ImageException(
    'This picture is too detailed to store. Try a simpler or smaller one.',
  );
}

/// Where pictures come from: the gallery or the camera.
abstract class ImagePickerService {
  bool get cameraAvailable;

  /// Returns the shrunken picture as base64 text, or null if the user
  /// cancelled. Throws [ImageException] if the file cannot be used.
  Future<String?> pick({bool camera = false});
}

class DeviceImagePicker implements ImagePickerService {
  DeviceImagePicker() : _picker = ImagePicker();

  final ImagePicker _picker;

  @override
  bool get cameraAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<String?> pick({bool camera = false}) async {
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      // Cuts memory use on phones before our own shrinking.
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    // Decoding a big photo is slow: do it off the UI thread where possible.
    final small = kIsWeb
        ? compressImage(bytes)
        : await compute(compressImage, bytes);
    return base64Encode(small);
  }
}
