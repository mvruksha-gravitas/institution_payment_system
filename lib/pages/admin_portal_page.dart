import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:institutation_payment_system/models/institution_models.dart';
import 'package:institutation_payment_system/services/firebase_institution_repository.dart';
import 'package:institutation_payment_system/services/student_repository.dart';
import 'package:institutation_payment_system/services/admin_repository.dart';
import 'package:institutation_payment_system/services/support_ticket_repository.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';
import 'package:institutation_payment_system/services/storage_service.dart';
import 'package:institutation_payment_system/state/app_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:institutation_payment_system/widgets/branding.dart';

class _LocalAttachment {
  final Uint8List bytes; final String extension;
  _LocalAttachment(this.bytes, this.extension);
}


class AdminPortalPage extends StatefulWidget {
  const AdminPortalPage({super.key});

  @override
  State<AdminPortalPage> createState() => _AdminPortalPageState();
}

class _AdminPortalPageState extends State<AdminPortalPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = FirebaseInstitutionRepository();
  final _studentRepo = FirebaseStudentRepository();
  final _adminRepo = AdminRepository();
  List<InstitutionRequestModel> _pending = [];
  List<InstitutionRequestModel> _institutions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final pending = await _repo.getPendingRequests();
      final institutions = await _repo.getApprovedInstitutions();
      if (!mounted) return;
      setState(() {
        _pending = pending;
        _institutions = institutions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  Future<void> _approve(String documentId) async {
    try {
      final result = await _repo.approveInstitutionRequest(documentId: documentId, adminNotes: 'Approved by admin');
      final instId = result.$1; final creds = result.$2;
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      await showDialog(context: context, builder: (ctx) => _EmailPreviewDialog(toEmail: 'n/a', instId: instId, username: creds.username, password: creds.password));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error approving request: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _reject(String documentId) async {
    try {
      await _repo.rejectInstitutionRequest(
        documentId: documentId,
        adminNotes: 'Rejected by admin',
      );
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request rejected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting request: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!app.isAdmin) {
      return const _UnauthorizedScaffold(role: 'Super Admin', loginRoute: '/admin-login');
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.of(context).size.width < 600 ? 80 : 92,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          BrandedHeaderLine(),
          SizedBox(height: 2),
          Text('Admin Portal'),
        ]),
        actions: [
          IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
          IconButton(onPressed: () async { final controller = TextEditingController(); final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Change Admin Password'), content: TextField(controller: controller, obscureText: true, decoration: const InputDecoration(labelText: 'New password')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Change'))])); if (ok == true) { await _adminRepo.changePassword(newPassword: controller.text.trim()); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated'))); } } }, icon: const Icon(Icons.password)),
          IconButton(onPressed: () async { await context.read<AppState>().signOut(); if (mounted) Navigator.of(context).pushReplacementNamed('/admin-login'); }, icon: const Icon(Icons.logout)),
        ],
        bottom: TabBar(isScrollable: true, controller: _tabController, tabs: const [Tab(text: 'Pending Requests'), Tab(text: 'Institutions'), Tab(text: 'Tickets')]),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _PendingList(pending: _pending, onApprove: _approve, onReject: _reject),
                    _InstitutionsList(institutions: _institutions, studentRepo: _studentRepo, repo: _repo, onChanged: _refresh),
                    const _TicketsTab(),
                  ],
                ),
              ),
      ),
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

class _PendingList extends StatelessWidget {
  final List<InstitutionRequestModel> pending;
  final Future<void> Function(String) onApprove;
  final Future<void> Function(String) onReject;
  const _PendingList({required this.pending, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty) {
      return const Center(child: Text('No pending requests'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final p = pending[index];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.apartment, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text(p.institutionName, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis, softWrap: true)),
              ]),
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.person_outline, label: 'Contact', value: p.personName),
              _InfoRow(icon: Icons.phone, label: 'Phone', value: p.phoneNumber),
              _InfoRow(icon: Icons.email_outlined, label: 'Email', value: p.email),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(onPressed: () => onReject(p.id), icon: const Icon(Icons.close, color: Colors.red), label: const Text('Reject')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(onPressed: () => onApprove(p.id), icon: const Icon(Icons.check), label: const Text('Approve')),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

class _TicketsTab extends StatefulWidget {
  const _TicketsTab();
  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab> {
  final _repo = FirebaseSupportTicketRepository();
  String _status = 'all';
  String _priority = 'all';
  String _category = 'all';
  String _query = '';
  bool _loading = true;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _repo.listAllTickets(status: _status);
    List<Map<String, dynamic>> list = data;
    if (_priority != 'all') list = list.where((t) => (t[SupportTicketSchema.priority] as String?) == _priority).toList();
    if (_category != 'all') list = list.where((t) => (t[SupportTicketSchema.category] as String?) == _category).toList();
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) list = list.where((t) => ((t[SupportTicketSchema.subject] as String?) ?? '').toLowerCase().contains(q) || ((t[SupportTicketSchema.instId] as String?) ?? '').toLowerCase().contains(q)).toList();
    if (!mounted) return; setState(() { _tickets = list; _loading = false; });
  }

  Future<void> _assign(String ticketId, String who) async { await _repo.assignTo(ticketId: ticketId, assignee: who); await _load(); }
  Future<void> _setStatus(String ticketId, String status) async { await _repo.setStatus(ticketId: ticketId, status: status); await _load(); }

  Color _statusColor(String s) {
    switch (s) {
      case 'new': return Colors.blue;
      case 'acknowledged': return Colors.indigo;
      case 'in_progress': return Colors.orange;
      case 'resolved': return Colors.green;
      case 'closed': return Colors.grey;
      case 'reopened': return Colors.purple;
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(width: 220, child: TextField(onChanged: (v) { setState(() => _query = v); _load(); }, decoration: const InputDecoration(labelText: 'Search subject/InstId', border: OutlineInputBorder(), prefixIcon: Icon(Icons.search, color: Colors.blue)) )),
                DropdownButton<String>(value: _status, items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'new', child: Text('New')),
                  DropdownMenuItem(value: 'acknowledged', child: Text('Acknowledged')),
                  DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  DropdownMenuItem(value: 'reopened', child: Text('Reopened')),
                ], onChanged: (v) { setState(() => _status = v ?? 'all'); _load(); }),
                DropdownButton<String>(value: _priority, items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Priority')),
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                ], onChanged: (v) { setState(() => _priority = v ?? 'all'); _load(); }),
                DropdownButton<String>(value: _category, items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Categories')),
                  DropdownMenuItem(value: 'complaint', child: Text('Complaint')),
                  DropdownMenuItem(value: 'feedback', child: Text('Feedback')),
                  DropdownMenuItem(value: 'suggestion', child: Text('Suggestion')),
                  DropdownMenuItem(value: 'technical', child: Text('Technical')),
                  DropdownMenuItem(value: 'enhancement', child: Text('Enhancement')),
                  DropdownMenuItem(value: 'feature', child: Text('Feature')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ], onChanged: (v) { setState(() => _category = v ?? 'all'); _load(); }),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())) else if (_tickets.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No tickets'))) else ...[
            for (final t in _tickets)
              Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: _statusColor((t[SupportTicketSchema.status] as String?) ?? 'new').withValues(alpha: 0.15), child: Icon(Icons.support_agent, color: _statusColor((t[SupportTicketSchema.status] as String?) ?? 'new'))),
                  title: Text((t[SupportTicketSchema.subject] as String?) ?? '-', overflow: TextOverflow.ellipsis),
                  subtitle: Text('Inst: ${t[SupportTicketSchema.instId]} • ${t[SupportTicketSchema.category]} • Priority: ${t[SupportTicketSchema.priority]} • Status: ${t[SupportTicketSchema.status]}', overflow: TextOverflow.ellipsis),
                  trailing: PopupMenuButton<int>(
                    onSelected: (v) async {
                      if (v == 1) {
                        await _assign(t[SupportTicketSchema.id] as String, 'Super Admin');
                      } else if (v == 2) {
                        await _setStatus(t[SupportTicketSchema.id] as String, 'acknowledged');
                      } else if (v == 3) {
                        await _setStatus(t[SupportTicketSchema.id] as String, 'in_progress');
                      } else if (v == 4) {
                        await _setStatus(t[SupportTicketSchema.id] as String, 'resolved');
                      } else if (v == 5) {
                        await _setStatus(t[SupportTicketSchema.id] as String, 'closed');
                      } else if (v == 6) {
                        await _setStatus(t[SupportTicketSchema.id] as String, 'reopened');
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 1, child: Text('Assign to me')),
                      PopupMenuItem(value: 2, child: Text('Mark Acknowledged')),
                      PopupMenuItem(value: 3, child: Text('Mark In Progress')),
                      PopupMenuItem(value: 4, child: Text('Mark Resolved')),
                      PopupMenuItem(value: 5, child: Text('Mark Closed')),
                      PopupMenuItem(value: 6, child: Text('Reopen')),
                    ],
                  ),
                  onTap: () async {
                    await showDialog(context: context, builder: (ctx) => _AdminTicketDetailsDialog(ticket: t));
                    await _load();
                  },
                ),
              )
          ]
        ],
      ),
    );
  }
}

class _AdminTicketDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const _AdminTicketDetailsDialog({required this.ticket});
  @override
  State<_AdminTicketDetailsDialog> createState() => _AdminTicketDetailsDialogState();
}

class _AdminTicketDetailsDialogState extends State<_AdminTicketDetailsDialog> {
  final _repo = FirebaseSupportTicketRepository();
  final _message = TextEditingController();
  String? _statusChange;
  final List<_LocalAttachment> _attachments = [];
  bool _busy = false;
  List<Map<String, dynamic>> _updates = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final u = await _repo.listUpdates(ticketId: widget.ticket[SupportTicketSchema.id] as String);
    if (!mounted) return; setState(() { _updates = u; _loading = false; });
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (f == null) return; final bytes = await f.readAsBytes();
    String ext = 'jpg'; final name = f.name.toLowerCase(); if (name.endsWith('.png')) ext = 'png'; else if (name.endsWith('.webp')) ext = 'webp'; else if (name.endsWith('.jpeg')) ext = 'jpeg';
    setState(() => _attachments.add(_LocalAttachment(bytes, ext)));
  }

  Future<void> _send() async {
    final msg = _message.text.trim();
    if (msg.isEmpty && _statusChange == null && _attachments.isEmpty) return;
    setState(() => _busy = true);
    try {
      final name = 'Super Admin';
      List<String> urls = [];
      if (_attachments.isNotEmpty) {
        final storage = FirebaseStorageService();
        for (final a in _attachments) {
          final url = await storage.uploadSupportAttachment(instId: widget.ticket[SupportTicketSchema.instId] as String, ticketId: widget.ticket[SupportTicketSchema.id] as String, data: a.bytes, fileExtension: a.extension);
          urls.add(url);
        }
      }
      await _repo.addUpdate(ticketId: widget.ticket[SupportTicketSchema.id] as String, authorRole: 'admin', authorName: name, statusChange: _statusChange, message: msg.isEmpty ? (_statusChange != null ? 'Status updated' : 'Attachment') : msg, attachmentUrls: urls);
      _message.clear(); _attachments.clear(); _statusChange = null; await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Update sent')));
    } catch (e) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    return AlertDialog(
      title: const Text('Ticket') ,
      content: SizedBox(width: 640, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((t[SupportTicketSchema.subject] as String?) ?? '-', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text((t[SupportTicketSchema.description] as String?) ?? '-', softWrap: true),
        const Divider(height: 16),
        Text('Updates', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Flexible(child: _loading ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())) : (_updates.isEmpty ? const Text('No updates yet') : ListView.separated(shrinkWrap: true, itemCount: _updates.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (ctx, i) {
          final u = _updates[i];
          final role = (u[SupportUpdateSchema.authorRole] as String?) ?? 'institution_admin';
          final name = (u[SupportUpdateSchema.authorName] as String?) ?? role;
          final msg = (u[SupportUpdateSchema.message] as String?) ?? '';
          final stat = (u[SupportUpdateSchema.statusChange] as String?);
          return ListTile(leading: Icon(role == 'admin' ? Icons.shield : Icons.account_circle, color: Theme.of(context).colorScheme.primary), title: Text(name), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (stat != null) Text('Status: $stat'), if (msg.isNotEmpty) Text(msg)]));
        }))),
        const Divider(height: 16),
        DropdownButtonFormField<String?>(value: _statusChange, items: const [
          DropdownMenuItem(value: null, child: Text('No status change')),
          DropdownMenuItem(value: 'acknowledged', child: Text('Acknowledge')),
          DropdownMenuItem(value: 'in_progress', child: Text('Work in Progress')),
          DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
          DropdownMenuItem(value: 'closed', child: Text('Closed')),
          DropdownMenuItem(value: 'reopened', child: Text('Reopened')),
        ], onChanged: (v) => setState(() => _statusChange = v), decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Status')),
        const SizedBox(height: 8),
        TextField(controller: _message, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Message'), minLines: 2, maxLines: 5),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: _busy ? null : _pick, icon: const Icon(Icons.attach_file, color: Colors.blue), label: const Text('Attach')),
          if (_attachments.isNotEmpty) ...[
            for (int i = 0; i < _attachments.length; i++) Chip(label: Text('Attachment ${i + 1}'), onDeleted: () => setState(() => _attachments.removeAt(i)))
          ]
        ])
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')), FilledButton(onPressed: _busy ? null : _send, child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send'))],
    );
  }
}

class _InstitutionsList extends StatelessWidget {
  final List<InstitutionRequestModel> institutions;
  final FirebaseStudentRepository studentRepo;
  final FirebaseInstitutionRepository repo;
  final Future<void> Function()? onChanged;
  const _InstitutionsList({required this.institutions, required this.studentRepo, required this.repo, this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (institutions.isEmpty) {
      return const Center(child: Text('No approved institutions yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: institutions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final i = institutions[index];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.verified, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(i.institutionName, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                if (i.uniqueInstitutionId != null)
                  Chip(label: Text(i.uniqueInstitutionId!)),
              ]),
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.person_outline, label: 'Contact', value: i.personName),
              _InfoRow(icon: Icons.phone, label: 'Phone', value: i.phoneNumber),
              _InfoRow(icon: Icons.email_outlined, label: 'Email', value: i.email),
              if (i.loginCredentials?.username != null)
                _InfoRow(icon: Icons.lock_outline, label: 'Username', value: i.loginCredentials!.username),
              if (i.approvedAt != null)
                _InfoRow(icon: Icons.calendar_today, label: 'Approved', value: '${i.approvedAt!.day}/${i.approvedAt!.month}/${i.approvedAt!.year}'),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Enabled'),
                const SizedBox(width: 8),
                Switch(value: i.enabled, onChanged: (v) async { final id = i.uniqueInstitutionId ?? i.id; await repo.setInstitutionEnabled(instId: id, enabled: v); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Institution ${v ? 'enabled' : 'disabled'}'))); await onChanged?.call(); }),
              ]),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 480;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FutureBuilder<int>(future: studentRepo.countStudents(instId: i.uniqueInstitutionId ?? i.id), builder: (ctx, snap) => Chip(label: Text('Students: ${snap.data ?? 0}'))),
                    ConstrainedBox(
                      constraints: BoxConstraints(minWidth: isNarrow ? constraints.maxWidth : 0),
                      child: OutlinedButton.icon(onPressed: () async {
                        // Quick export from card (optional before deletion)
                        final id = i.uniqueInstitutionId ?? i.id;
                        try {
                          final students = await studentRepo.listStudents(instId: id);
                          final headers = [
                            'id','inst_id','first_name','last_name','phone_number','email','aadhaar','photo_url','parent_name','parent_phone','address','occupation','college_course_class','terms_accepted','status','enabled','fee_amount','fee_type','fee_due_date','room_number','bed_number','created_at','updated_at'
                          ];
                          String esc(Object? v) {
                            final s = v == null ? '' : v is Timestamp ? v.toDate().toIso8601String() : v.toString();
                            final q = s.replaceAll('"', '""');
                            return '"$q"';
                          }
                          final rows = <String>[];
                          rows.add(headers.map(esc).join(','));
                          for (final d in students) {
                            rows.add([
                              d['id'], d['inst_id'], d['first_name'], d['last_name'], d['phone_number'], d['email'], d['aadhaar'], d['photo_url'], d['parent_name'], d['parent_phone'], d['address'], d['occupation'], d['college_course_class'], d['terms_accepted'], d['status'], d['enabled'], d['fee_amount'], d['fee_type'], d['fee_due_date'], d['room_number'], d['bed_number'], d['created_at'], d['updated_at']
                            ].map(esc).join(','));
                          }
                          final csv = rows.join('\n');
                          final storage = FirebaseStorageService();
                          final fileName = 'students_${id}_export_${DateTime.now().millisecondsSinceEpoch}.csv';
                          final url = await storage.uploadInstitutionExportText(instId: id, data: Uint8List.fromList(utf8.encode(csv)), fileName: fileName, contentType: 'text/csv');
                          if (context.mounted) {
                            await showDialog<void>(
                              context: context,
                              builder: (ctx2) => AlertDialog(
                                title: const Text('Export ready'),
                                content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('Students CSV has been uploaded. Use the link below to download/share:'),
                                  const SizedBox(height: 8),
                                  SelectableText(url, maxLines: 3),
                                ]),
                                actions: [
                                  TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: url)); Navigator.pop(ctx2); }, child: const Text('Copy link')),
                                  TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Close')),
                                ],
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
                          }
                        }
                      }, icon: const Icon(Icons.download, color: Colors.blue), label: const Text('Export Students')),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(minWidth: isNarrow ? constraints.maxWidth : 0),
                      child: OutlinedButton.icon(onPressed: () async {
                        final id = i.uniqueInstitutionId ?? i.id;
                        final controller = TextEditingController();
                        bool obscure = true;
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) {
                            return StatefulBuilder(builder: (ctx, setState) {
                              return AlertDialog(
                                title: const Text('Set Institution Admin Password'),
                                content: TextField(
                                  controller: controller,
                                  obscureText: obscure,
                                  decoration: InputDecoration(
                                    labelText: 'New password',
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() => obscure = !obscure),
                                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
                                ],
                              );
                            });
                          },
                        );
                        if (ok == true) {
                          final newPass = controller.text.trim();
                          if (newPass.isEmpty) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password cannot be empty')));
                            }
                            return;
                          }
                          await repo.setInstitutionAdminPassword(instId: id, newPassword: newPass);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Institution Admin password updated')));
                          }
                        }
                      }, icon: const Icon(Icons.key, color: Colors.orange), label: const Text('Set Institution Admin Password')),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(minWidth: isNarrow ? constraints.maxWidth : 0),
                      child: OutlinedButton.icon(onPressed: () async {
                        final id = i.uniqueInstitutionId ?? i.id;
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) {
                            final confirmCtrl = TextEditingController();
                            bool canDelete = false;
                            bool busy = false;
                            return StatefulBuilder(builder: (ctx, setState) {
                              Future<void> exportNow() async {
                                try {
                                  setState(() => busy = true);
                                  final students = await studentRepo.listStudents(instId: id);
                                  final headers = [
                                    'id','inst_id','first_name','last_name','phone_number','email','aadhaar','photo_url','parent_name','parent_phone','address','occupation','college_course_class','terms_accepted','status','enabled','fee_amount','fee_type','fee_due_date','room_number','bed_number','created_at','updated_at'
                                  ];
                                  String esc(Object? v) {
                                    final s = v == null ? '' : v is Timestamp ? v.toDate().toIso8601String() : v.toString();
                                    final q = s.replaceAll('"', '""');
                                    return '"$q"';
                                  }
                                  final rows = <String>[];
                                  rows.add(headers.map(esc).join(','));
                                  for (final d in students) {
                                    rows.add([
                                      d['id'], d['inst_id'], d['first_name'], d['last_name'], d['phone_number'], d['email'], d['aadhaar'], d['photo_url'], d['parent_name'], d['parent_phone'], d['address'], d['occupation'], d['college_course_class'], d['terms_accepted'], d['status'], d['enabled'], d['fee_amount'], d['fee_type'], d['fee_due_date'], d['room_number'], d['bed_number'], d['created_at'], d['updated_at']
                                    ].map(esc).join(','));
                                  }
                                  final csv = rows.join('\n');
                                  final storage = FirebaseStorageService();
                                  final fileName = 'students_${id}_export_${DateTime.now().millisecondsSinceEpoch}.csv';
                                  final url = await storage.uploadInstitutionExportText(instId: id, data: Uint8List.fromList(utf8.encode(csv)), fileName: fileName, contentType: 'text/csv');
                                  if (context.mounted) {
                                    await showDialog<void>(
                                      context: context,
                                      builder: (ctx2) => AlertDialog(
                                        title: const Text('Export ready'),
                                        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          const Text('Students CSV has been uploaded. Use the link below to download/share:'),
                                          const SizedBox(height: 8),
                                          SelectableText(url, maxLines: 3),
                                        ]),
                                        actions: [
                                          TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: url)); Navigator.pop(ctx2); }, child: const Text('Copy link')),
                                          TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Close')),
                                        ],
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
                                  }
                                } finally {
                                  setState(() => busy = false);
                                }
                              }
                              return AlertDialog(
                                title: const Text('Delete Institution'),
                                content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('You are about to delete $id. This will permanently remove the institution and ALL its students, payments, rooms and complaints.'),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(onPressed: busy ? null : exportNow, icon: const Icon(Icons.download), label: const Text('Export Students CSV')),
                                  const SizedBox(height: 12),
                                  const Text('Type Delete to confirm'),
                                  TextField(
                                    controller: confirmCtrl,
                                    onChanged: (_) => setState(() => canDelete = confirmCtrl.text.trim() == 'Delete'),
                                    decoration: const InputDecoration(labelText: 'Confirmation'),
                                  ),
                                ]),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  FilledButton(
                                    onPressed: (!canDelete || busy) ? null : () => Navigator.pop(ctx, true),
                                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                    child: busy ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Delete'),
                                  ),
                                ],
                              );
                            });
                          },
                        );
                        if (ok == true) {
                          try {
                            print('Attempting to delete institution with ID: $id (original: ${i.id}, unique: ${i.uniqueInstitutionId})');
                            await repo.deleteInstitution(instId: id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Institution $id deleted successfully')));
                            }
                            // Immediately refresh the list so the deleted institution disappears
                            await onChanged?.call();
                          } catch (e) {
                            print('Deletion failed for institution $id: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete institution: $e'), backgroundColor: Colors.red));
                            }
                          }
                        }
                      }, icon: const Icon(Icons.delete, color: Colors.red), label: const Text('Delete')),
                    ),
                  ],
                );
              })
            ])
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: Colors.blue),
        const SizedBox(width: 8),
        Text('$label: ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        Expanded(child: Text(value, overflow: TextOverflow.ellipsis, softWrap: true)),
      ]),
    );
  }
}

class _EmailPreviewDialog extends StatelessWidget {
  final String toEmail; final String instId; final String username; final String password;
  const _EmailPreviewDialog({required this.toEmail, required this.instId, required this.username, required this.password});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Credentials emailed'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('To: $toEmail'),
          const SizedBox(height: 8),
          Text('Subject: Institution Registration Approved'),
          const Divider(),
          Text('Dear Institution Admin,\n\nYour registration has been approved.\n\nInstitution ID: $instId\nUsername: $username\nPassword: $password\n\nPlease keep this information secure.'),
          const SizedBox(height: 12),
          Text('Note: This is a simulated email for demo purposes.'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}
