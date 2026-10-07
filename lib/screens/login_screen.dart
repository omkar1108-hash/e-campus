import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_controller.dart';
import '../services/backend.dart';
import '../services/demo_backend.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final session = await auth.sendOtp('+91${_phone.text.trim()}');
      if (!mounted) return;
      nav.push(MaterialPageRoute(builder: (_) => OtpScreen(session: session)));
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = context.read<Backend>().isDemo;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.school, size: 80, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'E-Campus',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'College Management App',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      prefixText: '+91 ',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (v) =>
                        RegExp(r'^\d{10}$').hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Enter a valid 10-digit mobile number',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _sendOtp,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send OTP'),
                  ),
                  if (isDemo) ...[
                    const SizedBox(height: 24),
                    Card(
                      color: scheme.secondaryContainer,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Demo mode (Firebase not configured)\n'
                          'OTP for every number: ${DemoBackend.demoOtp}\n\n'
                          '9000000001 - Admin\n'
                          '9000000002 - Teacher\n'
                          '9000000003 - Class Representative\n'
                          '9000000004 - Student\n'
                          'Any other number registers as a new student.',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
