import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Decodes a stored base64 picture, or null if there is none / it is broken.
Uint8List? decodeStoredImage(String? base64Text) {
  if (base64Text == null || base64Text.isEmpty) return null;
  try {
    return base64Decode(base64Text);
  } catch (_) {
    return null;
  }
}

/// A news poster: full width, 16:9, tap to see it full screen.
class PostImage extends StatelessWidget {
  const PostImage({super.key, required this.base64Image});

  final String base64Image;

  @override
  Widget build(BuildContext context) {
    final bytes = decodeStoredImage(base64Image);
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: bytes == null
            ? ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(Icons.broken_image, color: scheme.outline),
              )
            : GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FullScreenImage(bytes: bytes),
                  ),
                ),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Icon(Icons.broken_image, color: scheme.outline),
                  ),
                ),
              ),
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  const FullScreenImage({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
