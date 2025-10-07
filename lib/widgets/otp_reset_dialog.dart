import 'package:flutter/material.dart';
import 'package:institutation_payment_system/services/otp_repository.dart';
import 'package:institutation_payment_system/services/firebase_institution_repository.dart';
import 'package:institutation_payment_system/services/student_repository.dart';
import 'package:institutation_payment_system/widgets/responsive_dialog.dart';

class OtpResetDialog extends StatefulWidget {
  final String role; // 'institution_admin' | 'student'
  final String instId;
  final String phone;
  final String toEmail;
  final String? studentId; // required for student role
  const OtpResetDialog({super.key, required this.role, required this.instId, required this.phone, required this.toEmail, this.studentId});

  @override
  State<OtpResetDialog> createState() => _OtpResetDialogState();
}

class _OtpResetDialogState extends State<OtpResetDialog> {
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _requested = false;
  bool _verifying = false;
  String? _requestId;
  String? _debugOtp; // show in UI for demo only
  String? _error;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    setState(() { _error = null; });
    try {
      final otpRepo = OtpRepository();
      final result = await otpRepo.requestOtp(role: widget.role, instId: widget.instId, phone: widget.phone, email: widget.toEmail);
      setState(() { _requested = true; _requestId = result.$2; _debugOtp = result.$1; });
    } catch (e) {
      setState(() { _error = 'Failed to request OTP: $e'; });
    }
  }

  Future<void> _verifyAndUpdate() async {
    if ((_requestId ?? '').isEmpty) return;
    final otp = _otpCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final conf = _confirmCtrl.text.trim();
    if (otp.length < 4) { setState(() { _error = 'Enter the 6-digit OTP'; }); return; }
    if (pass.isEmpty || pass.length < 6) { setState(() { _error = 'Password must be at least 6 characters'; }); return; }
    if (pass != conf) { setState(() { _error = 'Passwords do not match'; }); return; }
    setState(() { _verifying = true; _error = null; });
    try {
      final ok = await OtpRepository().verifyOtp(requestId: _requestId!, otp: otp);
      if (!ok) { setState(() { _error = 'Invalid or expired OTP'; _verifying = false; }); return; }
      if (widget.role == 'institution_admin') {
        await FirebaseInstitutionRepository().setInstitutionAdminPassword(instId: widget.instId, newPassword: pass);
      } else {
        final sid = widget.studentId;
        if (sid == null) { throw Exception('Student not found'); }
        await FirebaseStudentRepository().setStudentPasswordById(instId: widget.instId, studentId: sid, newPassword: pass);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() { _error = 'Failed to reset password: $e'; });
    } finally { if (mounted) setState(() { _verifying = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_requested) ...[
            Text('We will send a 6-digit OTP to:\n${widget.toEmail}', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _request, icon: const Icon(Icons.mark_email_unread), label: const Text('Send OTP to email')),
          ] else ...[
            Text('An OTP has been sent to ${widget.toEmail}. Please enter the OTP and set a new password.'),
            const SizedBox(height: 8),
            TextField(controller: _otpCtrl, decoration: const InputDecoration(labelText: 'OTP', border: OutlineInputBorder(), prefixIcon: Icon(Icons.pin, color: Colors.blue))),
            const SizedBox(height: 8),
            TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'New password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline, color: Colors.blue)), obscureText: true),
            const SizedBox(height: 8),
            TextField(controller: _confirmCtrl, decoration: const InputDecoration(labelText: 'Confirm password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline, color: Colors.blue)), obscureText: true),
            const SizedBox(height: 8),
            if (_debugOtp != null)
              Text('Demo OTP: $_debugOtp', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange)),
            const SizedBox(height: 4),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _verifying ? null : _verifyAndUpdate, child: _verifying ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Reset password'))),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );

    return AppResponsiveDialog(
      titleText: 'Reset password via OTP',
      content: content,
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Close')),
      ],
    );
  }
}
