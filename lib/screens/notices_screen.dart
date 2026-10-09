import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/campus.dart';
import '../services/backend.dart';
import '../utils/rbac.dart';
import '../widgets/audience_picker.dart';
import '../widgets/common.dart';
import '../widgets/image_picker_field.dart';
import '../widgets/link_text.dart';
import '../widgets/post_image.dart';

/// College-wide notices and announcements. Admin and admin staff post them.
class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key, required this.user});

  final AppUser user;

  Future<void> _post(BuildContext context) async {
    final backend = context.read<Backend>();
    final item = await showDialog<Notice>(
      context: context,
      builder: (_) => _PostNoticeDialog(user: user),
    );
    if (item != null) await backend.addNotice(item);
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final fmt = DateFormat('d MMM yyyy, h:mm a');
    return Scaffold(
      floatingActionButton: Rbac.canPostNotices(user)
          ? FloatingActionButton.extended(
              onPressed: () => _post(context),
              icon: const Icon(Icons.campaign),
              label: const Text('New notice'),
            )
          : null,
      body: Live<List<Notice>>(
        stream: backend.watchNotices(user),
        builder: (context, items) {
          if (items.isEmpty) {
            return const EmptyState(
              'No notices yet',
              icon: Icons.campaign_outlined,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final n = items[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (n.image != null && n.image!.isNotEmpty) ...[
                        PostImage(base64Image: n.image!),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (n.public)
                            const Tooltip(
                              message: 'Also shown on the opening page',
                              child: Icon(Icons.public, size: 18),
                            ),
                          if (Rbac.canPostNotices(user))
                            IconButton(
                              tooltip: 'Delete notice',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => backend.deleteNotice(n.id),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinkText(n.body),
                      const SizedBox(height: 8),
                      if (Rbac.canPostNotices(user))
                        Text(
                          'For: ${n.audience.describe()}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      Text(
                        '${n.authorName} · ${fmt.format(n.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
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

class _PostNoticeDialog extends StatefulWidget {
  const _PostNoticeDialog({required this.user});

  final AppUser user;

  @override
  State<_PostNoticeDialog> createState() => _PostNoticeDialogState();
}

class _PostNoticeDialogState extends State<_PostNoticeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String? _image;
  bool _public = false;
  Audience _audience = Audience.everyone;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New notice'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: requiredField,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _body,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Details'),
                validator: requiredField,
              ),
              const SizedBox(height: 8),
              AudiencePicker(
                value: _audience,
                onChanged: (a) => setState(() {
                  _audience = a;
                  // Only a notice for everybody can be public.
                  if (a.departments.isNotEmpty || a.groups.isNotEmpty) {
                    _public = false;
                  }
                }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show on the opening page'),
                subtitle: const Text(
                  'Visible to anyone, even before sign-in. Only for notices '
                  'to all branches and everyone.',
                ),
                value: _public,
                onChanged:
                    _audience.departments.isEmpty && _audience.groups.isEmpty
                    ? (v) => setState(() => _public = v)
                    : null,
              ),
              ImagePickerField(
                value: _image,
                label: 'Add poster / image',
                onChanged: (v) => setState(() => _image = v),
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
              Notice(
                id: '',
                title: _title.text.trim(),
                body: _body.text.trim(),
                authorName: widget.user.name,
                createdAt: DateTime.now(),
                image: _image,
                public: _public,
                audience: _audience,
              ),
            );
          },
          child: const Text('Publish'),
        ),
      ],
    );
  }
}
