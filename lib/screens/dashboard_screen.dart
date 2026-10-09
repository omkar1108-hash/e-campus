import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/book.dart';
import '../models/bus.dart';
import '../models/campus.dart';
import '../models/news_item.dart';
import '../services/backend.dart';
import '../services/inbox_controller.dart';
import '../utils/rbac.dart';
import '../widgets/role_badge.dart';

/// A live summary of what matters to this role right now. Every card opens
/// the matching section ([onOpen] takes the drawer title).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.user, required this.onOpen});

  final AppUser user;
  final void Function(String destination) onOpen;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final inbox = context.watch<InboxController>();
    final u = user;
    final theme = Theme.of(context);

    Stream<List<TimetableSlot>> todaysClasses() =>
        backend.watchTimetables(u).map((all) {
          final day = weekDayName(DateTime.now());
          final mine = Rbac.isStudent(u)
              ? all[u.department] ?? const <TimetableSlot>[]
              : [for (final l in all.values) ...l];
          return mine
              .where(
                (s) =>
                    s.day == day &&
                    (Rbac.isStudent(u) || s.teacherUid == u.uid),
              )
              .toList();
        });

    final cards = <Widget>[
      _StatCard<int>(
        icon: Icons.chat,
        title: 'Messages',
        stream: () => const Stream<int>.empty(),
        initial: inbox.unreadCount,
        map: (n) => (
          n == 0 ? 'All read' : '$n unread',
          n == 0 ? 'No new messages' : 'Tap to open your chats',
        ),
        onTap: () => onOpen('Chat'),
      ),
      if (Rbac.canReadNotices(u))
        _StatCard<List<Notice>>(
          icon: Icons.campaign,
          title: 'Notices',
          stream: () => backend.watchNotices(u),
          map: (l) => l.isEmpty
              ? ('None', 'No notices yet')
              : ('${l.length}', 'Latest: ${l.first.title}'),
          onTap: () => onOpen('Notices'),
        ),
      if (Rbac.isStudent(u) || u.role.isTeaching)
        _StatCard<List<TimetableSlot>>(
          icon: Icons.schedule,
          title: "Today's classes",
          stream: () => todaysClasses(),
          map: (l) => l.isEmpty
              ? ('None', 'No classes today')
              : (
                  '${l.length}',
                  'First: ${(l..sort((a, b) => a.order.compareTo(b.order))).first.subject} at ${l.first.start}',
                ),
          onTap: () => onOpen('Timetable'),
        ),
      if (Rbac.isStudent(u))
        _StatCard<List<AttendanceRecord>>(
          icon: Icons.fact_check,
          title: 'Attendance',
          stream: () => backend.watchMyAttendance(u.uid),
          map: (l) => l.isEmpty
              ? ('—', 'Nothing marked yet')
              : (
                  '${overallAttendance(l).toStringAsFixed(0)}%',
                  overallAttendance(l) < attendanceTarget
                      ? 'Below ${attendanceTarget.toStringAsFixed(0)}% - attend more'
                      : 'Keep it up',
                ),
          warn: (l) => l.isNotEmpty && overallAttendance(l) < attendanceTarget,
          onTap: () => onOpen('Attendance'),
        ),
      if (Rbac.canViewAssignments(u))
        _StatCard<List<Assignment>>(
          icon: Icons.assignment,
          title: Rbac.isStudent(u) ? 'Assignments due' : 'Shared by you',
          stream: () => backend.watchAssignments(u),
          map: (l) {
            if (!Rbac.isStudent(u)) {
              return ('${l.length}', 'assignments and notes');
            }
            final due =
                l
                    .where(
                      (a) =>
                          a.kind == WorkKind.assignment &&
                          a.dueDate != null &&
                          a.dueDate!.isAfter(DateTime.now()),
                    )
                    .toList()
                  ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
            return due.isEmpty
                ? ('None', 'Nothing due')
                : ('${due.length}', 'Next: ${due.first.title}');
          },
          onTap: () => onOpen('Assignments'),
        ),
      if (u.role.isTeaching)
        _StatCard<List<AttendanceRecord>>(
          icon: Icons.fact_check,
          title: 'Attendance marked',
          stream: () => backend.watchMarkedAttendance(u.uid),
          map: (l) {
            final lectures = {
              for (final r in l) '${r.date}|${r.department}|${r.subject}',
            };
            return ('${lectures.length}', 'lectures recorded');
          },
          onTap: () => onOpen('Attendance'),
        ),
      if (Rbac.canUseLibrary(u))
        _StatCard<List<Book>>(
          icon: Icons.local_library,
          title: Rbac.canVerifyBooks(u)
              ? 'Books to verify'
              : u.role.isTeaching
              ? 'My books'
              : 'E-Library',
          stream: () => backend.watchBooks(u),
          map: (l) {
            if (Rbac.canVerifyBooks(u)) {
              final n = l.where((b) => b.status == BookStatus.pending).length;
              return (
                '$n',
                n == 0 ? 'Nothing waiting' : 'waiting for approval',
              );
            }
            if (u.role.isTeaching) {
              final mine = l.where((b) => b.uploadedBy == u.uid).toList();
              final pending = mine
                  .where((b) => b.status == BookStatus.pending)
                  .length;
              final rejected = mine
                  .where((b) => b.status == BookStatus.rejected)
                  .length;
              return ('${mine.length}', '$pending pending, $rejected rejected');
            }
            return ('${l.length}', 'books available');
          },
          onTap: () => onOpen('E-Library'),
        ),
      if (Rbac.canReadNews(u))
        _StatCard<List<NewsItem>>(
          icon: Icons.newspaper,
          title: 'Tech news',
          stream: () => backend.watchNews(u.department),
          map: (l) => l.isEmpty
              ? ('None', 'Nothing for ${u.department} yet')
              : ('${l.length}', l.first.title),
          onTap: () => onOpen('Tech News'),
        ),
      _StatCard<List<Bus>>(
        icon: Icons.directions_bus,
        title: Rbac.canShareBusLocation(u) ? 'Your bus' : 'Bus tracking',
        stream: () => backend.watchBuses(u),
        map: (l) {
          if (l.isEmpty) return ('—', 'No bus assigned');
          final now = DateTime.now();
          final live = l.where((b) => b.isLive(now)).toList();
          if (Rbac.canShareBusLocation(u)) {
            return (
              live.isEmpty ? 'Not running' : 'Trip running',
              live.isEmpty ? 'Open to start your trip' : l.first.name,
            );
          }
          return (
            live.isEmpty ? 'None live' : '${live.length} live',
            live.isEmpty ? '${l.length} bus(es) not running' : live.first.name,
          );
        },
        onTap: () => onOpen('Bus Tracking'),
      ),
      if (Rbac.canManageUsers(u))
        _StatCard<List<AppUser>>(
          icon: Icons.admin_panel_settings,
          title: 'Accounts',
          stream: () => backend.watchUsers(),
          map: (l) => (
            '${l.where((x) => x.active).length}',
            '${l.where((x) => !x.active).length} disabled',
          ),
          onTap: () => onOpen('Manage Users'),
        ),
      if (Rbac.canAssignClassReps(u))
        _StatCard<List<AppUser>>(
          icon: Icons.how_to_reg,
          title: 'Class representatives',
          stream: () => backend.watchUsers(),
          map: (l) {
            final n = l
                .where(
                  (x) =>
                      x.role == UserRole.classRep &&
                      x.department == u.department,
                )
                .length;
            return ('$n / 4', 'in ${u.department}');
          },
          onTap: () => onOpen('Class Representatives'),
        ),
      if (Rbac.canViewAllComplaints(u))
        _StatCard<List<Complaint>>(
          icon: Icons.report_problem,
          title: 'Complaints',
          stream: () => backend.watchAllComplaints(),
          map: (l) {
            final fresh = l
                .where((c) => c.status == ComplaintStatus.submitted)
                .length;
            final review = l
                .where((c) => c.status == ComplaintStatus.inReview)
                .length;
            return ('$fresh new', '$review in review, ${l.length} total');
          },
          warn: (l) => l.any((c) => c.status == ComplaintStatus.submitted),
          onTap: () => onOpen('Complaints'),
        ),
      if (Rbac.canViewActivityLog(u))
        _StatCard<List<ActivityEntry>>(
          icon: Icons.history,
          title: 'Activity log',
          stream: () => backend.watchActivity(),
          map: (l) => l.isEmpty
              ? ('Empty', 'No actions recorded')
              : ('${l.length}', l.first.sentence),
          onTap: () => onOpen('Activity Log'),
        ),
    ];

    final actions = <(IconData, String)>[
      if (Rbac.canSearch(u)) (Icons.search, 'Search'),
      if (Rbac.canPostNews(u)) (Icons.edit_note, 'Tech News'),
      if (Rbac.canPostNotices(u)) (Icons.campaign, 'Notices'),
      if (Rbac.canEditTimetable(u)) (Icons.edit_calendar, 'Timetable'),
      if (Rbac.canMarkAttendance(u)) (Icons.fact_check, 'Attendance'),
      if (Rbac.canPostAssignments(u)) (Icons.assignment_add, 'Assignments'),
      if (Rbac.canManageBooks(u)) (Icons.library_add, 'E-Library'),
      if (Rbac.canManageBuses(u)) (Icons.directions_bus_filled, 'Manage Buses'),
      if (Rbac.canSendAlert(u)) (Icons.warning_amber, 'Emergency Alert'),
      if (Rbac.canFileComplaint(u)) (Icons.report_outlined, 'Complaints'),
      if (Rbac.canUseChatbot(u)) (Icons.smart_toy, 'AI Chatbot'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Welcome, ${u.name}', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [RoleBadge(u.role), Text('${u.department} · ${u.email}')],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 520 ? 2 : 1);
            final width = (c.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final card in cards) SizedBox(width: width, child: card),
              ],
            );
          },
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Quick actions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in actions)
                ActionChip(
                  avatar: Icon(a.$1, size: 18),
                  label: Text(a.$2),
                  onPressed: () => onOpen(a.$2),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One live tile: shows "…" until the first value arrives. The stream is
/// created once, so rebuilding the dashboard does not resubscribe.
class _StatCard<T> extends StatefulWidget {
  _StatCard({
    required this.icon,
    required this.title,
    required this.stream,
    required this.map,
    required this.onTap,
    this.warn,
    this.initial,
  }) : super(key: ValueKey(title));

  final IconData icon;
  final String title;
  final Stream<T> Function() stream;
  final T? initial;
  final (String, String) Function(T data) map;
  final bool Function(T data)? warn;
  final VoidCallback onTap;

  @override
  State<_StatCard<T>> createState() => _StatCardState<T>();
}

class _StatCardState<T> extends State<_StatCard<T>> {
  late final Stream<T> _stream = widget.stream();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<T>(
      stream: _stream,
      initialData: widget.initial,
      builder: (context, snap) {
        final data = widget.initial ?? snap.data;
        final (value, sub) = data == null
            ? (snap.hasError ? 'n/a' : '…', snap.hasError ? 'Unavailable' : '')
            : widget.map(data);
        final warning = data != null && (widget.warn?.call(data) ?? false);
        return Card(
          color: warning ? theme.colorScheme.errorContainer : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(widget.icon, size: 32, color: theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: theme.textTheme.labelLarge),
                        Text(value, style: theme.textTheme.headlineSmall),
                        if (sub.isNotEmpty)
                          Text(
                            sub,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
