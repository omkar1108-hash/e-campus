import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../services/backend.dart';
import '../utils/rbac.dart';

/// Admin / admin staff: create a login for someone. They receive a
/// verification email and a link to choose their own password.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key, required this.actor});

  final AppUser actor;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  String _department = AppConfig.departments.first;
  late UserRole _role = Rbac.rolesCreatableBy(widget.actor).last;
  Gender? _gender;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final backend = context.read<Backend>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await backend.createAccount(
        email: _email.text,
        name: _name.text.trim(),
        department: _department,
        role: _role,
        gender: _gender,
      );
      nav.pop(true);
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = Rbac.rolesCreatableBy(widget.actor);
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (they must be able to open it)',
                prefixIcon: Icon(Icons.email),
              ),
              validator: (v) => (v ?? '').trim().contains('@')
                  ? null
                  : 'Enter a valid email address',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.badge),
              ),
              items: [
                for (final r in roles)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _department,
              decoration: const InputDecoration(
                labelText: 'Department',
                prefixIcon: Icon(Icons.apartment),
              ),
              items: [
                for (final d in AppConfig.departments)
                  DropdownMenuItem(value: d, child: Text(d)),
              ],
              onChanged: (v) => setState(() => _department = v ?? _department),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Gender>(
              initialValue: _gender,
              decoration: InputDecoration(
                labelText: _role == UserRole.student
                    ? 'Gender (required for students)'
                    : 'Gender (optional)',
                prefixIcon: const Icon(Icons.wc),
              ),
              items: [
                for (final g in Gender.values)
                  DropdownMenuItem(value: g, child: Text(g.label)),
              ],
              onChanged: (v) => setState(() => _gender = v),
              validator: (v) => (_role == UserRole.student && v == null)
                  ? 'Select a gender'
                  : null,
            ),
            const SizedBox(height: 8),
            const Text(
              'The person receives two emails: one to verify their address '
              'and one to choose their password. They can then sign in.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
