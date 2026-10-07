import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../services/backend.dart';
import 'chat_screen.dart';

/// Directory of everyone you can chat with (teachers, friends, ...).
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search people',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AppUser>>(
            stream: backend.watchUsers(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final people = snap.data!
                  .where(
                    (u) =>
                        u.uid != widget.user.uid &&
                        '${u.name} ${u.department} ${u.role.label}'
                            .toLowerCase()
                            .contains(_query),
                  )
                  .toList();
              if (people.isEmpty) {
                return const Center(child: Text('No one to chat with yet'));
              }
              return ListView.builder(
                itemCount: people.length,
                itemBuilder: (context, i) {
                  final p = people[i];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(p.name.isEmpty ? '?' : p.name[0]),
                    ),
                    title: Text(p.name),
                    subtitle: Text('${p.role.label} · ${p.department}'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(me: widget.user, other: p),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
