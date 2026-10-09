import 'package:flutter/material.dart';

/// A centred message for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key, this.icon = Icons.inbox});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

String? requiredField(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Required' : null;

/// Accepts http(s) links and www. addresses; empty is allowed.
String? optionalLink(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return null;
  final uri = Uri.tryParse(
    t.toLowerCase().startsWith('www.') ? 'https://$t' : t,
  );
  final ok =
      uri != null &&
      uri.hasAuthority &&
      uri.host.contains('.') &&
      (uri.scheme == 'http' ||
          uri.scheme == 'https' ||
          t.toLowerCase().startsWith('www.'));
  return ok ? null : 'Enter a web address starting with https://';
}

/// Builds a [StreamBuilder] with the usual loading / error handling.
class Live<T> extends StatelessWidget {
  const Live({super.key, required this.stream, required this.builder});

  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
    stream: stream,
    builder: (context, snap) {
      if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return builder(context, snap.data as T);
    },
  );
}
