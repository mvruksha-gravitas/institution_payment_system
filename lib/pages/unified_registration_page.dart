import 'package:flutter/material.dart';
import 'package:institutation_payment_system/services/firebase_institution_repository.dart';
import 'package:institutation_payment_system/services/student_repository.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';
import 'package:institutation_payment_system/widgets/otp_reset_dialog.dart';
import 'package:institutation_payment_system/widgets/branding.dart';


class UnifiedRegistrationPage extends StatefulWidget {
  const UnifiedRegistrationPage({super.key});
  @override
  State<UnifiedRegistrationPage> createState() => _UnifiedRegistrationPageState();
}

enum _RegSelection { institution, student }

class _UnifiedRegistrationPageState extends State<UnifiedRegistrationPage> {
  _RegSelection _selection = _RegSelection.institution;
  String? _initialInstId;

  double get _maxWidth => _selection == _RegSelection.institution ? 520 : 760;

  @override
  void initState() {
    super.initState();
    final qp = Uri.base.queryParameters;
    final role = qp['role'];
    if (role == 'student') _selection = _RegSelection.student;
    _initialInstId = qp['inst'];
  }

  Future<void> _goHome() async { if (!mounted) return; Navigator.of(context).pushNamed('/'); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandedHeaderLine(), actions: [TextButton(onPressed: _goHome, child: const Text('Website'))]),

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _maxWidth),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Compact radio selector, minimal spacing and aligned to form width
                _CompactRoleSelector(selection: _selection, onChanged: (v) => setState(() => _selection = v)),
                const SizedBox(height: 6),
                if (_selection == _RegSelection.institution) const InstitutionFormCard() else StudentFormCard(initialInstId: _initialInstId),
              ]),
            ),
          ),
        ),
      ),

    );
  }
}

class _CompactRoleSelector extends StatelessWidget {
  final _RegSelection selection;
  final ValueChanged<_RegSelection> onChanged;
  const _CompactRoleSelector({required this.selection, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12.5);
    return Row(children: [
      Radio<_RegSelection>(value: _RegSelection.institution, groupValue: selection, onChanged: (v) => onChanged(v ?? _RegSelection.institution)),
      GestureDetector(onTap: () => onChanged(_RegSelection.institution), child: Text('Institution', style: labelStyle)),
      const SizedBox(width: 16),
      Radio<_RegSelection>(value: _RegSelection.student, groupValue: selection, onChanged: (v) => onChanged(v ?? _RegSelection.student)),
      GestureDetector(onTap: () => onChanged(_RegSelection.student), child: Text('Student', style: labelStyle)),
    ]);
  }
}

class InstitutionFormCard extends StatefulWidget { const InstitutionFormCard({super.key}); @override State<InstitutionFormCard> createState() => _InstitutionFormCardState(); }
class _InstitutionFormCardState extends State<InstitutionFormCard> {
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final repo = FirebaseInstitutionRepository();
      // If phone already belongs to an approved institution, offer password reset instead
      final existing = await repo.findApprovedByPhone(_phoneController.text.trim());
      if (existing != null) {
        if (!mounted) return; setState(() => _submitting = false);
        final instId = existing[InstitutionRegistrationSchema.id] as String? ?? existing[InstitutionRegistrationSchema.uniqueInstitutionId] as String? ?? '';
        final email = existing[InstitutionRegistrationSchema.email] as String? ?? '';
        final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Phone already registered'), content: const Text('This phone is already registered for an approved institution. Would you like to reset the Institution Admin password instead?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset password'))]));
        if (confirm == true) {
          if (!mounted) return; await showDialog(context: context, builder: (ctx) => OtpResetDialog(role: 'institution_admin', instId: instId, phone: _phoneController.text.trim(), toEmail: email));
        }
        return;
      }
      await repo.submitInstitutionRequest(
        institutionName: _institutionController.text.trim(),
        personName: _personController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      await showDialog(context: context, builder: (_) => const _ThanksPendingDialog());
      if (!mounted) return;
      _formKey.currentState!.reset();
      _institutionController.clear();
      _personController.clear();
      _phoneController.clear();
      _emailController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _submitting = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            Text('Institution Enrollment', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Submit details. Super Admin will approve and generate your Inst-Id and credentials. Email delivery is not enabled.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            _LabeledField(label: 'Institution name', controller: _institutionController, validator: _required, icon: Icons.apartment, autofocus: true),
            const SizedBox(height: 12),
            _LabeledField(label: 'Person name', controller: _personController, validator: _required, icon: Icons.person_outline),
            const SizedBox(height: 12),
            _LabeledField(label: 'Phone number (used as login id)', controller: _phoneController, validator: _phone, icon: Icons.phone, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _LabeledField(label: 'Email id', controller: _emailController, validator: _email, icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _submitting ? null : _submit, icon: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send), label: Text(_submitting ? 'Submitting...' : 'Submit'))),
          ]),
        ),
      ),
    );
  }
}

class StudentFormCard extends StatefulWidget { final String? initialInstId; const StudentFormCard({super.key, this.initialInstId}); @override State<StudentFormCard> createState() => _StudentFormCardState(); }
class _StudentFormCardState extends State<StudentFormCard> {
  final _formKey = GlobalKey<FormState>();
  final _instIdController = TextEditingController();
  bool _instValid = false;

  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _occupationController = TextEditingController();
  final _collegeController = TextEditingController();
  bool _terms = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final pre = widget.initialInstId;
    if (pre != null && pre.trim().isNotEmpty) {
      _instIdController.text = pre.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) => _validateInstId());
    }
  }

  @override
  void dispose() {
    _instIdController.dispose();
    _firstController.dispose();
    _lastController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _aadhaarController.dispose();
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
    final instId = _instIdController.text.trim();
    if (instId.isEmpty) { setState(() => _instValid = false); return; }
    final repo = FirebaseStudentRepository();
    final ok = await repo.validateInstId(instId);
    setState(() => _instValid = ok);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid or disabled InstId')));
    }
  }

  Future<void> _submit() async {
    if (!_instValid) { await _validateInstId(); if (!_instValid) return; }
    if (!_formKey.currentState!.validate() || !_terms) {
      if (!_terms) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please accept Terms & Conditions'))); }
      return;
    }
    setState(() => _submitting = true);
    try {
      // Enforce: If this phone is registered as an Institution Admin, block student registration
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
        photoUrl: null,
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
      setState(() => _instValid = false);
      _instIdController.clear();
      _firstController.clear();
      _lastController.clear();
      _phoneController.clear();
      _emailController.clear();
      _aadhaarController.clear();
      _parentNameController.clear();
      _parentPhoneController.clear();
      _addressController.clear();
      _occupationController.clear();
      _collegeController.clear();
      _terms = false;
    } catch (e) {
      if (!mounted) return;
      // If phone already registered for this InstId, offer OTP reset
      if ((e.toString()).contains('Phone number already registered')) {
        try {
          final instId = _instIdController.text.trim();
          final repo = FirebaseStudentRepository();
          final existing = await repo.findStudentByPhone(instId: instId, phone: _phoneController.text.trim());
          if (existing != null && mounted) {
            final email = existing[StudentSchema.email] as String? ?? '';
            final studentId = existing[StudentSchema.id] as String? ?? '';
            await showDialog(context: context, builder: (ctx) => OtpResetDialog(role: 'student', instId: instId, phone: _phoneController.text.trim(), toEmail: email, studentId: studentId));
          }
        } catch (_) {}
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e'), backgroundColor: Colors.red));
      }
    } finally { if (mounted) setState(() => _submitting = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
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
            if (_instValid) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: const [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 6), Text('InstId is valid')]))
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
                  SizedBox(width: 360, child: _LabeledField(label: 'First name', controller: _firstController, validator: _required, icon: Icons.person_outline)),
                  SizedBox(width: 360, child: _LabeledField(label: 'Last name', controller: _lastController, validator: _required, icon: Icons.person_outline)),
                  SizedBox(width: 360, child: _LabeledField(label: 'Phone number', controller: _phoneController, validator: _phone, icon: Icons.phone, keyboardType: TextInputType.phone)),
                  SizedBox(width: 360, child: _LabeledField(label: 'Aadhaar number', controller: _aadhaarController, validator: _required, icon: Icons.badge_outlined, keyboardType: TextInputType.number)),
                  SizedBox(width: 360, child: _LabeledField(label: 'E-mail ID', controller: _emailController, validator: _email, icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress)),
                  SizedBox(width: 360, child: _LabeledField(label: 'Parent phone number', controller: _parentPhoneController, validator: _phone, icon: Icons.phone_iphone, keyboardType: TextInputType.phone)),
                  SizedBox(width: 736, child: _LabeledField(label: 'Permanent address', controller: _addressController, validator: _required, icon: Icons.home, keyboardType: TextInputType.multiline)),
                  SizedBox(width: 360, child: _LabeledField(label: 'Parent name', controller: _parentNameController, validator: _required, icon: Icons.family_restroom)),
                  SizedBox(width: 360, child: _LabeledField(label: 'Occupation', controller: _occupationController, validator: _required, icon: Icons.work_outline)),
                  SizedBox(width: 736, child: _LabeledField(label: 'College, Course, Class', controller: _collegeController, validator: _required, icon: Icons.school_outlined)),
                ]),
                const SizedBox(height: 12),
                Row(children: [Checkbox(value: _terms, onChanged: (v) => setState(() => _terms = v ?? false)), const Expanded(child: Text('I acknowledge the Terms & Conditions'))]),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _submitting ? null : _submit, icon: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send), label: Text(_submitting ? 'Submitting...' : 'Submit'))),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class _LabeledField extends StatelessWidget {
  final String label; final TextEditingController controller; final String? Function(String?)? validator; final IconData icon; final TextInputType? keyboardType; final bool autofocus;
  const _LabeledField({required this.label, required this.controller, required this.validator, required this.icon, this.keyboardType, this.autofocus = false});
  @override
  Widget build(BuildContext context) {
    return TextFormField(controller: controller, validator: validator, keyboardType: keyboardType, maxLines: keyboardType == TextInputType.multiline ? 3 : 1, autofocus: autofocus, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.blue), border: const OutlineInputBorder()));
  }
}

class _ThanksPendingDialog extends StatelessWidget { const _ThanksPendingDialog(); @override Widget build(BuildContext context) { return AlertDialog(title: const Text('Thank you for enrolling'), content: const Text('Your request has been submitted for approval. You will receive InstId and credentials after Super Admin approval.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))]); }}

class _StudentSuccessDialog extends StatelessWidget { final String instId; const _StudentSuccessDialog({required this.instId}); @override Widget build(BuildContext context) { return AlertDialog(title: const Text('Registration submitted'), content: Text('Your registration is submitted for InstId: $instId. You will receive login credentials after approval.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))]); }}
