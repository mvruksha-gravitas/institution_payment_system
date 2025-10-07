import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:institutation_payment_system/services/student_repository.dart';
import 'package:institutation_payment_system/state/app_state.dart';
import 'package:institutation_payment_system/widgets/branding.dart';

class StudentLoginPage extends StatefulWidget {
  const StudentLoginPage({super.key});
  @override
  State<StudentLoginPage> createState() => _StudentLoginPageState();
}

class _StudentLoginPageState extends State<StudentLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _instIdCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _instIdCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final repo = FirebaseStudentRepository();
      final result = await repo.validateStudentLogin(instId: _instIdCtrl.text.trim(), phone: _phoneCtrl.text.trim(), password: _passwordCtrl.text.trim());
      if (!result.$1) throw Exception('Invalid credentials or account not approved');
      final studentId = result.$2!;
      if (!mounted) return;
      await context.read<AppState>().loginStudent(instId: _instIdCtrl.text.trim(), studentId: studentId, phone: _phoneCtrl.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/student', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandedLogo(height: 24),
            SizedBox(width: 8),
            Text('Student Login'),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    Text('Enter your InstId, phone number, and password.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    TextFormField(decoration: const InputDecoration(labelText: 'InstId', prefixIcon: Icon(Icons.badge, color: Colors.blue), border: OutlineInputBorder()), controller: _instIdCtrl, autofocus: true, validator: _required, textInputAction: TextInputAction.next, onFieldSubmitted: (_) => FocusScope.of(context).nextFocus()),
                    const SizedBox(height: 12),
                    TextFormField(decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone, color: Colors.blue), border: OutlineInputBorder()), controller: _phoneCtrl, keyboardType: TextInputType.phone, validator: _required, textInputAction: TextInputAction.next, onFieldSubmitted: (_) => FocusScope.of(context).nextFocus()),
                    const SizedBox(height: 12),
                    TextFormField(decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline, color: Colors.blue), border: OutlineInputBorder()), controller: _passwordCtrl, obscureText: true, validator: _required, textInputAction: TextInputAction.done, onFieldSubmitted: (_) => _login()),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _login, icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login), label: Text(_busy ? 'Signing in...' : 'Sign in'))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
