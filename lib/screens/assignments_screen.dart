import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../models/campus.dart';
import '../services/backend.dart';
import '../utils/rbac.dart';
import '../widgets/common.dart';
import '../widgets/link_text.dart';

/// Assignments and notes shared as links (a Drive / OneDrive link works).
/// Teachers post; students see their own department's items.
class AssignmentsScreen extends StatelessWidget {
  const AssignmentsScreen({super.key, required this.user});

  final AppUser user;

  Future<void> _post(BuildContext context) async {
    final backend = context.read<Backend>();
    final item = await showDialog<Assignment>(
      context: context,
      builder: (_) => _PostDialog(user: user),
    );
    if (item != null) await backend.addAssignment(item);
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final fmt = DateFormat('d MMM yyyy');
    return Scaffold(
      floatingActionButton: Rbac.canPostAssignments(user)
          ? FloatingActionButton.extended(
              onPressed: () => _post(context),
              icon: const Icon(Icons.add),
              label: const Text('Share'),
            )
          : null,
      body: Live<List<Assignment>>(
        stream: backend.watchAssignments(user),
        builder: (context, items) {
          if (items.isEmpty) {
            return const EmptyState(
              'No assignments or notes yet',
              icon: Icons.assignment_outlined,
            );
          }
          final now = DateTime.now();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final a = items[i];
              final overdue =
                  a.dueDate != null &&
                  a.kind == WorkKind.assignment &&
                  a.dueDate!.isBefore(now);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            a.kind == WorkKind.assignment
                                ? Icons.assignment
                                : Icons.description,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              a.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (Rbac.canDeleteAssignment(user, a.createdBy))
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => backend.deleteAssignment(a.id),
                            ),
                        ],
                      ),
                      Text(
                        [
                          a.kind.label,
                          if (a.subject.isNotEmpty) a.subject,
                          a.department,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (a.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        LinkText(a.description),
                      ],
                      if (a.link.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        LinkText(a.link),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (a.dueDate != null)
                            Chip(
                              avatar: Icon(
                                Icons.event,
                                size: 16,
                                color: overdue ? Colors.red : null,
                              ),
                              label: Text(
                                '${overdue ? 'Was due' : 'Due'} '
                                '${fmt.format(a.dueDate!)}',
                              ),
                            ),
                          const Spacer(),
                          Text(
                            a.createdByName,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PostDialog extends StatefulWidget {
  const _PostDialog({required this.user});

  final AppUser user;

  @override
  State<_PostDialog> createState() => _PostDialogState();
}

class _PostDialogState extends State<_PostDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _link = TextEditingController();
  WorkKind _kind = WorkKind.assignment;
  late String _department = widget.user.department;
  DateTime? _due;

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _description.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() => _due = DateTime(d.year, d.month, d.day, 23, 59));
    }
  }

  @override
  Widget build(BuildContext context) {
    final departments = {
      ...AppConfig.departments,
      widget.user.department,
    }.where((d) => d.isNotEmpty).toList();
    return AlertDialog(
      title: const Text('Share with students'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<WorkKind>(
                segments: [
                  for (final k in WorkKind.values)
                    ButtonSegment(value: k, label: Text(k.label)),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _department,
                decoration: const InputDecoration(labelText: 'Department'),
                items: [
                  for (final d in departments)
                    DropdownMenuItem(value: d, child: Text(d)),
                ],
                onChanged: (v) =>
                    setState(() => _department = v ?? _department),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subject,
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: requiredField,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: requiredField,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Instructions (optional)',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _link,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Link to the file (optional)',
                  hintText: 'https://drive.google.com/...',
                ),
                validator: optionalLink,
              ),
              if (_kind == WorkKind.assignment) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _due == null
                            ? 'No due date'
                            : 'Due ${DateFormat('d MMM yyyy').format(_due!)}',
                      ),
                    ),
                    TextButton(
                      onPressed: _pickDue,
                      child: const Text('Set due date'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              Assignment(
                id: '',
                kind: _kind,
                department: _department,
                subject: _subject.text.trim(),
                title: _title.text.trim(),
                description: _description.text.trim(),
                link: _link.text.trim(),
                dueDate: _kind == WorkKind.assignment ? _due : null,
                createdBy: widget.user.uid,
                createdByName: widget.user.name,
                createdAt: DateTime.now(),
              ),
            );
          },
          child: const Text('Share'),
        ),
      ],
    );
  }
}
