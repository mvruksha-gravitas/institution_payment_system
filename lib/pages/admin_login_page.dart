import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:institutation_payment_system/services/admin_repository.dart';
import 'package:institutation_payment_system/state/app_state.dart';
import 'package:institutation_payment_system/widgets/branding.dart';


class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController(text: 'mvruksha.gravitas');
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  final _repo = AdminRepository();

  @override
  void initState() {
    super.initState();
    _repo.ensureDefaultAdmin();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final ok = await _repo.validateLogin(username: _usernameCtrl.text.trim(), password: _passwordCtrl.text.trim());
      if (!ok) throw Exception('Invalid credentials');
      if (!mounted) return;
      await context.read<AppState>().loginAdmin();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false);
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
            Text('Super Admin Login'),
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
                    Center(
                      child: Column(
                        children: [
                          BrandedLogo(height: 48),
                          SizedBox(height: 8),
                          Text('mVruksha Softwares', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          Text('Super Admin Portal', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    TextFormField(decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.admin_panel_settings, color: Colors.blue), border: OutlineInputBorder()), controller: _usernameCtrl, autofocus: true, validator: _required, textInputAction: TextInputAction.next, onFieldSubmitted: (_) => FocusScope.of(context).nextFocus()),
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
