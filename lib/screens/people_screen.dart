import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../services/backend.dart';
import '../services/inbox_controller.dart';
import '../utils/chat_policy.dart';
import 'chat_screen.dart';

/// People you may chat with, newest conversation first. Unread chats are
/// bold with a dot. Filter by department with the chips.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  String _query = '';
  String? _department; // null = all

  String _time(DateTime t) {
    final now = DateTime.now();
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay ? DateFormat.jm().format(t) : DateFormat('d MMM').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final inbox = context.watch<InboxController>();
    final me = widget.user;
    return StreamBuilder<List<AppUser>>(
      stream: backend.watchUsers(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allowed = snap.data!
            .where((u) => ChatPolicy.canChat(me, u))
            .toList();
        final departments = {
          ...AppConfig.departments,
          ...allowed.map((u) => u.department),
        }.where((d) => d.isNotEmpty).toList();
        final people =
            allowed
                .where(
                  (u) =>
                      (_department == null || u.department == _department) &&
                      '${u.name} ${u.department} ${u.role.label}'
                          .toLowerCase()
                          .contains(_query),
                )
                .toList()
              ..sort((a, b) {
                final ca = inbox.chats[chatIdFor(me.uid, a.uid)];
                final cb = inbox.chats[chatIdFor(me.uid, b.uid)];
                if (ca != null && cb != null) {
                  return cb.lastMessageAt.compareTo(ca.lastMessageAt);
                }
                if (ca != null) return -1;
                if (cb != null) return 1;
                return a.name.compareTo(b.name);
              });
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search people',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All departments'),
                      selected: _department == null,
                      onSelected: (_) => setState(() => _department = null),
                    ),
                  ),
                  for (final d in departments)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(d),
                        selected: _department == d,
                        onSelected: (_) => setState(() => _department = d),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: people.isEmpty
                  ? const Center(child: Text('No one to chat with'))
                  : ListView.builder(
                      itemCount: people.length,
                      itemBuilder: (context, i) {
                        final p = people[i];
                        final chatId = chatIdFor(me.uid, p.uid);
                        final last = inbox.chats[chatId];
                        final unread = inbox.isUnread(chatId);
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(p.name.isEmpty ? '?' : p.name[0]),
                          ),
                          title: Text(
                            p.name,
                            style: unread
                                ? const TextStyle(fontWeight: FontWeight.bold)
                                : null,
                          ),
                          subtitle: Text(
                            last == null
                                ? '${p.role.label} · ${p.department}'
                                : '${last.lastSenderId == me.uid ? 'You: ' : ''}'
                                      '${last.lastText}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: unread
                                ? const TextStyle(fontWeight: FontWeight.bold)
                                : null,
                          ),
                          trailing: last == null
                              ? null
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _time(last.lastMessageAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                    if (unread)
                                      Container(
                                        key: ValueKey('unread-${p.uid}'),
                                        margin: const EdgeInsets.only(top: 6),
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChatScreen(me: me, other: p, inbox: inbox),
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
