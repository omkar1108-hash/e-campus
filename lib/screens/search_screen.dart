import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/book.dart';
import '../models/campus.dart';
import '../models/news_item.dart';
import '../services/backend.dart';
import '../widgets/common.dart';

/// One search box across e-library books, department news and notices.
/// Tapping a result opens the matching section ([onOpen]).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.user, required this.onOpen});

  final AppUser user;
  final void Function(String destination) onOpen;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _subs = <StreamSubscription<Object?>>[];
  List<Book> _books = const [];
  List<NewsItem> _news = const [];
  List<Notice> _notices = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    final backend = context.read<Backend>();
    final u = widget.user;
    _subs.addAll([
      backend.watchBooks(u).listen((v) => setState(() => _books = v)),
      backend.watchNews(u.department).listen((v) => setState(() => _news = v)),
      backend.watchNotices(u).listen((v) => setState(() => _notices = v)),
    ]);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _controller.dispose();
    super.dispose();
  }

  bool _match(String text) => text.toLowerCase().contains(_query);

  @override
  Widget build(BuildContext context) {
    final searching = _query.length >= 2;
    final books = !searching
        ? const <Book>[]
        : _books
              .where(
                (b) => _match('${b.title} ${b.author} ${b.category} ${b.isbn}'),
              )
              .toList();
    final news = !searching
        ? const <NewsItem>[]
        : _news.where((n) => _match('${n.title} ${n.body}')).toList();
    final notices = !searching
        ? const <Notice>[]
        : _notices.where((n) => _match('${n.title} ${n.body}')).toList();
    final nothing = books.isEmpty && news.isEmpty && notices.isEmpty;

    Widget section(String title, List<Widget> tiles) => tiles.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              ...tiles,
            ],
          );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _controller,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Search books, news and notices',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: !searching
              ? const EmptyState(
                  'Type at least two letters to search',
                  icon: Icons.search,
                )
              : nothing
              ? EmptyState('Nothing found for "${_controller.text.trim()}"')
              : ListView(
                  children: [
                    section('Books', [
                      for (final b in books)
                        ListTile(
                          leading: const Icon(Icons.menu_book),
                          title: Text(b.title),
                          subtitle: Text('${b.author} · ${b.category}'),
                          onTap: () => widget.onOpen('E-Library'),
                        ),
                    ]),
                    section('Tech news', [
                      for (final n in news)
                        ListTile(
                          leading: const Icon(Icons.newspaper),
                          title: Text(n.title),
                          subtitle: Text(
                            n.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => widget.onOpen('Tech News'),
                        ),
                    ]),
                    section('Notices', [
                      for (final n in notices)
                        ListTile(
                          leading: const Icon(Icons.campaign),
                          title: Text(n.title),
                          subtitle: Text(
                            n.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => widget.onOpen('Notices'),
                        ),
                    ]),
                  ],
                ),
        ),
      ],
    );
  }
}
