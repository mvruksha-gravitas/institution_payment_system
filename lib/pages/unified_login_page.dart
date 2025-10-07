import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:institutation_payment_system/services/firebase_institution_repository.dart';
import 'package:institutation_payment_system/services/student_repository.dart';
import 'package:institutation_payment_system/state/app_state.dart';
import 'package:institutation_payment_system/widgets/otp_reset_dialog.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';
import 'package:institutation_payment_system/widgets/branding.dart';


class UnifiedLoginPage extends StatelessWidget {
  const UnifiedLoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandedHeaderLine(),
        actions: [TextButton(onPressed: () => Navigator.of(context).pushNamed('/'), child: const Text('Website'))],
      ),
      body: const SingleUnifiedLoginCard(),
    );
  }
}

class SingleUnifiedLoginCard extends StatefulWidget {
  const SingleUnifiedLoginCard({super.key});
  @override
  State<SingleUnifiedLoginCard> createState() => _SingleUnifiedLoginCardState();
}

class _SingleUnifiedLoginCardState extends State<SingleUnifiedLoginCard> {
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  // Step state
  // identify -> select_inst (if multiple student memberships) -> password
  String _step = 'identify';
  Map<String, dynamic>? _adminData; // when phone is Institution Admin
  List<(String instId, String studentId, Map<String, dynamic> data)> _memberships = const [];
  String? _selectedInstId;
  String? _selectedStudentId;
  String? _selectedInstitutionName;
  String? _selectedDisplayName; // Student full name or Admin person name

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _identify() async {
    if (_busy) return;
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter mobile number')));
      return;
    }
    setState(() => _busy = true);
    try {
      final instRepo = FirebaseInstitutionRepository();
      final studentRepo = FirebaseStudentRepository();

      // In parallel: check admin and student memberships
      final adminFuture = instRepo.findApprovedByPhone(phone);
      final membershipsFuture = studentRepo.listMembershipsByPhone(phone: phone);
      final admin = await adminFuture; // approved only
      final memberships = await membershipsFuture;

      if (admin == null && memberships.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No account found. Please register.')));
        return;
      }

      if (admin != null) {
        // Admin number cannot be used as Student (enforced going forward). Prefer Admin login.
        _adminData = admin;
        _selectedInstId = (admin[InstitutionRegistrationSchema.id] as String?) ?? (admin[InstitutionRegistrationSchema.uniqueInstitutionId] as String?) ?? '';
        _selectedDisplayName = admin[InstitutionRegistrationSchema.personName] as String? ?? '';
        _selectedInstitutionName = admin[InstitutionRegistrationSchema.institutionName] as String? ?? '';
        _step = 'password';
        if (memberships.isNotEmpty) {
          // Inform the user about the constraint
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This mobile is registered as Institution Admin. Student login is not allowed for this number.')));
          }
        }
      } else {
        // Student path
        _memberships = memberships;
        if (memberships.length == 1) {
          final m = memberships.first;
          _selectedInstId = m.$1;
          _selectedStudentId = m.$2;
          final data = m.$3;
          final first = (data[StudentSchema.firstName] as String?) ?? '';
          final last = (data[StudentSchema.lastName] as String?) ?? '';
          _selectedDisplayName = [first, last].where((e) => e.trim().isNotEmpty).join(' ').trim();
          // Fetch institution name
          final instDoc = await instRepo.getInstitutionDoc(_selectedInstId!);
          _selectedInstitutionName = (instDoc.data()?[InstitutionRegistrationSchema.institutionName] as String?) ?? _selectedInstId;
          _step = 'password';
        } else {
          // Multiple memberships: go to selection step
          _step = 'select_inst';
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      String friendlyMessage = 'Account lookup failed. Please try again.';
      if (e.toString().contains('index') || e.toString().contains('COLLECTION_GROUP')) {
        friendlyMessage = 'Database setup in progress. Please contact admin or try again later.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyMessage), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseMembership(String instId, String studentId) async {
    setState(() => _busy = true);
    try {
      _selectedInstId = instId;
      _selectedStudentId = studentId;
      final instRepo = FirebaseInstitutionRepository();
      final student = _memberships.firstWhere((m) => m.$1 == instId && m.$2 == studentId);
      final data = student.$3;
      final first = (data[StudentSchema.firstName] as String?) ?? '';
      final last = (data[StudentSchema.lastName] as String?) ?? '';
      _selectedDisplayName = [first, last].where((e) => e.trim().isNotEmpty).join(' ').trim();
      final instDoc = await instRepo.getInstitutionDoc(instId);
      _selectedInstitutionName = (instDoc.data()?[InstitutionRegistrationSchema.institutionName] as String?) ?? instId;
      _step = 'password';
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selection failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneCtrl.text.trim();
    final password = _passCtrl.text.trim();
    setState(() => _busy = true);
    try {
      if (_adminData != null && _selectedInstId != null) {
        final instRepo = FirebaseInstitutionRepository();
        final res = await instRepo.validateInstitutionAdminLoginByPhone(phone: phone, password: password);
        if (res.$1 && res.$2 != null) {
          if (!mounted) return;
          await context.read<AppState>().loginInstitutionAdmin(instId: res.$2!);
          if (!mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil('/institution-admin', (route) => false);
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid password for Institution Admin')));
        }
        return;
      }

      if (_selectedInstId != null) {
        final studentRepo = FirebaseStudentRepository();
        final res = await studentRepo.validateStudentLogin(instId: _selectedInstId!, phone: phone, password: password);
        if (res.$1 && res.$2 != null) {
          if (!mounted) return;
          await context.read<AppState>().loginStudent(instId: _selectedInstId!, studentId: res.$2!, phone: phone);
          if (!mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil('/student', (route) => false);
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid password for selected InstId')));
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please identify and select an account')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_busy) return;
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your phone number to reset')));
      return;
    }
    try {
      final instRepo = FirebaseInstitutionRepository();
      final studentRepo = FirebaseStudentRepository();

      if (_adminData != null && _selectedInstId != null) {
        final instData = _adminData!;
        final instIdSel = (instData[InstitutionRegistrationSchema.id] as String?) ?? (instData[InstitutionRegistrationSchema.uniqueInstitutionId] as String?) ?? '';
        final email = instData[InstitutionRegistrationSchema.email] as String? ?? '';
        if (!mounted) return;
        final ok = await showDialog<bool>(context: context, builder: (_) => OtpResetDialog(role: 'institution_admin', instId: instIdSel, phone: phone, toEmail: email));
        if (ok == true && mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated. Please sign in.'))); }
        return;
      }

      if (_selectedInstId != null && _selectedStudentId != null) {
        final dataTuple = _memberships.firstWhere((m) => m.$1 == _selectedInstId && m.$2 == _selectedStudentId);
        final data = dataTuple.$3;
        final email = data[StudentSchema.email] as String? ?? '';
        final ok = await showDialog<bool>(context: context, builder: (_) => OtpResetDialog(role: 'student', instId: _selectedInstId!, phone: phone, toEmail: email, studentId: _selectedStudentId));
        if (ok == true && mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated. Please sign in.'))); }
        return;
      }

      // Fallback: attempt auto-detect similar to before
      final instFuture = instRepo.findApprovedByPhone(phone);
      final studentFuture = studentRepo.findStudentGlobalByPhone(phone: phone);
      final instData = await instFuture;
      final studentTuple = await studentFuture;
      final bool hasInst = instData != null;
      final bool hasStudent = studentTuple.$1 != null && studentTuple.$2 != null && studentTuple.$3 != null;

      if (!hasInst && !hasStudent) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No approved account found for this phone')));
        return;
      }

      if (hasInst) {
        final instIdSel = (instData[InstitutionRegistrationSchema.id] as String?) ?? (instData[InstitutionRegistrationSchema.uniqueInstitutionId] as String?) ?? '';
        final email = instData[InstitutionRegistrationSchema.email] as String? ?? '';
        if (!mounted) return;
        final ok = await showDialog<bool>(context: context, builder: (_) => OtpResetDialog(role: 'institution_admin', instId: instIdSel, phone: phone, toEmail: email));
        if (ok == true && mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated. Please sign in.'))); }
        return;
      }

      if (hasStudent) {
        final instIdSel = studentTuple.$1!; final studentId = studentTuple.$2!; final data = studentTuple.$3!;
        final email = data[StudentSchema.email] as String? ?? '';
        if (!mounted) return;
        final ok = await showDialog<bool>(context: context, builder: (_) => OtpResetDialog(role: 'student', instId: instIdSel, phone: phone, toEmail: email, studentId: studentId));
        if (ok == true && mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated. Please sign in.'))); }
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset failed: $e'), backgroundColor: Colors.red));
    }
  }

  void _resetFlow() {
    setState(() {
      _adminData = null;
      _memberships = const [];
      _selectedInstId = null;
      _selectedStudentId = null;
      _selectedInstitutionName = null;
      _selectedDisplayName = null;
      _passCtrl.clear();
      _step = 'identify';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sign in', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_step == 'identify') ...[
                    TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone, color: Colors.blue), border: OutlineInputBorder()), keyboardType: TextInputType.phone, autofocus: true, textInputAction: TextInputAction.done, onFieldSubmitted: (_) => _identify(), validator: _required),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: FilledButton.icon(onPressed: _busy ? null : _identify, icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right), label: Text(_busy ? 'Checking...' : 'Continue'))),
                    ]),
                    const SizedBox(height: 8),
                    Text('Enter your mobile number to continue. We will detect your account and prompt for password.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ]
                  else if (_step == 'select_inst') ...[
                    Row(children: [
                      Expanded(child: Text('Select your Institution', style: Theme.of(context).textTheme.titleSmall)),
                      TextButton.icon(onPressed: _busy ? null : _resetFlow, icon: const Icon(Icons.edit, color: Colors.blue), label: const Text('Change mobile')),
                    ]),
                    const SizedBox(height: 8),
                    _MembershipList(memberships: _memberships, onChoose: _busy ? null : _chooseMembership),
                  ]
                  else if (_step == 'password') ...[
                    Row(children: [
                      Expanded(child: Text(_adminData != null ? 'Institution Admin' : 'Student', style: Theme.of(context).textTheme.titleSmall)),
                      TextButton.icon(onPressed: _busy ? null : _resetFlow, icon: const Icon(Icons.edit, color: Colors.blue), label: const Text('Change mobile')),
                    ]),
                    const SizedBox(height: 8),
                    if (_adminData != null) _AccountSummary(icon: Icons.apartment, primary: _selectedInstitutionName ?? '', secondary: _selectedDisplayName ?? '', tertiary: 'Mobile: ${_phoneCtrl.text.trim()}'),
                    if (_adminData == null) _AccountSummary(icon: Icons.school, primary: _selectedDisplayName ?? '', secondary: (_selectedInstitutionName ?? _selectedInstId ?? ''), tertiary: 'Mobile: ${_phoneCtrl.text.trim()}'),
                    const SizedBox(height: 12),
                    TextFormField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline, color: Colors.blue), border: OutlineInputBorder()), validator: _required, obscureText: true, textInputAction: TextInputAction.done, onFieldSubmitted: (_) => _login()),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _login, icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login), label: Text(_busy ? 'Signing in...' : 'Sign in'))),
                    TextButton(onPressed: _busy ? null : _forgotPassword, child: const Text('Forgot password?')),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MembershipList extends StatelessWidget {
  final List<(String instId, String studentId, Map<String, dynamic> data)> memberships;
  final Future<void> Function(String instId, String studentId)? onChoose;
  const _MembershipList({required this.memberships, required this.onChoose});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final m in memberships)
        _MembershipTile(instId: m.$1, studentId: m.$2, data: m.$3, onChoose: onChoose),
    ]);
  }
}

class _MembershipTile extends StatelessWidget {
  final String instId; final String studentId; final Map<String, dynamic> data; final Future<void> Function(String instId, String studentId)? onChoose;
  const _MembershipTile({required this.instId, required this.studentId, required this.data, required this.onChoose});
  @override
  Widget build(BuildContext context) {
    final first = (data[StudentSchema.firstName] as String?) ?? '';
    final last = (data[StudentSchema.lastName] as String?) ?? '';
    final name = [first, last].where((e) => e.trim().isNotEmpty).join(' ').trim();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
      child: ListTile(
        leading: const Icon(Icons.school, color: Colors.blue),
        title: Text(name.isEmpty ? 'Student' : name),
        subtitle: Text('InstId: $instId\nSelect to continue'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: onChoose == null ? null : () => onChoose!(instId, studentId),
      ),
    );
  }
}

class _AccountSummary extends StatelessWidget {
  final IconData icon; final String primary; final String secondary; final String? tertiary;
  const _AccountSummary({required this.icon, required this.primary, required this.secondary, this.tertiary});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(primary, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(secondary, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (tertiary != null && tertiary!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(tertiary!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]
        ])),
      ]),
    );
  }
}
