import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../services/auth_controller.dart';
import '../utils/rbac.dart';
import 'bus_screen.dart';
import 'chatbot_screen.dart';
import 'dashboard_screen.dart';
import 'library_screen.dart';
import 'news_screen.dart';
import 'people_screen.dart';
import 'class_reps_screen.dart';
import 'manage_users_screen.dart';

class _Destination {
  const _Destination(this.title, this.icon, this.builder, this.allowed);
  final String title;
  final IconData icon;
  final Widget Function(AppUser user) builder;
  final bool Function(AppUser user) allowed;
}

/// Main shell. The drawer is built from the user's role: entries the role
/// may not use are simply not shown (see [Rbac]).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selected = 0;

  static final _all = <_Destination>[
    _Destination(
      'Dashboard',
      Icons.dashboard,
      (u) => DashboardScreen(user: u),
      (_) => true,
    ),
    _Destination(
      'E-Library',
      Icons.local_library,
      (u) => LibraryScreen(user: u),
      Rbac.canUseLibrary,
    ),
    _Destination(
      'Bus Tracking',
      Icons.directions_bus,
      (u) => BusScreen(user: u),
      Rbac.canTrackBus,
    ),
    _Destination(
      'Chat',
      Icons.chat,
      (u) => PeopleScreen(user: u),
      Rbac.canChat,
    ),
    _Destination(
      'AI Chatbot',
      Icons.smart_toy,
      (_) => const ChatbotScreen(),
      Rbac.canUseChatbot,
    ),
    _Destination(
      'Tech News',
      Icons.newspaper,
      (u) => NewsScreen(user: u),
      Rbac.canReadNews,
    ),
    _Destination(
      'Class Representatives',
      Icons.how_to_reg,
      (u) => ClassRepsScreen(user: u),
      Rbac.canAssignClassReps,
    ),
    _Destination(
      'Manage Users',
      Icons.admin_panel_settings,
      (u) => ManageUsersScreen(user: u),
      Rbac.canManageUsers,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user!;
    final items = _all.where((d) => d.allowed(user)).toList();
    // A role change can shrink the list; keep the index valid.
    final index = _selected.clamp(0, items.length - 1);
    final current = items[index];

    return Scaffold(
      appBar: AppBar(title: Text(current.title)),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user.name),
              accountEmail: Text('${user.role.label} · ${user.department}'),
              currentAccountPicture: CircleAvatar(
                child: Text(
                  user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < items.length; i++)
                    ListTile(
                      leading: Icon(items[i].icon),
                      title: Text(items[i].title),
                      selected: i == index,
                      onTap: () {
                        setState(() => _selected = i);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () {
                Navigator.of(context).pop();
                auth.signOut();
              },
            ),
          ],
        ),
      ),
      body: current.builder(user),
    );
  }
}
