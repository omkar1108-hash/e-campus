import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/campus.dart';
import '../services/backend.dart';
import '../utils/rbac.dart';
import '../widgets/common.dart';

Color statusColor(ComplaintStatus s) => switch (s) {
  ComplaintStatus.submitted => Colors.orange.shade800,
  ComplaintStatus.inReview => Colors.blue.shade700,
  ComplaintStatus.resolved => Colors.teal.shade700,
  ComplaintStatus.closed => Colors.green.shade800,
  ComplaintStatus.rejected => Colors.red.shade700,
};

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final ComplaintStatus status;

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(status.chip, style: TextStyle(color: c, fontSize: 12)),
      side: BorderSide(color: c.withValues(alpha: 0.6)),
      backgroundColor: c.withValues(alpha: 0.1),
    );
  }
}

/// Complaints. Everybody except the committee files complaints and follows
/// them under "My complaints"; the Grievance Committee and the administrator
/// also get the "All complaints" inbox.
class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final tabs = <(String, Widget)>[
      if (Rbac.canViewAllComplaints(user))
        ('All complaints', _InboxTab(user: user)),
      if (Rbac.canFileComplaint(user)) ('My complaints', _MineTab(user: user)),
    ];
    if (tabs.length == 1) return tabs.first.$2;
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(tabs: [for (final t in tabs) Tab(text: t.$1)]),
          Expanded(child: TabBarView(children: [for (final t in tabs) t.$2])),
        ],
      ),
    );
  }
}

// ---- My complaints ----------------------------------------------------------
class _MineTab extends StatelessWidget {
  const _MineTab({required this.user});

  final AppUser user;

  Future<void> _file(BuildContext context) async {
    final backend = context.read<Backend>();
    final messenger = ScaffoldMessenger.of(context);
    final form = await showDialog<_ComplaintForm>(
      context: context,
      builder: (_) => const _FileDialog(),
    );
    if (form == null) return;
    try {
      await backend.fileComplaint(
        category: form.category,
        subject: form.subject,
        description: form.description,
        anonymous: form.anonymous,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Complaint submitted')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not submit: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final fmt = DateFormat('d MMM yyyy');
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _file(context),
        icon: const Icon(Icons.edit_note),
        label: const Text('File a complaint'),
      ),
      body: Live<List<ComplaintIdentity>>(
        stream: backend.watchMyComplaints(user.uid),
        builder: (context, items) {
          if (items.isEmpty) {
            return const EmptyState(
              'You have not filed any complaints.\n'
              'Use the button below - you can stay anonymous.',
              icon: Icons.report_outlined,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final c = items[i];
              return Card(
                child: ListTile(
                  leading: Icon(
                    c.anonymous ? Icons.visibility_off : Icons.person,
                  ),
                  title: Text(c.subject),
                  subtitle: Text(
                    '${c.category.label} · ${fmt.format(c.createdAt)}'
                    '${c.anonymous ? ' · anonymous' : ''}',
                  ),
                  trailing: StatusChip(c.status),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ComplaintDetailScreen(
                        user: user,
                        complaintId: c.id,
                        asFiler: true,
                      ),
                    ),
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

class _ComplaintForm {
  const _ComplaintForm(
    this.category,
    this.subject,
    this.description,
    this.anonymous,
  );
  final ComplaintCategory category;
  final String subject;
  final String description;
  final bool anonymous;
}

class _FileDialog extends StatefulWidget {
  const _FileDialog();

  @override
  State<_FileDialog> createState() => _FileDialogState();
}

class _FileDialogState extends State<_FileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  ComplaintCategory _category = ComplaintCategory.academic;
  bool _anonymous = false;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('File a complaint'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ComplaintCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in ComplaintCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subject,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: requiredField,
              ),
              TextFormField(
                controller: _description,
                maxLines: 5,
                maxLength: 4000,
                decoration: const InputDecoration(labelText: 'What happened?'),
                validator: requiredField,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('File anonymously'),
                subtitle: Text(
                  _anonymous
                      ? 'The Grievance Committee will not see your name. '
                            'The college administrator can still see who '
                            'filed it, to prevent misuse.'
                      : 'The Grievance Committee will see your name.',
                ),
                value: _anonymous,
                onChanged: (v) => setState(() => _anonymous = v),
              ),
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
              _ComplaintForm(
                _category,
                _subject.text.trim(),
                _description.text.trim(),
                _anonymous,
              ),
            );
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

// ---- Committee / admin inbox ------------------------------------------------
class _InboxTab extends StatefulWidget {
  const _InboxTab({required this.user});

  final AppUser user;

  @override
  State<_InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<_InboxTab> {
  ComplaintStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final fmt = DateFormat('d MMM yyyy');
    return Live<List<Complaint>>(
      stream: backend.watchAllComplaints(),
      builder: (context, all) {
        final items = all
            .where((c) => _filter == null || c.status == _filter)
            .toList();
        return Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('All (${all.length})'),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                  ),
                  for (final s in ComplaintStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          '${s.chip} (${all.where((c) => c.status == s).length})',
                        ),
                        selected: _filter == s,
                        onSelected: (_) => setState(() => _filter = s),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const EmptyState(
                      'No complaints here',
                      icon: Icons.inbox_outlined,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final c = items[i];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              c.anonymous ? Icons.visibility_off : Icons.person,
                            ),
                            title: Text(c.subject),
                            subtitle: Text(
                              '${c.category.label} · '
                              '${c.anonymous ? 'Anonymous' : '${c.displayName}, ${c.displayDepartment}'}'
                              ' · ${fmt.format(c.createdAt)}',
                            ),
                            trailing: StatusChip(c.status),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ComplaintDetailScreen(
                                  user: widget.user,
                                  complaintId: c.id,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ---- Detail ---------------------------------------------------------------------
class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({
    super.key,
    required this.user,
    required this.complaintId,
    this.asFiler = false,
  });

  final AppUser user;
  final String complaintId;

  /// Opened from "My complaints": the viewer is the person who filed it.
  final bool asFiler;

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final _reply = TextEditingController();
  Future<ComplaintIdentity?>? _identity;

  @override
  void initState() {
    super.initState();
    if (Rbac.canSeeComplaintIdentity(widget.user)) {
      _identity = context.read<Backend>().getComplaintIdentity(
        widget.complaintId,
      );
    }
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    _reply.clear();
    await context.read<Backend>().addReply(widget.complaintId, text);
  }

  Future<void> _changeStatus(ComplaintStatus to, {String? title}) async {
    final backend = context.read<Backend>();
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _StatusDialog(status: to, title: title),
    );
    if (note != null) {
      await backend.setComplaintStatus(widget.complaintId, to, note: note);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final me = widget.user;
    final fmt = DateFormat('d MMM, h:mm a');
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Complaint')),
      body: StreamBuilder<Complaint?>(
        stream: backend.watchComplaint(widget.complaintId),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final c = snap.data;
          if (c == null) return const EmptyState('Complaint not found');
          // The committee always may reply; the person who filed it only
          // while it is open. The administrator just reads.
          final canReply =
              Rbac.canHandleComplaints(me) ||
              (widget.asFiler && !c.status.isFinal);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.subject,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        StatusChip(c.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${c.category.label} · ${fmt.format(c.createdAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.anonymous
                          ? 'Filed anonymously'
                          : 'Filed by ${c.displayName} (${c.displayDepartment})',
                    ),
                    if (_identity != null)
                      FutureBuilder<ComplaintIdentity?>(
                        future: _identity,
                        builder: (context, s) {
                          final id = s.data;
                          if (id == null || !id.anonymous) {
                            return const SizedBox.shrink();
                          }
                          return Card(
                            key: const ValueKey('admin-identity'),
                            color: theme.colorScheme.tertiaryContainer,
                            child: ListTile(
                              leading: const Icon(Icons.admin_panel_settings),
                              title: Text(
                                'Filed by ${id.filedByName} (${id.filedByDepartment})',
                              ),
                              subtitle: const Text(
                                'Only you, as administrator, can see this.',
                              ),
                            ),
                          );
                        },
                      ),
                    const Divider(height: 24),
                    SelectableText(c.description),
                    if (Rbac.canHandleComplaints(me) &&
                        c.status.next.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final s in c.status.next)
                            OutlinedButton(
                              onPressed: () => _changeStatus(s),
                              child: Text('Mark ${s.chip}'),
                            ),
                        ],
                      ),
                    ],
                    if (widget.asFiler && c.status.filerNext.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: theme.colorScheme.tertiaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'The committee says this is resolved. Is it '
                                'really fixed for you?',
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilledButton(
                                    onPressed: () => _changeStatus(
                                      ComplaintStatus.closed,
                                      title: 'Confirm it is resolved?',
                                    ),
                                    child: const Text('Yes, it is resolved'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _changeStatus(
                                      ComplaintStatus.inReview,
                                      title: 'Send back to the committee?',
                                    ),
                                    child: const Text('No, work on it again'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const Divider(height: 32),
                    Text('Conversation', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Live<List<ComplaintReply>>(
                      stream: backend.watchReplies(widget.complaintId),
                      builder: (context, replies) => replies.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No replies yet.'),
                            )
                          : Column(
                              children: [
                                for (final r in replies)
                                  _ReplyTile(
                                    reply: r,
                                    time: fmt.format(r.createdAt),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              if (canReply)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _reply,
                            decoration: InputDecoration(
                              hintText: Rbac.canHandleComplaints(me)
                                  ? 'Reply to the complainant'
                                  : 'Reply to the committee',
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Send reply',
                          icon: const Icon(Icons.send),
                          onPressed: _send,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({required this.reply, required this.time});

  final ComplaintReply reply;
  final String time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (reply.kind == 'status') {
      return ListTile(
        dense: true,
        leading: const Icon(Icons.flag_outlined),
        title: Text(reply.text),
        subtitle: Text('${reply.authorName} · $time'),
      );
    }
    return Card(
      color: reply.byCommittee
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      child: ListTile(
        title: Text(reply.text),
        subtitle: Text(
          '${reply.byCommittee ? 'Committee · ' : ''}${reply.authorName} · $time',
        ),
      ),
    );
  }
}

class _StatusDialog extends StatefulWidget {
  const _StatusDialog({required this.status, this.title});

  final ComplaintStatus status;
  final String? title;

  @override
  State<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends State<_StatusDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title ?? 'Mark as ${widget.status.chip}?'),
      content: TextField(
        controller: _note,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Note (optional)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
