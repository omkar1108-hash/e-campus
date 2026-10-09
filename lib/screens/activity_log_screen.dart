import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/campus.dart';
import '../services/backend.dart';
import '../widgets/common.dart';

/// Administrator: who created or disabled accounts, who deleted books, and
/// other sensitive actions. The log is written by the app itself, so it is
/// a convenient record rather than tamper-proof evidence.
class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  static const _filters = <(String, String?)>[
    ('All', null),
    ('Accounts', 'account'),
    ('Books', 'book'),
    ('News & notices', 'news,notice'),
    ('Buses', 'bus'),
    ('Complaints', 'complaint'),
    ('Alerts', 'alert'),
  ];
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final fmt = DateFormat('d MMM, h:mm a');
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            children: [
              for (final f in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.$1),
                    selected: _filter == f.$2,
                    onSelected: (_) => setState(() => _filter = f.$2),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Live<List<ActivityEntry>>(
            stream: backend.watchActivity(),
            builder: (context, all) {
              final types = _filter?.split(',');
              final items = all
                  .where((e) => types == null || types.contains(e.targetType))
                  .toList();
              if (items.isEmpty) {
                return const EmptyState(
                  'Nothing recorded yet',
                  icon: Icons.history,
                );
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = items[i];
                  return ListTile(
                    leading: Icon(_icon(e.targetType)),
                    title: Text(e.sentence),
                    subtitle: Text(fmt.format(e.createdAt)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  static IconData _icon(String type) => switch (type) {
    'account' => Icons.person,
    'book' => Icons.menu_book,
    'news' => Icons.newspaper,
    'notice' => Icons.campaign,
    'bus' => Icons.directions_bus,
    'complaint' => Icons.report_problem,
    'alert' => Icons.warning_amber,
    _ => Icons.history,
  };
}
