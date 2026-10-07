import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../services/backend.dart';

/// Admin-only: assign roles to registered users.
class UsersAdminScreen extends StatelessWidget {
  const UsersAdminScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return StreamBuilder<List<AppUser>>(
      stream: backend.watchUsers(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snap.data!;
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, i) {
            final u = users[i];
            final isSelf = u.uid == user.uid;
            return ListTile(
              leading: CircleAvatar(
                child: Text(u.name.isEmpty ? '?' : u.name[0]),
              ),
              title: Text(u.name),
              subtitle: Text('${u.email} · ${u.department}'),
              trailing: DropdownButton<UserRole>(
                value: u.role,
                // An admin cannot demote themselves and lock everyone out.
                onChanged: isSelf
                    ? null
                    : (r) {
                        if (r != null) backend.setUserRole(u.uid, r);
                      },
                items: [
                  for (final r in UserRole.values)
                    DropdownMenuItem(value: r, child: Text(r.label)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
