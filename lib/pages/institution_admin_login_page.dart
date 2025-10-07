import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:institutation_payment_system/services/firebase_institution_repository.dart';
import 'package:institutation_payment_system/state/app_state.dart';
import 'package:institutation_payment_system/widgets/branding.dart';

class InstitutionAdminLoginPage extends StatefulWidget {
  const InstitutionAdminLoginPage({super.key});
  @override
  State<InstitutionAdminLoginPage> createState() => _InstitutionAdminLoginPageState();
}

class _InstitutionAdminLoginPageState extends State<InstitutionAdminLoginPage> {
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
      final repo = FirebaseInstitutionRepository();
      final ok = await repo.validateInstitutionAdminLogin(instId: _instIdCtrl.text.trim(), phone: _phoneCtrl.text.trim(), password: _passwordCtrl.text.trim());
      if (!ok) throw Exception('Invalid credentials or institution disabled');
      if (!mounted) return;
      await context.read<AppState>().loginInstitutionAdmin(instId: _instIdCtrl.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/institution-admin', (route) => false);
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
            Text('Institution Admin Login'),
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
                    Text('Use your InstId, admin phone and password to access the Institution Admin portal.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    TextFormField(decoration: const InputDecoration(labelText: 'InstId', prefixIcon: Icon(Icons.badge, color: Colors.blue), border: OutlineInputBorder()), controller: _instIdCtrl, autofocus: true, validator: _required, textInputAction: TextInputAction.next, onFieldSubmitted: (_) => FocusScope.of(context).nextFocus()),
                    const SizedBox(height: 12),
                    TextFormField(decoration: const InputDecoration(labelText: 'Admin Phone', prefixIcon: Icon(Icons.phone, color: Colors.blue), border: OutlineInputBorder()), controller: _phoneCtrl, keyboardType: TextInputType.phone, validator: _required, textInputAction: TextInputAction.next, onFieldSubmitted: (_) => FocusScope.of(context).nextFocus()),
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
