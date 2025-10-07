import 'package:flutter/material.dart';
import 'package:institutation_payment_system/services/firebase_institution_repository.dart';
import 'package:institutation_payment_system/services/student_repository.dart';
import 'package:institutation_payment_system/widgets/branding.dart';

class InstitutionRegistrationPage extends StatefulWidget {
  const InstitutionRegistrationPage({super.key});

  @override
  State<InstitutionRegistrationPage> createState() => _InstitutionRegistrationPageState();
}

class _InstitutionRegistrationPageState extends State<InstitutionRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _institutionController = TextEditingController();
  final _personController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _institutionController.dispose();
    _personController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _phoneValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7 || digits.length > 15) return 'Enter a valid phone number';
    return null;
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!re.hasMatch(v.trim())) return 'Enter a valid email';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final repo = FirebaseInstitutionRepository();
      final phone = _phoneController.text.trim();
      // Enforce: One mobile number cannot be allowed to register for multiple institutions
      final existing = await repo.findAnyByPhone(phone);
      if (existing != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This phone number is already registered for an Institution Admin. Use a different phone.')));
        return;
      }
      // Enforce: Admin phone cannot be used by any Student account either
      final studentRepo = FirebaseStudentRepository();
      final usedByStudent = await studentRepo.existsAnyStudentByPhoneGlobal(phone);
      if (usedByStudent) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This phone number is already registered for a Student account. Use a different phone.')));
        return;
      }

      final result = await repo.registerInstitutionImmediate(
        institutionName: _institutionController.text.trim(),
        personName: _personController.text.trim(),
        phoneNumber: phone,
        email: _emailController.text.trim(),
      );
      final instId = result.$1;
      final creds = result.$2;

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => _ThankYouDialog(instId: instId, username: creds.username, password: creds.password),
      );
      if (!mounted) return;
      _formKey.currentState!.reset();
      _institutionController.clear();
      _personController.clear();
      _phoneController.clear();
      _emailController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting registration: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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
            Text('Institution Enrollment'),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const _HeaderSection(),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _LabeledField(label: 'Institution name', controller: _institutionController, validator: _requiredValidator, icon: Icons.apartment, autofocus: true),
                            const SizedBox(height: 12),
                            _LabeledField(label: 'Person name', controller: _personController, validator: _requiredValidator, icon: Icons.person_outline),
                            const SizedBox(height: 12),
                            _LabeledField(label: 'Phone number', controller: _phoneController, validator: _phoneValidator, icon: Icons.phone, keyboardType: TextInputType.phone),
                            const SizedBox(height: 12),
                            _LabeledField(label: 'Email id', controller: _emailController, validator: _emailValidator, icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                icon: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                                label: Text(_submitting ? 'Submitting...' : 'Submit & get InstId'),
                                onPressed: _submitting ? null : _submit,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Register your Institution', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('Provide your details. A unique InstId will be generated for your login.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label; final TextEditingController controller; final String? Function(String?)? validator; final IconData icon; final TextInputType? keyboardType; final bool autofocus;
  const _LabeledField({required this.label, required this.controller, required this.validator, required this.icon, this.keyboardType, this.autofocus = false});
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      autofocus: autofocus,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.blue), border: const OutlineInputBorder()),
    );
  }
}

class _ThankYouDialog extends StatelessWidget {
  final String instId; final String username; final String password;
  const _ThankYouDialog({required this.instId, required this.username, required this.password});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thank you for enrolling'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Your institution has been registered successfully.'),
        const SizedBox(height: 8),
        Text('InstId: $instId'),
        Text('Institution Admin login: $username'),
        Text('Temporary password: $password'),
        const SizedBox(height: 8),
        const Text('Share InstId with your students. They must use it to register.'),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}
