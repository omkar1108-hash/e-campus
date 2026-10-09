import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../models/campus.dart';
import '../services/backend.dart';
import '../utils/rbac.dart';
import '../widgets/common.dart';

/// Weekly timetable per department. Admin staff / admin edit it; teachers
/// can switch to "My classes" to see their own lectures across departments.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late String _department = widget.user.department;
  bool _mine = false;

  AppUser get _me => widget.user;
  bool get _canEdit => Rbac.canEditTimetable(_me);

  Future<void> _add(Map<String, List<TimetableSlot>> all) async {
    final backend = context.read<Backend>();
    final teachers = (await backend.watchUsers().first)
        .where((u) => u.role.isTeaching && u.active)
        .toList();
    if (!mounted) return;
    final slot = await showDialog<TimetableSlot>(
      context: context,
      builder: (_) => _SlotDialog(teachers: teachers),
    );
    if (slot == null) return;
    await backend.saveTimetable(_department, [...?all[_department], slot]);
  }

  Future<void> _remove(
    Map<String, List<TimetableSlot>> all,
    TimetableSlot slot,
  ) async {
    final rest = [...?all[_department]]..remove(slot);
    await context.read<Backend>().saveTimetable(_department, rest);
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return Live<Map<String, List<TimetableSlot>>>(
      stream: backend.watchTimetables(),
      builder: (context, all) {
        final slots = _mine
            ? [
                for (final e in all.entries)
                  for (final s in e.value)
                    if (s.teacherUid == _me.uid) DeptSlot(e.key, s),
              ]
            : [
                for (final s in all[_department] ?? <TimetableSlot>[])
                  DeptSlot(_department, s),
              ];
        slots.sort((a, b) => a.slot.order.compareTo(b.slot.order));
        final today = weekDayName(DateTime.now());
        return Scaffold(
          floatingActionButton: _canEdit && !_mine
              ? FloatingActionButton.extended(
                  onPressed: () => _add(all),
                  icon: const Icon(Icons.add),
                  label: const Text('Add class'),
                )
              : null,
          body: Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  children: [
                    if (_me.role.isTeaching)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('My classes'),
                          selected: _mine,
                          onSelected: (_) => setState(() => _mine = true),
                        ),
                      ),
                    for (final d in {
                      ...AppConfig.departments,
                      ...all.keys,
                      _me.department,
                    }.where((d) => d.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(d),
                          selected: !_mine && _department == d,
                          onSelected: (_) => setState(() {
                            _mine = false;
                            _department = d;
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: slots.isEmpty
                    ? EmptyState(
                        _mine
                            ? 'No classes assigned to you yet'
                            : 'No timetable for $_department yet',
                        icon: Icons.event_busy,
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                        children: [
                          for (final day in weekDays)
                            if (slots.any((s) => s.slot.day == day)) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                                child: Text(
                                  day == today ? '$day · today' : day,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: day == today
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                            : null,
                                      ),
                                ),
                              ),
                              for (final s in slots.where(
                                (s) => s.slot.day == day,
                              ))
                                Card(
                                  child: ListTile(
                                    leading: Text(
                                      '${s.slot.start}\n${s.slot.end}',
                                      textAlign: TextAlign.center,
                                    ),
                                    title: Text(s.slot.subject),
                                    subtitle: Text(
                                      [
                                        if (_mine) s.department,
                                        if (s.slot.teacherName.isNotEmpty)
                                          s.slot.teacherName,
                                        if (s.slot.room.isNotEmpty) s.slot.room,
                                      ].join(' · '),
                                    ),
                                    trailing: _canEdit && !_mine
                                        ? IconButton(
                                            tooltip: 'Remove class',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            onPressed: () =>
                                                _remove(all, s.slot),
                                          )
                                        : null,
                                  ),
                                ),
                            ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SlotDialog extends StatefulWidget {
  const _SlotDialog({required this.teachers});

  final List<AppUser> teachers;

  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _start = TextEditingController(text: '09:00');
  final _end = TextEditingController(text: '10:00');
  final _room = TextEditingController();
  String _day = weekDays.first;
  AppUser? _teacher;

  @override
  void dispose() {
    _subject.dispose();
    _start.dispose();
    _end.dispose();
    _room.dispose();
    super.dispose();
  }

  String? _time(String? v) =>
      TimetableSlot.validTime((v ?? '').trim()) ? null : 'Use 24-hour HH:mm';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add class'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _day,
                decoration: const InputDecoration(labelText: 'Day'),
                items: [
                  for (final d in weekDays)
                    DropdownMenuItem(value: d, child: Text(d)),
                ],
                onChanged: (v) => setState(() => _day = v ?? _day),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _start,
                      decoration: const InputDecoration(labelText: 'Start'),
                      validator: _time,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _end,
                      decoration: const InputDecoration(labelText: 'End'),
                      validator: _time,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subject,
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: requiredField,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<AppUser?>(
                initialValue: _teacher,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Teacher'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Not set')),
                  for (final t in widget.teachers)
                    DropdownMenuItem(
                      value: t,
                      child: Text('${t.name} (${t.department})'),
                    ),
                ],
                onChanged: (v) => setState(() => _teacher = v),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _room,
                decoration: const InputDecoration(labelText: 'Room (optional)'),
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
            if (_start.text.trim().compareTo(_end.text.trim()) >= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('End time must be after start')),
              );
              return;
            }
            Navigator.pop(
              context,
              TimetableSlot(
                day: _day,
                start: _start.text.trim(),
                end: _end.text.trim(),
                subject: _subject.text.trim(),
                teacherUid: _teacher?.uid ?? '',
                teacherName: _teacher?.name ?? '',
                room: _room.text.trim(),
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
