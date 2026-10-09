import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/campus.dart';
import '../services/auth_controller.dart';
import '../services/backend.dart';
import '../services/inbox_controller.dart';
import '../services/trip_controller.dart';
import '../utils/rbac.dart';
import 'activity_log_screen.dart';
import 'alert_screen.dart';
import 'assignments_screen.dart';
import 'attendance_screen.dart';
import 'bus_screen.dart';
import 'chatbot_screen.dart';
import 'complaints_screen.dart';
import 'dashboard_screen.dart';
import 'library_screen.dart';
import 'news_screen.dart';
import 'notices_screen.dart';
import 'search_screen.dart';
import 'timetable_screen.dart';
import 'people_screen.dart';
import 'chat_screen.dart';
import 'class_reps_screen.dart';
import 'manage_buses_screen.dart';
import 'manage_users_screen.dart';

class _Destination {
  const _Destination(this.title, this.icon, this.builder, this.allowed);
  final String title;
  final IconData icon;
  final Widget Function(AppUser user, void Function(String) go) builder;
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
  late final InboxController _inbox;
  StreamSubscription<IncomingMessage>? _incomingSub;
  Timer? _bannerTimer;
  DateTime? _lastBack;
  StreamSubscription<List<EmergencyAlert>>? _alertSub;
  List<EmergencyAlert> _alerts = const [];

  /// Alerts already announced with a pop-up on this device.
  late final Future<Set<String>> _seenAlerts = _loadSeenAlerts();
  static const _seenKey = 'seen_alert_ids';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _inbox = InboxController(context.read<Backend>(), auth.user!);
    _incomingSub = _inbox.incoming.listen(_showBanner);
    _alertSub = context.read<Backend>().watchActiveAlerts().listen(
      _onAlerts,
      onError: (_) {},
    );
  }

  Future<Set<String>> _loadSeenAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_seenKey) ?? const []).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// The red banner stays while an alert is active; each alert also pops up
  /// once per device.
  Future<void> _onAlerts(List<EmergencyAlert> alerts) async {
    if (!mounted) return;
    setState(() => _alerts = alerts);
    final seen = await _seenAlerts;
    final fresh = alerts.where((a) => !seen.contains(a.id)).toList();
    if (fresh.isEmpty || !mounted) return;
    seen.addAll(fresh.map((a) => a.id));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_seenKey, seen.toList());
    } catch (_) {}
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('alert-dialog'),
        icon: const Icon(Icons.warning_amber, color: Colors.red, size: 40),
        title: const Text('Emergency alert'),
        content: Text(fresh.map((a) => a.message).join('\n\n')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hideBanner();
    _incomingSub?.cancel();
    _alertSub?.cancel();
    _inbox.dispose();
    super.dispose();
  }

  /// [immediate] skips the slide-out animation (used before opening a chat,
  /// because a banner animating while a new screen appears overflows).
  OverlayEntry? _bannerEntry;

  void _hideBanner() {
    _bannerTimer?.cancel();
    _bannerEntry?.remove();
    _bannerEntry = null;
  }

  /// A banner at the very top, above whichever screen is open, whenever a
  /// message arrives while the app is running.
  void _showBanner(IncomingMessage m) {
    if (!mounted) return;
    _hideBanner();
    final entry = OverlayEntry(
      builder: (_) => _MessageBanner(
        message: m,
        onDismiss: _hideBanner,
        onOpen: () {
          _hideBanner();
          _openChat(m);
        },
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    _bannerEntry = entry;
    _bannerTimer = Timer(const Duration(seconds: 6), _hideBanner);
  }

  void _openChat(IncomingMessage m) {
    final other = _inbox.users[m.senderId];
    if (other == null) return;
    final items = _all.where((d) => d.allowed(_inbox.me)).toList();
    final chatIndex = items.indexWhere((d) => d.title == 'Chat');
    if (chatIndex >= 0) setState(() => _selected = chatIndex);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(me: _inbox.me, other: other, inbox: _inbox),
      ),
    );
  }

  static final _all = <_Destination>[
    _Destination(
      'Dashboard',
      Icons.dashboard,
      (u, go) => DashboardScreen(user: u, onOpen: go),
      (_) => true,
    ),
    _Destination(
      'Search',
      Icons.search,
      (u, go) => SearchScreen(user: u, onOpen: go),
      Rbac.canSearch,
    ),
    _Destination(
      'Notices',
      Icons.campaign,
      (u, _) => NoticesScreen(user: u),
      Rbac.canReadNotices,
    ),
    _Destination(
      'Timetable',
      Icons.calendar_month,
      (u, _) => TimetableScreen(user: u),
      Rbac.canViewTimetable,
    ),
    _Destination(
      'Attendance',
      Icons.fact_check,
      (u, _) => AttendanceScreen(user: u),
      (u) => Rbac.canMarkAttendance(u) || Rbac.canViewOwnAttendance(u),
    ),
    _Destination(
      'Assignments',
      Icons.assignment,
      (u, _) => AssignmentsScreen(user: u),
      Rbac.canViewAssignments,
    ),
    _Destination(
      'E-Library',
      Icons.local_library,
      (u, _) => LibraryScreen(user: u),
      Rbac.canUseLibrary,
    ),
    _Destination(
      'Bus Tracking',
      Icons.directions_bus,
      (u, _) => BusScreen(user: u),
      Rbac.canTrackBus,
    ),
    _Destination(
      'Chat',
      Icons.chat,
      (u, _) => PeopleScreen(user: u),
      Rbac.canChat,
    ),
    _Destination(
      'AI Chatbot',
      Icons.smart_toy,
      (u, _) => const ChatbotScreen(),
      Rbac.canUseChatbot,
    ),
    _Destination(
      'Tech News',
      Icons.newspaper,
      (u, _) => NewsScreen(user: u),
      Rbac.canReadNews,
    ),
    _Destination(
      'Complaints',
      Icons.report_problem,
      (u, _) => ComplaintsScreen(user: u),
      (u) => Rbac.canFileComplaint(u) || Rbac.canViewAllComplaints(u),
    ),
    _Destination(
      'Class Representatives',
      Icons.how_to_reg,
      (u, _) => ClassRepsScreen(user: u),
      Rbac.canAssignClassReps,
    ),
    _Destination(
      'Manage Buses',
      Icons.directions_bus_filled,
      (u, _) => ManageBusesScreen(user: u),
      Rbac.canManageBuses,
    ),
    _Destination(
      'Manage Users',
      Icons.admin_panel_settings,
      (u, _) => ManageUsersScreen(user: u),
      Rbac.canManageUsers,
    ),
    _Destination(
      'Activity Log',
      Icons.history,
      (u, _) => const ActivityLogScreen(),
      Rbac.canViewActivityLog,
    ),
    _Destination(
      'Emergency Alert',
      Icons.warning_amber,
      (u, _) => const AlertScreen(),
      Rbac.canSendAlert,
    ),
  ];

  /// Opens a drawer entry by its title (used by dashboard cards and search).
  void _go(String title) {
    final user = context.read<AuthController>().user;
    if (user == null) return;
    final items = _all.where((d) => d.allowed(user)).toList();
    final i = items.indexWhere((d) => d.title == title);
    if (i >= 0) setState(() => _selected = i);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user!;
    final items = _all.where((d) => d.allowed(user)).toList();
    // A role change can shrink the list; keep the index valid.
    final index = _selected.clamp(0, items.length - 1);
    final current = items[index];

    // Back from any section returns to the dashboard; back on the
    // dashboard needs a second press within 2 seconds to leave the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (index != 0) {
          setState(() => _selected = 0);
          return;
        }
        final now = DateTime.now();
        final last = _lastBack;
        if (last != null && now.difference(last) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBack = now;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
      },
      child: ChangeNotifierProvider<InboxController>.value(
        value: _inbox,
        child: Consumer<InboxController>(
          builder: (context, inbox, _) => _buildScaffold(
            context,
            auth,
            user,
            items,
            index,
            current,
            inbox.unreadCount,
          ),
        ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    AuthController auth,
    AppUser user,
    List<_Destination> items,
    int index,
    _Destination current,
    int unread,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(current.title),
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Open navigation menu',
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.menu),
            ),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
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
                      trailing: items[i].title == 'Chat' && unread > 0
                          ? Badge.count(count: unread)
                          : null,
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
              onTap: () async {
                final trips = context.read<TripController>();
                Navigator.of(context).pop();
                // Never leave a bus trip running after the driver signs out.
                await trips.stopIfRunning();
                await auth.signOut();
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          for (final a in _alerts) _AlertBanner(alert: a),
          Expanded(child: current.builder(user, _go)),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.alert});

  final EmergencyAlert alert;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('alert-banner'),
      color: Colors.red.shade700,
      child: ListTile(
        dense: true,
        textColor: Colors.white,
        iconColor: Colors.white,
        leading: const Icon(Icons.warning_amber),
        title: Text(
          alert.message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Emergency alert from ${alert.authorName}',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.message,
    required this.onOpen,
    required this.onDismiss,
  });

  final IncomingMessage message;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: -1, end: 0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          builder: (context, v, child) =>
              FractionalTranslation(translation: Offset(0, v), child: child),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Material(
                key: const ValueKey('message-banner'),
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.inverseSurface,
                child: ListTile(
                  textColor: Theme.of(context).colorScheme.onInverseSurface,
                  iconColor: Theme.of(context).colorScheme.onInverseSurface,
                  leading: const Icon(Icons.chat),
                  title: Text(message.senderName),
                  subtitle: Text(
                    message.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: onOpen,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(onPressed: onOpen, child: const Text('Open')),
                      IconButton(
                        tooltip: 'Dismiss',
                        icon: const Icon(Icons.close),
                        onPressed: onDismiss,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
