import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../utils/rbac.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final abilities = <(IconData, String)>[
      (Icons.local_library, 'Read and download books from the e-library'),
      (Icons.directions_bus, 'Track the college bus in real time'),
      (Icons.chat, 'Chat with teachers and friends'),
      (Icons.smart_toy, 'Clear doubts with the AI chatbot'),
      (Icons.newspaper, 'Read tech news for ${user.department}'),
      if (Rbac.canPostNews(user))
        (Icons.edit_note, 'Post tech news for your department'),
      if (Rbac.canManageBooks(user))
        (Icons.library_add, 'Add and remove e-library books'),
      if (Rbac.canShareBusLocation(user))
        (Icons.share_location, 'Publish the live bus location'),
      if (Rbac.canManageUsers(user))
        (Icons.admin_panel_settings, 'Manage user roles'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Welcome, ${user.name}', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('${user.role.label} · ${user.department} · ${user.phone}'),
        const SizedBox(height: 24),
        Text('What you can do', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final a in abilities)
          Card(
            child: ListTile(leading: Icon(a.$1), title: Text(a.$2)),
          ),
      ],
    );
  }
}
