import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../models/bus.dart';
import '../services/backend.dart';
import '../utils/bus_status.dart';

/// Admin / admin staff: create buses, assign a driver and the departments
/// that may track each bus.
class ManageBusesScreen extends StatelessWidget {
  const ManageBusesScreen({super.key, required this.user});

  final AppUser user;

  Future<void> _edit(
    BuildContext context,
    Bus? bus,
    List<Bus> buses,
    List<AppUser> users,
  ) async {
    final backend = context.read<Backend>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<Bus>(
      context: context,
      builder: (_) => _BusFormDialog(bus: bus, buses: buses, users: users),
    );
    if (result == null) return;
    try {
      await backend.saveBus(result);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> _delete(BuildContext context, Bus bus) async {
    final backend = context.read<Backend>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${bus.name}?'),
        content: const Text('Students will no longer see this bus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await backend.deleteBus(bus.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return StreamBuilder<List<AppUser>>(
      stream: backend.watchUsers(),
      builder: (context, usersSnap) {
        return StreamBuilder<List<Bus>>(
          stream: backend.watchBuses(user),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            if (!snap.hasData || !usersSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final buses = snap.data!;
            final users = usersSnap.data!;
            String driverName(String? uid) {
              if (uid == null) return 'No driver assigned';
              final d = users.where((u) => u.uid == uid).firstOrNull;
              return d == null ? 'Unknown driver' : 'Driver: ${d.name}';
            }

            return Scaffold(
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _edit(context, null, buses, users),
                icon: const Icon(Icons.add),
                label: const Text('Add bus'),
              ),
              body: buses.isEmpty
                  ? const Center(child: Text('No buses yet. Tap "Add bus".'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: buses.length,
                      itemBuilder: (context, i) {
                        final b = buses[i];
                        return ListTile(
                          leading: const Icon(Icons.directions_bus),
                          title: Text('${b.name}  ·  ${b.plate}'),
                          subtitle: Text(
                            '${driverName(b.driverUid)}\n'
                            'Departments: ${b.departments.join(', ')}\n'
                            '${busStatus(b, DateTime.now())}',
                          ),
                          isThreeLine: true,
                          onTap: () => _edit(context, b, buses, users),
                          trailing: IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(context, b),
                          ),
                        );
                      },
                    ),
            );
          },
        );
      },
    );
  }
}

class _BusFormDialog extends StatefulWidget {
  const _BusFormDialog({
    required this.bus,
    required this.buses,
    required this.users,
  });

  final Bus? bus;
  final List<Bus> buses;
  final List<AppUser> users;

  @override
  State<_BusFormDialog> createState() => _BusFormDialogState();
}

class _BusFormDialogState extends State<_BusFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.bus?.name ?? '');
  late final _plate = TextEditingController(text: widget.bus?.plate ?? '');
  late String? _driver = widget.bus?.driverUid;
  late final Set<String> _departments = {...?widget.bus?.departments};
  bool _showDeptError = false;

  @override
  void dispose() {
    _name.dispose();
    _plate.dispose();
    super.dispose();
  }

  List<AppUser> get _driverChoices {
    // A driver can drive one bus: hide drivers assigned elsewhere.
    final taken = {
      for (final b in widget.buses)
        if (b.id != widget.bus?.id && b.driverUid != null) b.driverUid,
    };
    return widget.users
        .where(
          (u) =>
              u.role == UserRole.busDriver &&
              u.active &&
              (!taken.contains(u.uid) || u.uid == _driver),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final choices = _driverChoices;
    final departments = {...AppConfig.departments, ..._departments}.toList();
    return AlertDialog(
      title: Text(widget.bus == null ? 'Add bus' : 'Edit bus'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Bus name (e.g. Bus 1 - North route)',
                ),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Number plate'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter the number plate' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: choices.any((u) => u.uid == _driver)
                    ? _driver
                    : null,
                decoration: const InputDecoration(labelText: 'Driver'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('No driver yet'),
                  ),
                  for (final u in choices)
                    DropdownMenuItem(value: u.uid, child: Text(u.name)),
                ],
                onChanged: (v) => setState(() => _driver = v),
              ),
              const SizedBox(height: 16),
              const Text('Departments that can track this bus'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in departments)
                    FilterChip(
                      label: Text(d),
                      selected: _departments.contains(d),
                      onSelected: (on) => setState(() {
                        on ? _departments.add(d) : _departments.remove(d);
                        _showDeptError = false;
                      }),
                    ),
                ],
              ),
              if (_showDeptError)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Choose at least one department',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
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
            final valid = _formKey.currentState!.validate();
            if (_departments.isEmpty) {
              setState(() => _showDeptError = true);
              return;
            }
            if (!valid) return;
            final base = widget.bus ?? const Bus(id: '', name: '', plate: '');
            Navigator.pop(
              context,
              base.copyWith(
                name: _name.text.trim(),
                plate: _plate.text.trim().toUpperCase(),
                driverUid: _driver,
                clearDriver: _driver == null,
                departments: _departments.toList()..sort(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
