import 'package:flutter/material.dart';
import 'package:institutation_payment_system/services/student_repository.dart';
import 'package:institutation_payment_system/services/firebase_institution_repository.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';
import 'package:institutation_payment_system/widgets/branding.dart';

class StudentRegistrationPage extends StatefulWidget {
  const StudentRegistrationPage({super.key});

  @override
  State<StudentRegistrationPage> createState() => _StudentRegistrationPageState();
}

class _StudentRegistrationPageState extends State<StudentRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _instIdController = TextEditingController();
  bool _instValid = false;
  String? _instName;
  String? _adminName;
  String? _instAddress;

  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _occupationController = TextEditingController();
  final _collegeController = TextEditingController();
  bool _terms = false;

  bool _submitting = false;

  @override
  void dispose() {
    _instIdController.dispose();
    _firstController.dispose();
    _lastController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _aadhaarController.dispose();
    _photoUrlController.dispose();
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    _addressController.dispose();
    _occupationController.dispose();
    _collegeController.dispose();
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
  String? _phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7 || digits.length > 15) return 'Enter a valid phone number';
    return null;
  }
  String? _email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!re.hasMatch(v.trim())) return 'Enter a valid email';
    return null;
  }

  Future<void> _validateInstId() async {
    final raw = _instIdController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _instValid = false;
        _instName = null;
        _adminName = null;
        _instAddress = null;
      });
      return;
    }
    final instId = raw.toUpperCase();
    try {
      final instRepo = FirebaseInstitutionRepository();
      final snap = await instRepo.getInstitutionDoc(instId);
      if (!snap.exists) {
        if (!mounted) return;
        setState(() {
          _instValid = false;
          _instName = null;
          _adminName = null;
          _instAddress = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid InstId')));
        return;
      }
      final data = snap.data()!;
      final enabled = (data[InstitutionRegistrationSchema.enabled] as bool?) ?? true;
      final status = data[InstitutionRegistrationSchema.status] as String?;
      if (!enabled || status == InstitutionRegistrationSchema.statusRejected) {
        if (!mounted) return;
        setState(() {
          _instValid = false;
          _instName = null;
          _adminName = null;
          _instAddress = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Institution is disabled or rejected')));
        return;
      }
      setState(() {
        _instValid = true;
        _instName = (data[InstitutionRegistrationSchema.institutionName] as String?)?.trim();
        _adminName = (data[InstitutionRegistrationSchema.personName] as String?)?.trim();
        // Address might be stored with various keys; try common ones.
        _instAddress = (data['address'] as String?)?.trim() ?? (data['institution_address'] as String?)?.trim();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _instValid = false;
        _instName = null;
        _adminName = null;
        _instAddress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to validate InstId: $e')));
    }
  }

  Future<void> _submit() async {
    if (!_instValid) {
      await _validateInstId();
      if (!_instValid) return;
    }
    if (!_formKey.currentState!.validate() || !_terms) {
      if (!_terms) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please accept Terms & Conditions')));
      }
      return;
    }
    setState(() => _submitting = true);
    try {
      // Enforce: If the Mobile number is registered as Admin, that number cannot be allowed to register as Student
      final adminRepo = FirebaseInstitutionRepository();
      final admin = await adminRepo.findAnyByPhone(_phoneController.text.trim());
      if (admin != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This phone is already registered as an Institution Admin. Use a different phone number for student registration.')));
        return;
      }

      final repo = FirebaseStudentRepository();
      final instId = _instIdController.text.trim();
      // Enforce: The phone must not be registered under any other institution
      final inOther = await repo.existsStudentPhoneInOtherInstitution(phone: _phoneController.text.trim(), excludeInstId: instId);
      if (inOther) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This phone number is already registered as a student in another institution. Use a different phone.')));
        return;
      }

      await repo.submitStudentRegistration(
        instId: instId,
        firstName: _firstController.text.trim(),
        lastName: _lastController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        aadhaar: _aadhaarController.text.trim(),
        photoUrl: _photoUrlController.text.trim().isEmpty ? null : _photoUrlController.text.trim(),
        parentName: _parentNameController.text.trim(),
        parentPhone: _parentPhoneController.text.trim(),
        address: _addressController.text.trim(),
        occupation: _occupationController.text.trim(),
        collegeCourseClass: _collegeController.text.trim(),
        termsAccepted: _terms,
      );
      if (!mounted) return;
      await showDialog(context: context, builder: (_) => _StudentSuccessDialog(instId: instId));
      if (!mounted) return;
      _formKey.currentState!.reset();
      setState(() {
        _instValid = false;
        _instName = null;
        _adminName = null;
        _instAddress = null;
      });
      _instIdController.clear();
      _firstController.clear();
      _lastController.clear();
      _phoneController.clear();
      _emailController.clear();
      _aadhaarController.clear();
      _photoUrlController.clear();
      _parentNameController.clear();
      _parentPhoneController.clear();
      _addressController.clear();
      _occupationController.clear();
      _collegeController.clear();
      _terms = false;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e'), backgroundColor: Colors.red),
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
            Text('Student Registration'),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Enter your InstId to continue', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'InstId', prefixIcon: Icon(Icons.badge, color: Colors.blue), border: OutlineInputBorder()), controller: _instIdController, autofocus: true)),
                        const SizedBox(width: 8),
                        FilledButton(onPressed: _validateInstId, child: const Text('Validate')),
                      ]),
                      if (_instValid)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: const [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 6), Text('InstId is valid')]),
                            if ((_instName ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(_instName!, style: Theme.of(context).textTheme.titleMedium),
                            ],
                            if ((_adminName ?? '').isNotEmpty)
                              Text('Institution Admin: $_adminName', style: Theme.of(context).textTheme.bodyMedium),
                            if ((_instAddress ?? '').isNotEmpty)
                              Text(_instAddress!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8))),
                          ]),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                if (_instValid)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(children: [
                          Wrap(spacing: 12, runSpacing: 12, children: [
                            SizedBox(width: 340, child: _LabeledField(label: 'First Name', controller: _firstController, validator: _required, icon: Icons.person_outline)),
                            SizedBox(width: 340, child: _LabeledField(label: 'Last Name', controller: _lastController, validator: _required, icon: Icons.person_outline)),
                            SizedBox(width: 340, child: _LabeledField(label: 'Phone number', controller: _phoneController, validator: _phone, icon: Icons.phone, keyboardType: TextInputType.phone)),
                            SizedBox(width: 340, child: _LabeledField(label: 'E-mail ID', controller: _emailController, validator: _email, icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress)),
                            SizedBox(width: 340, child: _LabeledField(label: 'Aadhaar number', controller: _aadhaarController, validator: _required, icon: Icons.badge_outlined, keyboardType: TextInputType.number)),
                            SizedBox(width: 340, child: _LabeledField(label: 'Photo URL (optional)', controller: _photoUrlController, validator: (_) => null, icon: Icons.photo_camera_outlined, keyboardType: TextInputType.url)),
                            SizedBox(width: 340, child: _LabeledField(label: 'Parent\'s name', controller: _parentNameController, validator: _required, icon: Icons.family_restroom)),
                            SizedBox(width: 340, child: _LabeledField(label: 'Parent phone number', controller: _parentPhoneController, validator: _phone, icon: Icons.phone_iphone, keyboardType: TextInputType.phone)),
                            SizedBox(width: 692, child: _LabeledField(label: 'Permanent address', controller: _addressController, validator: _required, icon: Icons.home, keyboardType: TextInputType.multiline)),
                            SizedBox(width: 340, child: _LabeledField(label: 'Occupation', controller: _occupationController, validator: _required, icon: Icons.work_outline)),
                            SizedBox(width: 340, child: _LabeledField(label: 'College, Course, Class', controller: _collegeController, validator: _required, icon: Icons.school_outlined)),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            Checkbox(value: _terms, onChanged: (v) => setState(() => _terms = v ?? false)),
                            const Expanded(child: Text('I acknowledge the Terms & Conditions')),
                          ]),
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _submitting ? null : _submit, icon: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send), label: Text(_submitting ? 'Submitting...' : 'Submit'))),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label; final TextEditingController controller; final String? Function(String?)? validator; final IconData icon; final TextInputType? keyboardType;
  const _LabeledField({required this.label, required this.controller, required this.validator, required this.icon, this.keyboardType});
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: keyboardType == TextInputType.multiline ? 3 : 1,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.blue), border: const OutlineInputBorder()),
    );
  }
}

class _StudentSuccessDialog extends StatelessWidget {
  final String instId;
  const _StudentSuccessDialog({required this.instId});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registration submitted'),
      content: Text('Your registration is submitted for InstId: $instId. You will receive login credentials after approval.'),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
