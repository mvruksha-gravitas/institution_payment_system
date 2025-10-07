import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';
import 'package:institutation_payment_system/services/student_repository.dart';
import 'package:institutation_payment_system/services/payment_repository.dart';
import 'package:institutation_payment_system/state/app_state.dart';
import 'package:institutation_payment_system/services/receipt_service.dart';
import 'package:institutation_payment_system/services/fee_repository.dart';
import 'package:institutation_payment_system/services/storage_service.dart';
import 'package:institutation_payment_system/widgets/payment_submission_dialog.dart';
import 'package:institutation_payment_system/widgets/receipt_view_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:institutation_payment_system/services/complaint_repository.dart';
import 'package:institutation_payment_system/widgets/branding.dart';

class StudentPortalPage extends StatefulWidget {
  const StudentPortalPage({super.key});
  @override
  State<StudentPortalPage> createState() => _StudentPortalPageState();
}

class _StudentPortalPageState extends State<StudentPortalPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _studentRepo = FirebaseStudentRepository();
  final _paymentRepo = FirebasePaymentRepository();
  final _feeRepo = FirebaseFeeRepository();
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _fees = [];
  int _myComplaintsCount = 0;
  bool _loading = true;
  String? _instName; String? _instAdmin; String? _instAddress;

  String get _instId => (context.read<AppState>().user as StudentSessionUser).instId;
  String get _studentId => (context.read<AppState>().user as StudentSessionUser).studentId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      if (app.initialized && app.isStudent && mounted) {
        _refresh();
      }
    });
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final studentDoc = await FirebaseFirestore.instance.collection(InstitutionRegistrationSchema.collectionName).doc(_instId).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(_studentId).get();
      final instDoc = await FirebaseFirestore.instance.collection(InstitutionRegistrationSchema.collectionName).doc(_instId).get();
      final payments = await _paymentRepo.listPayments(instId: _instId);
      final fees = await _feeRepo.listFees(instId: _instId, studentId: _studentId);
      // Complaints count for this student
      final complaints = await FirebaseComplaintRepository().listComplaints(instId: _instId);
      final myCount = complaints.where((c) => (c[ComplaintSchema.studentId] as String?) == _studentId).length;
      if (!mounted) return;
      setState(() {
        _profile = studentDoc.data() ?? <String, dynamic>{};
        _payments = payments.where((p) => p[PaymentSchema.studentId] == _studentId).toList();
        _fees = fees;
        _myComplaintsCount = myCount;
        _instName = (instDoc.data()?[InstitutionRegistrationSchema.institutionName] as String?)?.trim();
        _instAdmin = (instDoc.data()?[InstitutionRegistrationSchema.personName] as String?)?.trim();
        _instAddress = (instDoc.data()?['address'] as String?)?.trim();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _markStudentFeePaid(Map<String, dynamic> fee) async {
    try {
      final amount = fee[FeeItemSchema.amount] as num? ?? 0;
      final label = (fee[FeeItemSchema.type] == FeeItemSchema.typeMonthly) ? (fee[FeeItemSchema.label] as String? ?? 'Monthly Fee') : (fee[FeeItemSchema.label] as String? ?? 'Other charge');
      final result = await showDialog<PaymentSubmissionResult>(context: context, builder: (ctx) => const PaymentSubmissionDialog(title: 'Submit Payment Details', showAdminHint: false));
      if (result == null) return;
      String? proofUrl;
      if (result.proofBytes != null && result.proofExtension != null) {
        proofUrl = await FirebaseStorageService().uploadPaymentProof(instId: _instId, studentId: _studentId, feeItemId: fee[FeeItemSchema.id] as String, data: result.proofBytes!, fileExtension: result.proofExtension!);
      }
      await _paymentRepo.addPendingPayment(instId: _instId, studentId: _studentId, amount: amount, method: result.method, feeItemId: fee[FeeItemSchema.id] as String?, feeLabel: label, note: result.note, proofUrl: proofUrl);
      await _feeRepo.submitFeeForConfirmation(instId: _instId, studentId: _studentId, feeItemId: fee[FeeItemSchema.id] as String, method: result.method, note: result.note, proofUrl: proofUrl);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted for Institution Admin confirmation')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _updateContact() async {
    final phoneCtrl = TextEditingController(text: _profile?[StudentSchema.phoneNumber] as String? ?? '');
    final emailCtrl = TextEditingController(text: _profile?[StudentSchema.email] as String? ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Contact'),
        content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone number', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
          const SizedBox(height: 8),
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))],
      ),
    );
    if (saved != true) return;
    await _studentRepo.updateStudentContact(instId: _instId, studentId: _studentId, phone: phoneCtrl.text.trim(), email: emailCtrl.text.trim());
    await _refresh();
  }

  Future<void> _resetPassword() async {
    await _studentRepo.resetStudentPassword(instId: _instId, studentId: _studentId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset. Check SMS/WhatsApp (simulated).')));
  }

  Future<void> _updatePhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final name = file.name.toLowerCase();
      String ext = 'jpg';
      if (name.endsWith('.png')) ext = 'png'; else if (name.endsWith('.webp')) ext = 'webp'; else if (name.endsWith('.jpeg')) ext = 'jpg';
      final url = await FirebaseStorageService().uploadStudentProfilePhoto(instId: _instId, studentId: _studentId, data: bytes, fileExtension: ext);
      await _studentRepo.setStudentPhotoUrl(instId: _instId, studentId: _studentId, photoUrl: url);
      await _refresh();
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating photo: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _payNow() async {
    final amount = (_profile?[StudentSchema.feeAmount] as num? ?? 0);
    if (amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No fee amount set by institution')));
      return;
    }
    await _paymentRepo.addPayment(instId: _instId, studentId: _studentId, amount: amount, method: 'online', roomNumber: _profile?[StudentSchema.roomNumber] as String?);
    await _refresh();
  }

  Future<void> _raiseComplaint() async {
    final subjCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Raise Complaint'),
      content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: subjCtrl, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: msgCtrl, decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()), maxLines: 4),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
      ],
    ));
    if (ok != true) { subjCtrl.dispose(); msgCtrl.dispose(); return; }
    final subject = subjCtrl.text.trim();
    final message = msgCtrl.text.trim();
    subjCtrl.dispose(); msgCtrl.dispose();
    if (subject.isEmpty || message.isEmpty) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subject and Message are required'))); return; }
    try {
      final name = '${_profile?[StudentSchema.firstName] ?? ''} ${_profile?[StudentSchema.lastName] ?? ''}'.trim();
      final room = _profile?[StudentSchema.roomNumber] as String?;
      await FirebaseComplaintRepository().addComplaint(instId: _instId, studentId: _studentId, studentName: name.isEmpty ? (_profile?[StudentSchema.phoneNumber] as String? ?? 'Student') : name, roomNumber: room, subject: subject, message: message);
      await _refresh();
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complaint submitted')));
    } catch (e) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _openMyComplaintsList() async {
    try {
      final list = await FirebaseComplaintRepository().listComplaints(instId: _instId);
      final mine = list.where((c) => (c[ComplaintSchema.studentId] as String?) == _studentId).toList();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('My Complaints'),
          content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 560), child: mine.isEmpty ? const Text('No complaints yet') : ListView.separated(
            shrinkWrap: true,
            itemCount: mine.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = mine[i];
              final ts = (c[ComplaintSchema.createdAt] as Timestamp?)?.toDate();
              return ListTile(
                leading: const Icon(Icons.feedback, color: Colors.orange),
                title: Text(c[ComplaintSchema.subject] as String? ?? ''),
                subtitle: Text('${c[ComplaintSchema.message] as String? ?? ''}\n${ts != null ? '${ts.day}/${ts.month}/${ts.year}' : ''}'),
                isThreeLine: true,
                trailing: Text((c[ComplaintSchema.status] as String? ?? '').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
              );
            },
          )),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load complaints: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!app.isStudent) {
      return const _UnauthorizedScaffold(role: 'Student', loginRoute: '/login');
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.of(context).size.width < 600 ? 84 : 96,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const BrandedHeaderLine(),
          const SizedBox(height: 2),
          _StudentWelcomeBannerTitle(
            studentName: '${_profile?[StudentSchema.firstName] ?? ''} ${_profile?[StudentSchema.lastName] ?? ''}'.trim(),
            instName: _instName,
            address: _instAddress,
          ),
        ]),
        actions: [
          IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Raise Complaint', onPressed: _raiseComplaint, icon: const Icon(Icons.report, color: Colors.orange)),
          IconButton(onPressed: () => context.read<AppState>().signOut().then((_) => Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false)), icon: const Icon(Icons.logout, color: Colors.red))
        ],
        bottom: TabBar(isScrollable: true, controller: _tab, tabs: const [Tab(text: 'Dashboard'), Tab(text: 'Payments'), Tab(text: 'Profile')]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tab, children: [
              _StudentDashboardTab(
                profile: _profile ?? const {},
                fees: _fees,
                payments: _payments,
                complaintsCount: _myComplaintsCount,
                onGoToPayments: () => _tab.animateTo(1),
                onRaiseComplaint: _raiseComplaint,
                onViewComplaints: _openMyComplaintsList,
              ),
              _StudentPaymentsTab(payments: _payments, fees: _fees, instId: _instId, studentProfile: _profile ?? const {}, onMarkPaid: _markStudentFeePaid),
              _ProfileTab(profile: _profile ?? const {}, onUpdateContact: _updateContact, onResetPassword: _resetPassword, onUpdatePhoto: _updatePhoto),
            ]),
      bottomNavigationBar: const BrandedFooter(),
    );
  }
}

class _UnauthorizedScaffold extends StatelessWidget {
  final String role; final String loginRoute;
  const _UnauthorizedScaffold({required this.role, required this.loginRoute});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandedHeaderLine()),
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline, color: Colors.blue, size: 32),
              const SizedBox(height: 8),
              Text('Not signed in as $role', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: () => Navigator.of(context).pushReplacementNamed(loginRoute), icon: const Icon(Icons.login), label: const Text('Go to Login')),
            ]),
          ),
        ),
      ),
    );
  }
}


class _ProfileTab extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onUpdateContact;
  final VoidCallback onResetPassword;
  final Future<void> Function() onUpdatePhoto;
  const _ProfileTab({required this.profile, required this.onUpdateContact, required this.onResetPassword, required this.onUpdatePhoto});
  @override
  Widget build(BuildContext context) {
    final fullName = '${profile[StudentSchema.firstName] ?? ''} ${profile[StudentSchema.lastName] ?? ''}'.trim();
    final status = profile[StudentSchema.status] as String? ?? '';
    final photoUrl = profile[StudentSchema.photoUrl] as String?;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(12), child: LayoutBuilder(builder: (ctx, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        final button = OutlinedButton.icon(onPressed: onUpdatePhoto, icon: const Icon(Icons.camera_alt, color: Colors.blue), label: const Text('Update Photo'));
        if (isNarrow) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 28, backgroundColor: Colors.blue.withValues(alpha: 0.1), backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null, child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, color: Colors.blue) : null),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fullName.isEmpty ? (profile[StudentSchema.phoneNumber] as String? ?? '') : fullName, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Status: $status', overflow: TextOverflow.ellipsis),
              ])),
            ]),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: button),
          ]);
        }
        return Row(children: [
          CircleAvatar(radius: 28, backgroundColor: Colors.blue.withValues(alpha: 0.1), backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null, child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, color: Colors.blue) : null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fullName.isEmpty ? (profile[StudentSchema.phoneNumber] as String? ?? '') : fullName, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('Status: $status', overflow: TextOverflow.ellipsis),
          ])),
          button
        ]);
      }))),
      const SizedBox(height: 8),
      _FieldTile(label: 'Phone', value: profile[StudentSchema.phoneNumber] as String? ?? ''),
      _FieldTile(label: 'Email', value: profile[StudentSchema.email] as String? ?? ''),
      _FieldTile(label: 'Aadhaar', value: profile[StudentSchema.aadhaar] as String? ?? ''),
      _FieldTile(label: 'Parent name', value: profile[StudentSchema.parentName] as String? ?? ''),
      _FieldTile(label: 'Parent phone', value: profile[StudentSchema.parentPhone] as String? ?? ''),
      _FieldTile(label: 'Address', value: profile[StudentSchema.address] as String? ?? ''),
      _FieldTile(label: 'Occupation', value: profile[StudentSchema.occupation] as String? ?? ''),
      _FieldTile(label: 'College/Course/Class', value: profile[StudentSchema.collegeCourseClass] as String? ?? ''),
      _FieldTile(label: 'Room number', value: profile[StudentSchema.roomNumber] as String? ?? '-'),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: onUpdateContact, icon: const Icon(Icons.edit), label: const Text('Update Contact'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: onResetPassword, icon: const Icon(Icons.lock_reset), label: const Text('Reset Password'))),
      ]),
      const SizedBox(height: 8),
    ]);
  }
}

class _FieldTile extends StatelessWidget {
  final String label; final String value;
  const _FieldTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return ListTile(leading: const Icon(Icons.chevron_right), title: Text(label), subtitle: Text(value));
  }
}

class _StudentWelcomeBannerTitle extends StatelessWidget {
  final String studentName; final String? instName; final String? address;
  const _StudentWelcomeBannerTitle({required this.studentName, required this.instName, required this.address});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onAppBar = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final titleStyle = theme.textTheme.titleLarge?.copyWith(color: onAppBar, fontWeight: FontWeight.w700);
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(color: onAppBar.withValues(alpha: 0.9));
    final addressStyle = theme.textTheme.bodySmall?.copyWith(color: onAppBar.withValues(alpha: 0.85));
    final displayName = studentName.isNotEmpty ? studentName : 'Student';
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome', style: theme.textTheme.labelSmall?.copyWith(color: onAppBar.withValues(alpha: 0.9))),
        const SizedBox(height: 2),
        Text(displayName, style: titleStyle, overflow: TextOverflow.ellipsis),
        if (instName != null && instName!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(instName!, style: subtitleStyle, overflow: TextOverflow.ellipsis)),
        if (address != null && address!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(address!, style: addressStyle, overflow: TextOverflow.ellipsis, maxLines: 2)),
      ]),
    );
  }
}

class _StudentDashboardTab extends StatelessWidget {
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> fees;
  final List<Map<String, dynamic>> payments;
  final int complaintsCount;
  final VoidCallback onGoToPayments;
  final Future<void> Function() onRaiseComplaint;
  final Future<void> Function() onViewComplaints;
  const _StudentDashboardTab({required this.profile, required this.fees, required this.payments, required this.complaintsCount, required this.onGoToPayments, required this.onRaiseComplaint, required this.onViewComplaints});
  @override
  Widget build(BuildContext context) {
    final room = profile[StudentSchema.roomNumber] as String?;
    final bed = profile[StudentSchema.bedNumber] as int?;
    final pendingFees = fees.where((f) => (f[FeeItemSchema.status] as String? ?? 'pending') != 'paid').toList();
    DateTime? nextDue;
    for (final f in pendingFees) {
      final ts = f[FeeItemSchema.dueDate] as Timestamp?; final d = ts?.toDate();
      if (d == null) continue; if (nextDue == null || d.isBefore(nextDue)) nextDue = d;
    }
    final pendingCount = pendingFees.length;
    final nextDueStr = nextDue == null ? '-' : '${nextDue!.day}/${nextDue!.month}/${nextDue!.year}';

    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth;
      int cross = 1;
      if (w >= 1100) cross = 4; else if (w >= 800) cross = 3; else if (w >= 600) cross = 2;
      return ListView(padding: const EdgeInsets.all(12), children: [
        GridView.count(
          crossAxisCount: cross,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 3.2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _DashboardInfoTile(
              color: Colors.blue,
              icon: Icons.meeting_room,
              title: 'Room',
              value: '${room ?? '-'}${bed != null ? ' • Bed $bed' : ''}',
              subtitle: 'Your accommodation',
              onTap: () {},
            ),
            _DashboardInfoTile(
              color: Colors.orange,
              icon: Icons.request_quote,
              title: 'Pending/Upcoming',
              value: '$pendingCount items',
              subtitle: 'Next due: $nextDueStr',
              onTap: onGoToPayments,
            ),
            _DashboardInfoTile(
              color: Colors.purple,
              icon: Icons.notifications,
              title: 'Notifications',
              value: '—',
              subtitle: 'No new notifications',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No notifications yet'))),
            ),
            _DashboardInfoTile(
              color: Colors.green,
              icon: Icons.feedback,
              title: 'Feedback & Complaints',
              value: complaintsCount > 0 ? '$complaintsCount submitted' : 'Tap to submit',
              subtitle: 'Let us know your issue',
              onTap: () async {
                await showModalBottomSheet(
                  context: context,
                  showDragHandle: true,
                  builder: (bctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { Navigator.pop(bctx); onRaiseComplaint(); }, icon: const Icon(Icons.add_comment), label: const Text('Raise Complaint'))),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () { Navigator.pop(bctx); onViewComplaints(); }, icon: const Icon(Icons.list), label: const Text('View My Complaints'))),
                    ],
                  ))),
                );
              },
            ),
          ],
        ),
      ]);
    });
  }
}

class _DashboardInfoTile extends StatelessWidget {
  final Color color; final IconData icon; final String title; final String value; final String subtitle; final VoidCallback onTap;
  const _DashboardInfoTile({required this.color, required this.icon, required this.title, required this.value, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
        ])),
      ])),
    ));
  }
}

class _StudentPaymentsTab extends StatelessWidget {
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> fees;
  final String instId;
  final Map<String, dynamic> studentProfile;
  final Future<void> Function(Map<String, dynamic> fee) onMarkPaid;
  const _StudentPaymentsTab({required this.payments, required this.fees, required this.instId, required this.studentProfile, required this.onMarkPaid});
  @override
  Widget build(BuildContext context) {
    final room = studentProfile[StudentSchema.roomNumber] as String?;
    final bed = studentProfile[StudentSchema.bedNumber] as int?;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.meeting_room, color: Colors.blue),
            title: Text('Room: ${room ?? '-'}${bed != null ? ' • Bed: $bed' : ''}'),
            subtitle: const Text('Your current accommodation'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: const [Icon(Icons.request_quote, color: Colors.orange), SizedBox(width: 8), Text('Assigned Charges')]),
              const SizedBox(height: 8),
              if (fees.isEmpty) const Text('No assigned charges yet') else ...fees.map((f) {
                final label = f[FeeItemSchema.label] as String? ?? '';
                final amt = (f[FeeItemSchema.amount] as num? ?? 0).toStringAsFixed(2);
                final type = f[FeeItemSchema.type] as String? ?? FeeItemSchema.typeMonthly;
                final dueTs = f[FeeItemSchema.dueDate] as Timestamp?; final due = dueTs?.toDate();
                final dueStr = due == null ? '-' : '${due.day}/${due.month}/${due.year}';
                final status = f[FeeItemSchema.status] as String? ?? 'pending';
                final paymentId = f[FeeItemSchema.paymentId] as String?;
                final isPaid = status == 'paid';
                final isToConfirm = status == 'to_confirm';
                final color = isPaid ? Colors.green : (isToConfirm ? Colors.blue : Colors.orange);
                final bg = isPaid ? Colors.green.withValues(alpha: 0.10) : (isToConfirm ? Colors.blue.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.10));
                final amtNum = f[FeeItemSchema.amount] as num? ?? 0;
                final prevPaid = isPaid ? amtNum : 0;
                final pendingAmt = amtNum - prevPaid;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    leading: Icon(type == FeeItemSchema.typeMonthly ? Icons.calendar_month : Icons.attach_money, color: color),
                    title: Text('$label • ₹$amt'),
                    subtitle: Text('Due: $dueStr • ${type == FeeItemSchema.typeMonthly ? ((f[FeeItemSchema.recurring] as bool? ?? false) ? "Monthly (Recurring)" : "Monthly") : "Other"} • Paid: ₹${prevPaid.toStringAsFixed(2)} • Pending: ₹${pendingAmt.toStringAsFixed(2)} • ${isToConfirm ? 'TO BE CONFIRMED BY INSTITUTION ADMIN' : status.toUpperCase()}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (!isPaid && !isToConfirm) IconButton(tooltip: 'Mark as Paid', onPressed: () => onMarkPaid(f), icon: const Icon(Icons.check_circle, color: Colors.green)),
                      if (paymentId != null && isPaid) IconButton(tooltip: 'View Receipt', icon: const Icon(Icons.visibility, color: Colors.blue), onPressed: () async {
                        final payDoc = await FirebaseFirestore.instance.collection(InstitutionRegistrationSchema.collectionName).doc(instId).collection(InstitutionRegistrationSchema.paymentsSubcollection).doc(paymentId).get();
                        final data = payDoc.data();
                        if (data != null && context.mounted) {
                          await showDialog(context: context, builder: (ctx) => ReceiptViewDialog.forPayment(instId: instId, payment: data));
                        }
                      }),
                    ]),
                  ),
                );
              })
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: const [Icon(Icons.receipt_long, color: Colors.green), SizedBox(width: 8), Text('Payments')]),
              const SizedBox(height: 8),
              if (payments.isEmpty) const Text('No payments yet') else ...payments.map((p) {
                final ts = (p[PaymentSchema.paidAt] as Timestamp?)?.toDate();
                final created = (p[PaymentSchema.createdAt] as Timestamp?)?.toDate();
                final label = p[PaymentSchema.feeLabel] as String?;
                final status = p[PaymentSchema.status] as String? ?? 'paid';
                final isPaid = status == 'paid';
                final statusLabel = status == 'pending' ? 'TO BE CONFIRMED BY INSTITUTION ADMIN' : status.toUpperCase();
                return ListTile(
                  leading: Icon(Icons.receipt, color: isPaid ? Colors.green : Colors.blue),
                  title: Text('₹${(p[PaymentSchema.amount] as num? ?? 0).toString()} • ${p[PaymentSchema.method]} • $statusLabel'),
                  subtitle: Text(isPaid
                      ? '${label != null ? '$label • ' : ''}Receipt: ${p[PaymentSchema.receiptNo]} • ${ts != null ? '${ts.day}/${ts.month}/${ts.year}' : ''}'
                      : '${label != null ? '$label • ' : ''}Submitted: ${created != null ? '${created.day}/${created.month}/${created.year}' : ''}'),
                  trailing: isPaid ? IconButton(tooltip: 'View Receipt', icon: const Icon(Icons.visibility, color: Colors.blue), onPressed: () async {
                    await showDialog(context: context, builder: (ctx) => ReceiptViewDialog.forPayment(instId: instId, payment: p));
                  }) : null,
                );
              })
            ]),
          ),
        )
      ],
    );
  }
}
