import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../services/backend.dart';
import '../utils/rbac.dart';
import 'create_account_screen.dart';

/// Admin / admin staff: create accounts, edit profiles and roles, disable
/// or re-enable people. Admin staff never see administrator accounts.
class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  String _query = '';

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateAccountScreen(actor: widget.user),
      ),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created. Setup emails have been sent.'),
        ),
      );
    }
  }

  Future<void> _edit(AppUser target) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditUserSheet(actor: widget.user, target: target),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.person_add),
        label: const Text('Create account'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search name, email, role or department',
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
                final users = snap.data!
                    .where(
                      (u) =>
                          // Admin staff must not even see administrators.
                          (widget.user.role == UserRole.admin ||
                              u.role != UserRole.admin) &&
                          '${u.name} ${u.email} ${u.role.label} ${u.department}'
                              .toLowerCase()
                              .contains(_query),
                    )
                    .toList();
                if (users.isEmpty) {
                  return const Center(child: Text('No users found'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final u = users[i];
                    final editable = Rbac.canEditUser(widget.user, u);
                    return ListTile(
                      enabled: u.active,
                      leading: CircleAvatar(
                        child: Text(u.name.isEmpty ? '?' : u.name[0]),
                      ),
                      title: Text(u.name),
                      subtitle: Text(
                        '${u.role.label} · ${u.department}\n${u.email}',
                      ),
                      isThreeLine: true,
                      trailing: u.active
                          ? (editable ? const Icon(Icons.edit) : null)
                          : const Chip(label: Text('Disabled')),
                      onTap: editable ? () => _edit(u) : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EditUserSheet extends StatefulWidget {
  const _EditUserSheet({required this.actor, required this.target});

  final AppUser actor;
  final AppUser target;

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  late final _name = TextEditingController(text: widget.target.name);
  late String _department = widget.target.department;
  late UserRole _role = widget.target.role;
  late Gender? _gender = widget.target.gender;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final target = widget.target;
    final roles = Rbac.rolesAssignableBy(widget.actor, target);
    final departments = {...AppConfig.departments, target.department}.toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(target.email, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _department,
              decoration: const InputDecoration(labelText: 'Department'),
              items: [
                for (final d in departments)
                  DropdownMenuItem(value: d, child: Text(d)),
              ],
              onChanged: (v) => setState(() => _department = v ?? _department),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [
                for (final r in roles)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Gender?>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Not set')),
                for (final g in Gender.values)
                  DropdownMenuItem(value: g, child: Text(g.label)),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy || _name.text.trim().length < 2
                  ? null
                  : () => _run(
                      () => backend.updateUser(
                        target.copyWith(
                          name: _name.text.trim(),
                          department: _department,
                          role: _role,
                          gender: _gender,
                        ),
                      ),
                      'Saved',
                    ),
              child: const Text('Save changes'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => backend.sendPasswordReset(target.email),
                      'Setup email sent to ${target.email}',
                    ),
              icon: const Icon(Icons.mail),
              label: const Text('Resend setup email'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: target.active
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => backend.setUserActive(target.uid, !target.active),
                      target.active ? 'Account disabled' : 'Account enabled',
                    ),
              icon: Icon(target.active ? Icons.block : Icons.check_circle),
              label: Text(target.active ? 'Disable account' : 'Enable account'),
            ),
          ],
        ),
      ),
    );
  }
}
