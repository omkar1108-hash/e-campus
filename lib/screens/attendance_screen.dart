import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../models/campus.dart';
import '../services/backend.dart';
import '../utils/rbac.dart';
import '../widgets/common.dart';

/// Teachers mark attendance; students see their percentage per subject.
class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    if (Rbac.canMarkAttendance(user)) return _TeacherView(user: user);
    return _StudentView(user: user);
  }
}

// ---- Student --------------------------------------------------------------
class _StudentView extends StatelessWidget {
  const _StudentView({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return Live<List<AttendanceRecord>>(
      stream: backend.watchMyAttendance(user.uid),
      builder: (context, records) {
        if (records.isEmpty) {
          return const EmptyState(
            'No attendance has been marked for you yet',
            icon: Icons.fact_check_outlined,
          );
        }
        final overall = overallAttendance(records);
        final subjects = summarizeAttendance(records);
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: overall < attendanceTarget
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Overall attendance',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '${overall.toStringAsFixed(0)}%',
                      key: const ValueKey('overall-attendance'),
                      style: theme.textTheme.displayMedium,
                    ),
                    if (overall < attendanceTarget)
                      Text(
                        'Below the ${attendanceTarget.toStringAsFixed(0)}% '
                        'minimum - attend more lectures.',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final s in subjects)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.subject,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            '${s.percent.toStringAsFixed(0)}%',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: s.percent < attendanceTarget
                                  ? theme.colorScheme.error
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: s.percent / 100),
                      const SizedBox(height: 4),
                      Text('${s.present} of ${s.total} lectures attended'),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---- Teacher --------------------------------------------------------------
class _TeacherView extends StatelessWidget {
  const _TeacherView({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Mark attendance'),
              Tab(text: 'History'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _MarkTab(user: user),
                _HistoryTab(user: user),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkTab extends StatefulWidget {
  const _MarkTab({required this.user});

  final AppUser user;

  @override
  State<_MarkTab> createState() => _MarkTabState();
}

class _MarkTabState extends State<_MarkTab> {
  final _subject = TextEditingController();
  late String _department = widget.user.department;
  DateTime _date = DateTime.now();
  final Map<String, bool> _present = {};
  String _loadedKey = '';
  bool _saving = false;

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 120)),
      lastDate: now,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save(List<AppUser> students) async {
    final subject = _subject.text.trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter the subject first')));
      return;
    }
    final backend = context.read<Backend>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await backend.saveAttendance([
        for (final s in students)
          AttendanceRecord(
            studentUid: s.uid,
            studentName: s.name,
            department: _department,
            subject: subject,
            date: AttendanceRecord.dateKey(_date),
            present: _present[s.uid] ?? true,
            teacherUid: widget.user.uid,
          ),
      ]);
      final absent = students.where((s) => _present[s.uid] == false).length;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Attendance saved: ${students.length - absent} present, '
            '$absent absent',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final departments = {
      ...AppConfig.departments,
      widget.user.department,
    }.where((d) => d.isNotEmpty).toList();
    return Live<List<AppUser>>(
      stream: backend.watchUsers(),
      builder: (context, users) {
        final students =
            users
                .where(
                  (u) =>
                      Rbac.isStudent(u) &&
                      u.active &&
                      u.department == _department,
                )
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
        return StreamBuilder<List<AttendanceRecord>>(
          stream: backend.watchMarkedAttendance(widget.user.uid),
          builder: (context, snap) {
            final key =
                '$_department|${_subject.text.trim()}|'
                '${AttendanceRecord.dateKey(_date)}';
            // Re-opening a lecture already marked shows what was saved.
            if (snap.hasData && key != _loadedKey) {
              _loadedKey = key;
              _present.clear();
              for (final r in snap.data!) {
                if ('${r.department}|${r.subject}|${r.date}' == key) {
                  _present[r.studentUid] = r.present;
                }
              }
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _department,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: [
                    for (final d in departments)
                      DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (v) => setState(() {
                    _department = v ?? _department;
                    _loadedKey = '';
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _subject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  onChanged: (_) => setState(() => _loadedKey = ''),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
                ),
                const Divider(height: 24),
                if (students.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No students in $_department'),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${students.length} students · tap to toggle',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          for (final s in students) {
                            _present[s.uid] = true;
                          }
                        }),
                        child: const Text('All present'),
                      ),
                    ],
                  ),
                  for (final s in students)
                    CheckboxListTile(
                      key: ValueKey('att-${s.uid}'),
                      value: _present[s.uid] ?? true,
                      title: Text(s.name),
                      subtitle: Text(
                        (_present[s.uid] ?? true) ? 'Present' : 'Absent',
                      ),
                      onChanged: (v) =>
                          setState(() => _present[s.uid] = v ?? true),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _save(students),
                    icon: const Icon(Icons.save),
                    label: const Text('Save attendance'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return Live<List<AttendanceRecord>>(
      stream: backend.watchMarkedAttendance(user.uid),
      builder: (context, records) {
        // One row per lecture: department, subject and date.
        final lectures = <String, List<AttendanceRecord>>{};
        for (final r in records) {
          lectures
              .putIfAbsent('${r.date}|${r.department}|${r.subject}', () => [])
              .add(r);
        }
        if (lectures.isEmpty) {
          return const EmptyState(
            'No lectures marked yet',
            icon: Icons.history,
          );
        }
        final keys = lectures.keys.toList()..sort((a, b) => b.compareTo(a));
        return ListView(
          children: [
            for (final k in keys)
              Builder(
                builder: (_) {
                  final rs = lectures[k]!;
                  final p = rs.where((r) => r.present).length;
                  return ListTile(
                    leading: const Icon(Icons.fact_check),
                    title: Text('${rs.first.subject} · ${rs.first.department}'),
                    subtitle: Text(rs.first.date),
                    trailing: Text('$p / ${rs.length} present'),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
