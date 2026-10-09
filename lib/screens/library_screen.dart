import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_user.dart';
import '../models/book.dart';
import '../services/backend.dart';
import '../utils/rbac.dart';
import '../widgets/book_cover.dart';
import '../widgets/image_picker_field.dart';

/// The e-library.
///
/// Everybody reads approved books. Teachers' books wait for library staff to
/// verify them: teachers see their own uploads in a second tab, library staff
/// see a "To verify" queue, and admin staff / admin see everything pending.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _query = '';

  AppUser get _me => widget.user;

  void _toast(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _open(Book book) async {
    final uri = Uri.tryParse(book.url);
    var ok = false;
    try {
      ok =
          uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) _toast('Could not open ${book.title}');
  }

  Future<void> _add() async {
    final backend = context.read<Backend>();
    final form = await showDialog<Book>(
      context: context,
      builder: (_) => _BookFormDialog(teacherNotice: !Rbac.seesAllBooks(_me)),
    );
    if (form == null) return;
    try {
      await backend.addBook(
        Book(
          id: '',
          title: form.title,
          author: form.author,
          category: form.category,
          url: form.url,
          isbn: form.isbn,
          cover: form.cover,
          status: Rbac.initialBookStatus(_me),
          uploadedBy: _me.uid,
          uploadedByName: _me.name,
        ),
      );
      if (mounted) {
        _toast(
          Rbac.initialBookStatus(_me) == BookStatus.pending
              ? 'Sent to the library staff for verification'
              : 'Book added',
        );
      }
    } catch (e) {
      if (mounted) _toast('Could not add the book: $e');
    }
  }

  Future<void> _edit(Book book) async {
    final backend = context.read<Backend>();
    final resubmit =
        !Rbac.seesAllBooks(_me) && book.status != BookStatus.approved;
    final form = await showDialog<Book>(
      context: context,
      builder: (_) => _BookFormDialog(book: book, teacherNotice: resubmit),
    );
    if (form == null) return;
    try {
      await backend.updateBook(form, resubmit: resubmit);
      if (mounted) {
        _toast(resubmit ? 'Sent for verification again' : 'Book saved');
      }
    } catch (e) {
      if (mounted) _toast('Could not save: $e');
    }
  }

  Future<void> _delete(Book book) async {
    final backend = context.read<Backend>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${book.title}"?'),
        content: const Text('The book will be removed from the library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await backend.deleteBook(book.id);
    } catch (e) {
      if (mounted) _toast('Could not delete: $e');
    }
  }

  Future<void> _approve(Book book) async {
    final backend = context.read<Backend>();
    try {
      await backend.reviewBook(book.id, approve: true);
      if (mounted) _toast('"${book.title}" approved');
    } catch (e) {
      if (mounted) _toast('Could not approve: $e');
    }
  }

  Future<void> _reject(Book book) async {
    final backend = context.read<Backend>();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(title: book.title),
    );
    if (reason == null) return;
    try {
      await backend.reviewBook(book.id, approve: false, reason: reason);
      if (mounted) _toast('"${book.title}" rejected');
    } catch (e) {
      if (mounted) _toast('Could not reject: $e');
    }
  }

  Future<void> _approveLegacy() async {
    final backend = context.read<Backend>();
    try {
      final n = await backend.approveLegacyBooks();
      if (mounted) {
        _toast(
          n == 0 ? 'No old books needed approval' : '$n old books approved',
        );
      }
    } catch (e) {
      if (mounted) _toast('Could not update: $e');
    }
  }

  bool _matches(Book b) =>
      '${b.title} ${b.author} ${b.category}'.toLowerCase().contains(_query);

  Widget _statusLine(Book b) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (b.status) {
      BookStatus.pending => Colors.orange.shade800,
      BookStatus.approved => Colors.green.shade700,
      BookStatus.rejected => scheme.error,
    };
    final reason = b.status == BookStatus.rejected && b.rejectReason.isNotEmpty
        ? ' - ${b.rejectReason}'
        : '';
    return Text(
      '${b.status.label}$reason',
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }

  Widget _tile(Book b, {required bool showStatus}) {
    final canVerify =
        Rbac.canVerifyBooks(_me) && b.status == BookStatus.pending;
    return ListTile(
      key: ValueKey('book-${b.id}'),
      leading: BookCover(book: b),
      title: Text(b.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${b.author} · ${b.category}'
            '${showStatus && b.uploadedByName.isNotEmpty ? '\nAdded by ${b.uploadedByName}' : ''}',
          ),
          if (showStatus) _statusLine(b),
        ],
      ),
      isThreeLine: showStatus,
      onTap: () => _open(b),
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (canVerify) ...[
            IconButton(
              key: ValueKey('approve-${b.id}'),
              tooltip: 'Approve',
              color: Colors.green.shade700,
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () => _approve(b),
            ),
            IconButton(
              key: ValueKey('reject-${b.id}'),
              tooltip: 'Reject',
              color: Theme.of(context).colorScheme.error,
              icon: const Icon(Icons.cancel_outlined),
              onPressed: () => _reject(b),
            ),
          ],
          if (!showStatus || b.status == BookStatus.approved)
            IconButton(
              key: ValueKey('open-${b.id}'),
              tooltip: 'Read / download',
              icon: const Icon(Icons.download),
              onPressed: () => _open(b),
            ),
          if (Rbac.canEditBook(_me, b))
            IconButton(
              key: ValueKey('edit-${b.id}'),
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(b),
            ),
          if (Rbac.canDeleteBook(_me, b))
            IconButton(
              key: ValueKey('delete-${b.id}'),
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(b),
            ),
        ],
      ),
    );
  }

  Widget _list(List<Book> books, {required bool showStatus, String? empty}) {
    final shown = books.where(_matches).toList();
    if (shown.isEmpty) {
      return Center(child: Text(empty ?? 'No books found'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: shown.length,
      itemBuilder: (_, i) => _tile(shown[i], showStatus: showStatus),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final canManage = Rbac.canManageBooks(_me);
    return StreamBuilder<List<Book>>(
      stream: backend.watchBooks(_me),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Could not load books: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!;
        final approved = all
            .where((b) => b.status == BookStatus.approved)
            .toList();
        final bool twoTabs = Rbac.canSeeUnapprovedBooks(_me);

        // Second tab: what the viewer has to look at besides the library.
        late final String secondLabel;
        late final List<Book> second;
        late final String secondEmpty;
        if (_me.role == UserRole.teacher) {
          second = all.where((b) => b.uploadedBy == _me.uid).toList();
          final open = second
              .where((b) => b.status != BookStatus.approved)
              .length;
          secondLabel = open > 0 ? 'My uploads ($open)' : 'My uploads';
          secondEmpty = 'You have not added any books yet.';
        } else if (Rbac.canVerifyBooks(_me)) {
          second = all.where((b) => b.status == BookStatus.pending).toList();
          secondLabel = second.isEmpty
              ? 'To verify'
              : 'To verify (${second.length})';
          secondEmpty = 'No books are waiting for verification.';
        } else {
          second = all.where((b) => b.status != BookStatus.approved).toList();
          secondLabel = second.isEmpty
              ? 'Not approved'
              : 'Not approved (${second.length})';
          secondEmpty = 'No pending or rejected books.';
        }

        final body = Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search title, author or category',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) =>
                          setState(() => _query = v.toLowerCase()),
                    ),
                  ),
                  if (Rbac.seesAllBooks(_me))
                    PopupMenuButton<String>(
                      tooltip: 'More',
                      onSelected: (_) => _approveLegacy(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'legacy',
                          child: Text('Approve books added before this update'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (twoTabs)
              TabBar(
                tabs: [
                  const Tab(text: 'Library'),
                  Tab(text: secondLabel),
                ],
              ),
            Expanded(
              child: twoTabs
                  ? TabBarView(
                      children: [
                        _list(approved, showStatus: false),
                        _list(second, showStatus: true, empty: secondEmpty),
                      ],
                    )
                  : _list(approved, showStatus: false),
            ),
          ],
        );

        return DefaultTabController(
          length: twoTabs ? 2 : 1,
          child: Scaffold(
            floatingActionButton: canManage
                ? FloatingActionButton.extended(
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                    label: const Text('Add book'),
                  )
                : null,
            body: body,
          ),
        );
      },
    );
  }
}

class _BookFormDialog extends StatefulWidget {
  const _BookFormDialog({this.book, required this.teacherNotice});

  final Book? book;

  /// Teachers are told that library staff verify books first.
  final bool teacherNotice;

  @override
  State<_BookFormDialog> createState() => _BookFormDialogState();
}

class _BookFormDialogState extends State<_BookFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.book?.title ?? '');
  late final _author = TextEditingController(text: widget.book?.author ?? '');
  late final _category = TextEditingController(
    text: widget.book?.category ?? 'General',
  );
  late final _isbn = TextEditingController(text: widget.book?.isbn ?? '');
  late final _url = TextEditingController(text: widget.book?.url ?? '');
  late String? _cover = widget.book?.cover;

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _category.dispose();
    _isbn.dispose();
    _url.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.book == null ? 'Add book' : 'Edit book'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.teacherNotice)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Library staff will verify this book before students '
                    'can see it.',
                  ),
                ),
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
                controller: _isbn,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ISBN (optional)',
                  helperText: 'Used to fetch the cover automatically',
                ),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'[^0-9Xx]'), '');
                  if (digits.isEmpty) return null;
                  return (digits.length == 10 || digits.length == 13)
                      ? null
                      : 'An ISBN has 10 or 13 digits';
                },
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
              const SizedBox(height: 12),
              ImagePickerField(
                value: _cover,
                label: 'Add cover picture',
                aspectRatio: 1 / 1.4,
                onChanged: (v) => setState(() => _cover = v),
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
            final base =
                widget.book ??
                const Book(
                  id: '',
                  title: '',
                  author: '',
                  category: '',
                  url: '',
                );
            Navigator.pop(
              context,
              base.copyWith(
                title: _title.text.trim(),
                author: _author.text.trim(),
                category: _category.text.trim(),
                url: _url.text.trim(),
                isbn: _isbn.text.trim(),
                cover: _cover,
                clearCover: _cover == null,
              ),
            );
          },
          child: Text(widget.book == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.title});

  final String title;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reject "${widget.title}"?'),
      content: TextField(
        controller: _reason,
        maxLength: 200,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'Reason (the teacher will see this)',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final r = _reason.text.trim();
            if (r.isEmpty) {
              setState(() => _error = 'Please give a short reason');
              return;
            }
            Navigator.pop(context, r);
          },
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
