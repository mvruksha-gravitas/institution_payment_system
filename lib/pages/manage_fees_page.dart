import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';
import 'package:institutation_payment_system/services/fee_repository.dart';
import 'package:institutation_payment_system/services/payment_repository.dart';
import 'package:institutation_payment_system/services/receipt_service.dart';
import 'package:institutation_payment_system/widgets/receipt_view_dialog.dart';

class ManageFeesPage extends StatefulWidget {
  final String instId;
  final String studentId;
  final bool isDisabled;
  const ManageFeesPage({super.key, required this.instId, required this.studentId, this.isDisabled = false});
  @override
  State<ManageFeesPage> createState() => _ManageFeesPageState();
}

class _ManageFeesPageState extends State<ManageFeesPage> {
  final _feeRepo = FirebaseFeeRepository();
  final _payRepo = FirebasePaymentRepository();
  final _receipt = ReceiptService();
  List<Map<String, dynamic>> _fees = [];
  bool _loading = true;
  Map<String, dynamic>? _studentDoc;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final fees = await _feeRepo.listFees(instId: widget.instId, studentId: widget.studentId);
    final sDoc = await FirebaseFirestore.instance
        .collection(InstitutionRegistrationSchema.collectionName)
        .doc(widget.instId)
        .collection(InstitutionRegistrationSchema.studentsSubcollection)
        .doc(widget.studentId)
        .get();
    if (!mounted) return;
    setState(() {
      _fees = fees;
      _studentDoc = sDoc.data();
      _loading = false;
    });
  }

  Future<void> _addMonthly() async {
    final res = await showDialog<(num amount, int month, int year, DateTime? due, bool recurring)>(
      context: context,
      builder: (ctx) => const _ManageFeesAddMonthlyDialog(),
    );
    if (res == null) return;
    await _feeRepo.addMonthlyFee(
      instId: widget.instId,
      studentId: widget.studentId,
      amount: res.$1,
      month: res.$2,
      year: res.$3,
      dueDate: res.$4,
      recurring: res.$5,
    );
    await _loadAll();
  }

  Future<void> _addOther() async {
    final res = await showDialog<(num amount, String reason, DateTime? due)>(context: context, builder: (ctx) => const _ManageFeesAddOtherDialog());
    if (res == null) return;
    await _feeRepo.addOtherCharge(instId: widget.instId, studentId: widget.studentId, amount: res.$1, reason: res.$2, dueDate: res.$3);
    await _loadAll();
  }

  Future<void> _editFee(Map<String, dynamic> fee) async {
    final dueTs = fee[FeeItemSchema.dueDate] as Timestamp?; final due = dueTs?.toDate();
    final amtVal = fee[FeeItemSchema.amount] as num? ?? 0;
    final res = await showDialog<(num amount, DateTime? due)>(context: context, builder: (ctx) => _ManageFeesEditFeeDialog(initialAmount: amtVal, initialDue: due));
    if (res == null) return;
    await _feeRepo.updateFeeItem(instId: widget.instId, studentId: widget.studentId, feeItemId: fee[FeeItemSchema.id] as String, amount: res.$1, dueDate: res.$2);
    await _loadAll();
  }

  Future<void> _deleteFee(Map<String, dynamic> fee) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Unpaid Amount'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(alignment: Alignment.centerLeft, child: Text('Please provide a reason for deleting this unpaid amount.')),
            const SizedBox(height: 8),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () { final r = reasonCtrl.text.trim(); if (r.isEmpty) return; Navigator.pop(ctx, r); }, child: const Text('Delete')),
        ],
      ),
    );
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await _feeRepo.deleteFeeItem(instId: widget.instId, studentId: widget.studentId, feeItemId: fee[FeeItemSchema.id] as String, reason: reason.trim());
      await _loadAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount deleted and excluded from totals.')));
    } catch (e) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _markPaid(Map<String, dynamic> fee) async {
    final amount = fee[FeeItemSchema.amount] as num? ?? 0;
    final label = (fee[FeeItemSchema.type] == FeeItemSchema.typeMonthly) ? (fee[FeeItemSchema.label] as String? ?? 'Monthly Fee') : (fee[FeeItemSchema.label] as String? ?? 'Other charge');
    final paymentId = await _payRepo.addPayment(instId: widget.instId, studentId: widget.studentId, amount: amount, method: 'cash', feeItemId: fee[FeeItemSchema.id] as String?, feeLabel: label);
    await _feeRepo.markFeePaid(instId: widget.instId, studentId: widget.studentId, feeItemId: fee[FeeItemSchema.id] as String, paymentId: paymentId);
    await _loadAll();
  }

  String _studentHeader() {
    final s = _studentDoc;
    if (s == null) return '';
    final first = (s[StudentSchema.firstName] as String?)?.trim() ?? '';
    final last = (s[StudentSchema.lastName] as String?)?.trim() ?? '';
    final phone = (s[StudentSchema.phoneNumber] as String?)?.trim();
    final name = ('$first $last').trim().isEmpty ? (phone ?? '-') : ('$first $last').trim();
    final room = s[StudentSchema.roomNumber] as String?;
    final bed = s[StudentSchema.bedNumber] as int?;
    final suffix = '(${room != null ? 'Room $room' : 'Room -'}, ${bed != null ? 'Bed $bed' : 'Bed -'})';
    return '$name $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 600;
    final title = isSmall ? 'Manage Charges' : 'Manage Charges';
    final subtitle = _studentHeader();
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title),
          if (subtitle.isNotEmpty) Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (widget.isDisabled)
                    Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)), child: const Text('This account is disabled. You cannot assign charges.', style: TextStyle(color: Colors.red))),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.icon(onPressed: widget.isDisabled ? null : _addMonthly, icon: const Icon(Icons.calendar_month), label: const Text('Add Monthly')),
                    OutlinedButton.icon(onPressed: widget.isDisabled ? null : _addOther, icon: const Icon(Icons.add), label: const Text('Add Other')),
                  ]),
                  const SizedBox(height: 12),
                  if (_fees.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 36), child: Text('No charges yet')))
                  else
                    ..._fees.map((f) {
                      final type = f[FeeItemSchema.type] as String? ?? FeeItemSchema.typeMonthly;
                      final label = f[FeeItemSchema.label] as String? ?? '';
                      final amt = (f[FeeItemSchema.amount] as num? ?? 0).toStringAsFixed(2);
                      final dueTs = f[FeeItemSchema.dueDate] as Timestamp?;
                      final due = dueTs?.toDate();
                      final dueStr = due == null ? '-' : '${due.day}/${due.month}/${due.year}';
                      final status = f[FeeItemSchema.status] as String? ?? 'pending';
                      final paymentId = f[FeeItemSchema.paymentId] as String?;
                      final isToConfirm = status == 'to_confirm';
                      final isDeleted = (f[FeeItemSchema.deleted] as bool?) ?? false;
                      final delReason = f[FeeItemSchema.deletedReason] as String?;
                      final delAtTs = f[FeeItemSchema.deletedAt] as Timestamp?;
                      final delAt = delAtTs?.toDate();
                      final color = isDeleted ? Colors.red : (status == 'paid' ? Colors.green : (isToConfirm ? Colors.blue : Colors.orange));
                      final titleStyle = isDeleted ? const TextStyle(decoration: TextDecoration.lineThrough) : null;
                      return Card(
                        child: ListTile(
                          leading: Icon(type == FeeItemSchema.typeMonthly ? Icons.calendar_month : Icons.attach_money, color: color),
                          title: Text('$label • ₹$amt', style: titleStyle, overflow: TextOverflow.ellipsis),
                          subtitle: isDeleted
                              ? Text('Deleted${delAt != null ? ' on ${delAt.day}/${delAt.month}/${delAt.year}' : ''} • Reason: ${delReason ?? '-'} • Excluded from total amount calculations.', style: TextStyle(color: Colors.red.withValues(alpha: 0.85)))
                              : Text('Due: $dueStr • ${type == FeeItemSchema.typeMonthly ? ((f[FeeItemSchema.recurring] as bool? ?? false) ? 'Monthly (Recurring)' : 'Monthly') : 'Other'} • ${isToConfirm ? 'TO CONFIRM' : status.toUpperCase()}'),
                          trailing: isDeleted
                              ? null
                              : Row(mainAxisSize: MainAxisSize.min, children: [
                                  if (isToConfirm) ...[
                                    IconButton(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) {
                                            final method = (f[FeeItemSchema.submissionMethod] as String? ?? '').toUpperCase();
                                            final note = f[FeeItemSchema.submissionNote] as String?;
                                            final proof = f[FeeItemSchema.submissionProofUrl] as String?;
                                            return AlertDialog(
                                              title: const Text('Submitted Payment'),
                                              content: ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 520),
                                                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                  Text('Method: $method'),
                                                  const SizedBox(height: 6),
                                                  if (note != null && note.isNotEmpty) Text('Comment: $note') else const Text('No comment'),
                                                  const SizedBox(height: 8),
                                                  if (proof != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(proof, height: 180, fit: BoxFit.cover)) else const Text('No screenshot attached'),
                                                ]),
                                              ),
                                              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                                            );
                                          },
                                        );
                                      },
                                      icon: const Icon(Icons.visibility, color: Colors.blue),
                                    ),
                                    IconButton(onPressed: () => _editFee(f), icon: const Icon(Icons.edit, color: Colors.blue)),
                                    IconButton(onPressed: () async { await _markPaid(f); }, icon: const Icon(Icons.check_circle, color: Colors.green)),
                                    IconButton(onPressed: () => _deleteFee(f), icon: const Icon(Icons.delete, color: Colors.red)),
                                  ] else if (status != 'paid') ...[
                                    IconButton(onPressed: () => _editFee(f), icon: const Icon(Icons.edit, color: Colors.blue)),
                                    IconButton(onPressed: () => _markPaid(f), icon: const Icon(Icons.check_circle, color: Colors.green)),
                                    IconButton(onPressed: () => _deleteFee(f), icon: const Icon(Icons.delete, color: Colors.red)),
                                  ],
                                  if (paymentId != null)
                                    IconButton(
                                      onPressed: () async {
                                        final payDoc = await FirebaseFirestore.instance
                                            .collection(InstitutionRegistrationSchema.collectionName)
                                            .doc(widget.instId)
                                            .collection(InstitutionRegistrationSchema.paymentsSubcollection)
                                            .doc(paymentId)
                                            .get();
                                        final data = payDoc.data(); if (data != null && mounted) { await showDialog(context: context, builder: (ctx) => ReceiptViewDialog.forPayment(instId: widget.instId, payment: data)); }
                                      },
                                      icon: const Icon(Icons.download, color: Colors.blue),
                                    ),
                                ]),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
    );
  }
}

class _ManageFeesAddMonthlyDialog extends StatefulWidget {
  const _ManageFeesAddMonthlyDialog();
  @override
  State<_ManageFeesAddMonthlyDialog> createState() => _ManageFeesAddMonthlyDialogState();
}

class _ManageFeesAddMonthlyDialogState extends State<_ManageFeesAddMonthlyDialog> {
  final _amount = TextEditingController();
  int _m = DateTime.now().month; int _y = DateTime.now().year; DateTime? _due; bool _recurring = true;
  @override
  void dispose() { _amount.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Monthly Fee'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _amount, decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: DropdownButtonFormField<int>(value: _m, items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('Month ${i + 1}'))), onChanged: (v) => setState(() => _m = v ?? _m), decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Month'))),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<int>(value: _y, items: List.generate(6, (i) { final y = DateTime.now().year - 1 + i; return DropdownMenuItem(value: y, child: Text('$y')); }), onChanged: (v) => setState(() => _y = v ?? _y), decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Year'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.event, color: Colors.orange), const SizedBox(width: 8),
            Expanded(child: Text(_due == null ? 'No due date selected' : 'Due: ${_due!.day}/${_due!.month}/${_due!.year}')),
            TextButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: _due ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) setState(() => _due = d); }, child: const Text('Pick date')),
          ]),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(value: _recurring, onChanged: (v) => setState(() => _recurring = v), title: const Text('Recurring monthly')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () { final a = num.tryParse(_amount.text.trim()); if (a == null) return; Navigator.pop(context, (a, _m, _y, _due, _recurring)); }, child: const Text('Save')),
      ],
    );
  }
}

class _ManageFeesAddOtherDialog extends StatefulWidget {
  const _ManageFeesAddOtherDialog();
  @override
  State<_ManageFeesAddOtherDialog> createState() => _ManageFeesAddOtherDialogState();
}

class _ManageFeesAddOtherDialogState extends State<_ManageFeesAddOtherDialog> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  DateTime? _due;
  @override
  void dispose() { _amount.dispose(); _reason.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Other Charge'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _amount, decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.event, color: Colors.orange), const SizedBox(width: 8),
            Expanded(child: Text(_due == null ? 'No due date selected' : 'Due: ${_due!.day}/${_due!.month}/${_due!.year}')),
            TextButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: _due ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) setState(() => _due = d); }, child: const Text('Pick date')),
          ])
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () { final a = num.tryParse(_amount.text.trim()); final r = _reason.text.trim(); if (a == null || r.isEmpty) return; Navigator.pop(context, (a, r, _due)); }, child: const Text('Save')),
      ],
    );
  }
}

class _ManageFeesEditFeeDialog extends StatefulWidget {
  final num initialAmount; final DateTime? initialDue;
  const _ManageFeesEditFeeDialog({required this.initialAmount, required this.initialDue});
  @override
  State<_ManageFeesEditFeeDialog> createState() => _ManageFeesEditFeeDialogState();
}

class _ManageFeesEditFeeDialogState extends State<_ManageFeesEditFeeDialog> {
  late TextEditingController _amount; DateTime? _due;
  @override
  void initState() { super.initState(); _amount = TextEditingController(text: widget.initialAmount.toString()); _due = widget.initialDue; }
  @override
  void dispose() { _amount.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Due/Amount'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.event, color: Colors.orange), const SizedBox(width: 8),
            Expanded(child: Text(_due == null ? 'No due date' : 'Due: ${_due!.day}/${_due!.month}/${_due!.year}')),
            TextButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: _due ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) setState(() => _due = d); }, child: const Text('Pick date')),
          ])
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () { final a = num.tryParse(_amount.text.trim()); if (a == null) return; Navigator.pop<(num, DateTime?)>(context, (a, _due)); }, child: const Text('Save')),
      ],
    );
  }
}
