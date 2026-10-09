import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/campus.dart';
import '../services/backend.dart';
import '../widgets/common.dart';

/// Administrator: send an emergency alert to everybody using the app, and
/// clear it again. Alerts are shown inside the app only (no push messages).
class AlertScreen extends StatefulWidget {
  const AlertScreen({super.key});

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    final backend = context.read<Backend>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send emergency alert?'),
        content: Text(
          'Everyone using the app will see this on screen:\n\n"$text"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send to everyone'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await backend.sendAlert(text);
      _message.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final fmt = DateFormat('d MMM, h:mm a');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Emergency alert', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
          'Appears as a red banner for every signed-in user, drivers '
          'included, until you clear it. It is shown inside the app only.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _message,
          maxLength: 300,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Alert message',
            hintText: 'e.g. Campus closed today because of heavy rain',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _busy ? null : _send,
          icon: const Icon(Icons.warning_amber),
          label: const Text('Send alert'),
        ),
        const SizedBox(height: 24),
        Text('Active alerts', style: Theme.of(context).textTheme.titleMedium),
        Live<List<EmergencyAlert>>(
          stream: backend.watchActiveAlerts(),
          builder: (context, alerts) => alerts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No active alerts.'),
                )
              : Column(
                  children: [
                    for (final a in alerts)
                      Card(
                        color: Colors.red.shade50,
                        child: ListTile(
                          leading: const Icon(Icons.warning, color: Colors.red),
                          title: Text(a.message),
                          subtitle: Text(
                            '${a.authorName} · ${fmt.format(a.createdAt)}',
                          ),
                          trailing: TextButton(
                            onPressed: () => backend.clearAlert(a.id),
                            child: const Text('Clear'),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
