import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/news_item.dart';
import '../services/backend.dart';
import '../utils/rbac.dart';
import '../widgets/image_picker_field.dart';
import '../widgets/link_text.dart';
import '../widgets/post_image.dart';

/// Tech news for the user's department. Class representatives (and teachers /
/// admins) post items; every student in that department sees them.
class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key, required this.user});

  final AppUser user;

  Future<void> _post(BuildContext context) async {
    final backend = context.read<Backend>();
    final item = await showDialog<NewsItem>(
      context: context,
      builder: (_) => _PostNewsDialog(user: user),
    );
    if (item != null) await backend.addNews(item);
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final fmt = DateFormat('d MMM yyyy, h:mm a');
    return Scaffold(
      floatingActionButton: Rbac.canPostNews(user)
          ? FloatingActionButton.extended(
              onPressed: () => _post(context),
              icon: const Icon(Icons.add),
              label: const Text('Post news'),
            )
          : null,
      body: StreamBuilder<List<NewsItem>>(
        stream: backend.watchNews(user.department),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return Center(child: Text('No news for ${user.department} yet'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
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
                          if (Rbac.canPostNews(user) &&
                              Rbac.canDeleteNews(user, n.department))
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => backend.deleteNews(n.id),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinkText(n.body),
                      const SizedBox(height: 8),
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

class _PostNewsDialog extends StatefulWidget {
  const _PostNewsDialog({required this.user});

  final AppUser user;

  @override
  State<_PostNewsDialog> createState() => _PostNewsDialogState();
}

class _PostNewsDialogState extends State<_PostNewsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String? _image;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Post news for ${widget.user.department}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Headline'),
                validator: _required,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _body,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Details'),
                validator: _required,
              ),
              const SizedBox(height: 12),
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
              NewsItem(
                id: '',
                title: _title.text.trim(),
                body: _body.text.trim(),
                department: widget.user.department,
                authorName: widget.user.name,
                createdAt: DateTime.now(),
                image: _image,
              ),
            );
          },
          child: const Text('Post'),
        ),
      ],
    );
  }
}
