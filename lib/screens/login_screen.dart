import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/campus.dart';

import '../services/auth_controller.dart';
import '../services/backend.dart';
import '../services/demo_backend.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toast(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    setState(() => _busy = true);
    try {
      await auth.signIn(_email.text, _password.text);
    } on AuthException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _toast('Enter your email above first');
      return;
    }
    final auth = context.read<AuthController>();
    try {
      await auth.sendPasswordReset(email);
      if (mounted) _toast('If that account exists, a reset link was sent.');
    } on AuthException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final hero = _Hero(scheme: scheme, compact: !wide);
            final signIn = _signInCard(context);
            final info = _Info(scheme: scheme);
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    hero,
                                    const SizedBox(height: 24),
                                    info,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(flex: 2, child: signIn),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              hero,
                              const SizedBox(height: 16),
                              signIn,
                              const SizedBox(height: 24),
                              info,
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _signInCard(BuildContext context) {
    final isDemo = context.read<Backend>().isDemo;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              const Text('Sign in with your college email'),
              const SizedBox(height: 20),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (v) => (v ?? '').trim().contains('@')
                    ? null
                    : 'Enter a valid email address',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Enter your password' : null,
                onFieldSubmitted: (_) => _signIn(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
              FilledButton(
                onPressed: _busy ? null : _signIn,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign in'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Accounts are created by your college administrator. '
                'You will receive an email to set your password.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              if (isDemo) ...[
                const SizedBox(height: 16),
                Card(
                  color: scheme.secondaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Demo mode (Firebase not configured)\n'
                      'Password for every demo account: '
                      '${DemoBackend.demoPassword}\n\n'
                      'admin@ / staff@ / library@ / teacher@ / rep@ /\n'
                      'student@ / driver@ / committee@  ecampus.demo',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.scheme, required this.compact});

  final ColorScheme scheme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.all(compact ? 20 : 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.school,
                size: compact ? 40 : 56,
                color: scheme.onPrimary,
              ),
              const SizedBox(width: 12),
              Text(
                'E-Campus',
                style: (compact ? text.headlineMedium : text.displaySmall)
                    ?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppConfig.collegeName,
            style: text.titleMedium?.copyWith(color: scheme.onPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            AppConfig.collegeTagline,
            style: text.bodyMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// Public notices, what the app offers, and how to reach the college.
class _Info extends StatelessWidget {
  const _Info({required this.scheme});

  final ColorScheme scheme;

  static const _features = <(IconData, String)>[
    (Icons.local_library, 'E-Library'),
    (Icons.directions_bus, 'Live bus tracking'),
    (Icons.chat, 'Chat'),
    (Icons.smart_toy, 'AI chatbot'),
    (Icons.newspaper, 'Tech news'),
    (Icons.calendar_month, 'Timetable'),
    (Icons.fact_check, 'Attendance'),
    (Icons.assignment, 'Assignments'),
    (Icons.report_problem, 'Grievance redressal'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backend = context.read<Backend>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<List<Notice>>(
          stream: backend.watchPublicNotices(),
          builder: (context, snap) {
            // No public notices (or no permission yet): show nothing.
            final notices = (snap.data ?? const <Notice>[]).take(3).toList();
            if (notices.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                key: const ValueKey('public-notices'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Latest notices', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final n in notices)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.campaign),
                        title: Text(n.title),
                        subtitle: Text(
                          '${n.body}\n${DateFormat('d MMM yyyy').format(n.createdAt)}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        Text('What you can do here', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _features)
              Chip(avatar: Icon(f.$1, size: 18), label: Text(f.$2)),
          ],
        ),
        const SizedBox(height: 24),
        Text('Contact the college', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        const _ContactRow(Icons.location_on, AppConfig.contactAddress),
        const _ContactRow(Icons.phone, AppConfig.contactPhone),
        const _ContactRow(Icons.email, AppConfig.contactEmail),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
