import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_user.dart';
import '../models/book.dart';
import '../services/backend.dart';
import '../utils/rbac.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _query = '';

  Future<void> _open(Book book) async {
    final uri = Uri.tryParse(book.url);
    final ok =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open ${book.title}')));
    }
  }

  Future<void> _addBook() async {
    final backend = context.read<Backend>();
    final book = await showDialog<Book>(
      context: context,
      builder: (_) => const _AddBookDialog(),
    );
    if (book != null) await backend.addBook(book);
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final canManage = Rbac.canManageBooks(widget.user);
    return Scaffold(
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _addBook,
              icon: const Icon(Icons.add),
              label: const Text('Add book'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search title, author or category',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Book>>(
              stream: backend.watchBooks(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final books = snap.data!
                    .where(
                      (b) => '${b.title} ${b.author} ${b.category}'
                          .toLowerCase()
                          .contains(_query),
                    )
                    .toList();
                if (books.isEmpty) {
                  return const Center(child: Text('No books found'));
                }
                return ListView.builder(
                  itemCount: books.length,
                  itemBuilder: (context, i) {
                    final b = books[i];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.menu_book)),
                      title: Text(b.title),
                      subtitle: Text('${b.author} · ${b.category}'),
                      onTap: () => _open(b),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Read / download',
                            icon: const Icon(Icons.download),
                            onPressed: () => _open(b),
                          ),
                          if (canManage)
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => backend.deleteBook(b.id),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AddBookDialog extends StatefulWidget {
  const _AddBookDialog();

  @override
  State<_AddBookDialog> createState() => _AddBookDialogState();
}

class _AddBookDialogState extends State<_AddBookDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _category = TextEditingController(text: 'General');
  final _url = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _category.dispose();
    _url.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add book'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: _required,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _author,
                decoration: const InputDecoration(labelText: 'Author'),
                validator: _required,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: _required,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Link (PDF/URL)'),
                validator: (v) {
                  final uri = Uri.tryParse(v?.trim() ?? '');
                  return (uri != null && uri.hasScheme && uri.host.isNotEmpty)
                      ? null
                      : 'Enter a full http(s) link';
                },
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
              Book(
                id: '',
                title: _title.text.trim(),
                author: _author.text.trim(),
                category: _category.text.trim(),
                url: _url.text.trim(),
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
