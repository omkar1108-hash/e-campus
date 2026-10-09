import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/image_service.dart';
import 'post_image.dart';

/// "Add image" control used in forms: shows a preview with Change / Remove.
class ImagePickerField extends StatefulWidget {
  const ImagePickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Add image',
    this.aspectRatio = 16 / 9,
  });

  /// Current picture as base64, or null.
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final double aspectRatio;

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  bool _busy = false;

  Future<void> _pick(bool camera) async {
    final picker = context.read<ImagePickerService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final picked = await picker.pick(camera: camera);
      if (picked != null) widget.onChanged(picked);
    } on ImageException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not load the picture: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final picker = context.read<ImagePickerService>();
    final bytes = decodeStoredImage(widget.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bytes != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: Image.memory(
                  bytes,
                  key: const ValueKey('image-preview'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(false),
              icon: const Icon(Icons.photo_library),
              label: Text(bytes == null ? widget.label : 'Change image'),
            ),
            if (picker.cameraAvailable)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(true),
                icon: const Icon(Icons.photo_camera),
                label: const Text('Camera'),
              ),
            if (bytes != null)
              TextButton.icon(
                onPressed: _busy ? null : () => widget.onChanged(null),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
