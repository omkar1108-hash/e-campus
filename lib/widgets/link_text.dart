import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Splits [text] into plain parts and web links.
///
/// Only http(s) links and `www.` addresses count. A trailing full stop,
/// comma or bracket is not part of the link.
List<({String text, Uri? link})> splitLinks(String text) {
  final pattern = RegExp(
    r'((?:https?://|www\.)[^\s<>]+)',
    caseSensitive: false,
  );
  final parts = <({String text, Uri? link})>[];
  var index = 0;
  for (final m in pattern.allMatches(text)) {
    var raw = m.group(0)!;
    // Punctuation that usually ends a sentence, not the address.
    while (raw.isNotEmpty && '.,;:!?)]}\'"'.contains(raw[raw.length - 1])) {
      raw = raw.substring(0, raw.length - 1);
    }
    final uri = Uri.tryParse(
      raw.toLowerCase().startsWith('www.') ? 'https://$raw' : raw,
    );
    if (raw.isEmpty || uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      continue;
    }
    if (m.start > index) {
      parts.add((text: text.substring(index, m.start), link: null));
    }
    parts.add((text: raw, link: uri));
    index = m.start + raw.length;
  }
  if (index < text.length) {
    parts.add((text: text.substring(index), link: null));
  }
  return parts;
}

/// Text whose web addresses can be tapped to open them in the browser.
class LinkText extends StatefulWidget {
  const LinkText(this.text, {super.key, this.style, this.selectable = false});

  final String text;
  final TextStyle? style;

  /// Allow selecting and copying the text (used for chatbot answers).
  final bool selectable;

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  final _recognizers = <GestureRecognizer>[];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  Future<void> _open(Uri uri) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not open ${uri.host}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final linkStyle = base.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    final spans = <InlineSpan>[
      for (final part in splitLinks(widget.text))
        if (part.link == null)
          TextSpan(text: part.text)
        else
          TextSpan(
            text: part.text,
            style: linkStyle,
            recognizer: (TapGestureRecognizer()
              ..onTap = () => _open(part.link!)),
          ),
    ];
    final span = TextSpan(style: base, children: spans);
    return widget.selectable ? SelectableText.rich(span) : Text.rich(span);
  }
}
