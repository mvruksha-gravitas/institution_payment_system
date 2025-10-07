import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../firestore/firestore_data_schema.dart';
import '../widgets/responsive_dialog.dart';
import '../widgets/receipt_view_dialog.dart';
import '../services/receipt_service.dart';
import '../theme.dart';
import 'payment_filters_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:institutation_payment_system/services/firebase_institution_repository.dart';
import 'package:institutation_payment_system/services/student_repository.dart';
import 'package:institutation_payment_system/services/payment_repository.dart';
import 'package:institutation_payment_system/services/fee_repository.dart';
import 'package:institutation_payment_system/services/accommodation_repository.dart';
import 'package:institutation_payment_system/services/complaint_repository.dart';
import 'package:institutation_payment_system/services/support_ticket_repository.dart';
import 'package:institutation_payment_system/services/storage_service.dart';
import 'package:institutation_payment_system/widgets/branding.dart';
import 'package:institutation_payment_system/widgets/payment_submission_dialog.dart';
import 'package:institutation_payment_system/pages/manage_fees_page.dart';
import 'package:institutation_payment_system/pages/manage_rooms_page.dart';

class InstitutionAdminPortalPage extends StatefulWidget {
const InstitutionAdminPortalPage({super.key});
@override
State<InstitutionAdminPortalPage> createState() => _InstitutionAdminPortalPageState();
}

class _InstitutionAdminPortalPageState extends State<InstitutionAdminPortalPage> with SingleTickerProviderStateMixin {
late final TabController _tab;
final _instRepo = FirebaseInstitutionRepository();
final _studentRepo = FirebaseStudentRepository();
final _paymentRepo = FirebasePaymentRepository();
final _feeRepo = FirebaseFeeRepository();
final _accomRepo = FirebaseAccommodationRepository();
final _complaintRepo = FirebaseComplaintRepository();

bool _loading = true;
List<Map<String, dynamic>> _students = [];
List<Map<String, dynamic>> _payments = [];
Map<String, List<Map<String, dynamic>>> _feesByStudent = {};
List<Map<String, dynamic>> _complaints = [];
num _totalPaid = 0;
num _expected = 0;
String? _roomFilter;
String _studentSearch = '';
bool _institutionEnabled = true;
String? _instName;
String? _adminName;
String? _instAddress;

String get _instId => (context.read<AppState>().user as InstitutionAdminSessionUser).instId;

Future<void> _setAdminPassword() async {
final newPass = await showDialog<String?> (
context: context,
barrierDismissible: false,
builder: (ctx) => const _SetInstitutionAdminPasswordDialog(),
);
if (newPass == null) return;
try {
await _instRepo.setInstitutionAdminPassword(instId: _instId, newPassword: newPass);
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Institution Admin password updated successfully.')));
} catch (e) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

@override
void initState() {
super.initState();
_tab = TabController(length: 6, vsync: this);
// Defer refresh until AppState is initialized and user is present
WidgetsBinding.instance.addPostFrameCallback((_) {
final app = context.read<AppState>();
if (app.initialized && app.isInstitutionAdmin && mounted) {
_refresh();
}
});
}

Future<void> _refresh() async {
setState(() => _loading = true);
try {
final students = await _studentRepo.listStudents(instId: _instId, roomFilter: _roomFilter);
final payments = await _paymentRepo.listPayments(instId: _instId, roomFilter: _roomFilter);
final paid = await _paymentRepo.totalPaidAmount(instId: _instId);
final Map<String, List<Map<String, dynamic>>> feesByStudent = {};
num expected = 0;
await Future.wait(students.map((s) async {
final sid = s[StudentSchema.id] as String;
final fees = await _feeRepo.listFees(instId: _instId, studentId: sid);
feesByStudent[sid] = fees;
for (final f in fees) {
final status = f[FeeItemSchema.status] as String? ?? 'pending';
final isDeleted = (f[FeeItemSchema.deleted] as bool?) ?? false;
if (!isDeleted && status != 'paid') {
expected += (f[FeeItemSchema.amount] as num? ?? 0);
}
}
}));
final instDoc = await _instRepo.getInstitutionDoc(_instId);
final instData = instDoc.data();
final enabled = (instData?[InstitutionRegistrationSchema.enabled] as bool?) ?? true;
final name = (instData?[InstitutionRegistrationSchema.institutionName] as String?)?.trim();
final admin = (instData?[InstitutionRegistrationSchema.personName] as String?)?.trim();
final addr = (instData?['address'] as String?)?.trim();
final complaints = await _complaintRepo.listComplaints(instId: _instId);
if (!mounted) return;
setState(() {
_students = students;
_payments = payments;
_feesByStudent = feesByStudent;
_complaints = complaints;
_totalPaid = paid;
_expected = expected;
_institutionEnabled = enabled;
_instName = (name == null || name.isEmpty) ? null : name;
_adminName = (admin == null || admin.isEmpty) ? null : admin;
_instAddress = (addr == null || addr.isEmpty) ? null : addr;
_loading = false;
});
} catch (e) {
if (!mounted) return;
setState(() => _loading = false);
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading: $e'), backgroundColor: Colors.red));
}
}

Future<void> _approveStudent(String studentId) async {
try {
await _studentRepo.approveStudent(instId: _instId, studentId: studentId);
await _refresh();
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student approved. Credentials sent via SMS/WhatsApp (simulated).')));
} catch (e) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

Future<void> _toggleStudent(String studentId, bool enabled) async {
String? reason;
if (!enabled) {
final ctrl = TextEditingController();
reason = await showDialog<String?>(
context: context,
barrierDismissible: false,
builder: (ctx) => AlertDialog(
title: const Text('Disable Student'),
content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
const Align(alignment: Alignment.centerLeft, child: Text('Please enter the reason for disabling this account.')),
const SizedBox(height: 8),
TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()))
])),
actions: [
TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
FilledButton(onPressed: () { final r = ctrl.text.trim(); if (r.isEmpty) return; Navigator.pop(ctx, r); }, child: const Text('Disable')),
],
),
);
if (reason == null || reason.isEmpty) return;
}
await _studentRepo.setStudentEnabled(instId: _instId, studentId: studentId, enabled: enabled, reason: reason);
await _refresh();
}

// Legacy _setFee removed. Use Manage Charges to add Monthly or Other charges per-student.


Future<void> _assignRoom(String studentId) async {
final controller = TextEditingController();
final room = await showDialog<String?>(
context: context,
builder: (ctx) => AlertDialog(
title: const Text('Assign Room Number'),
content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Room number', border: OutlineInputBorder())),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save'))],
),
);
if (room == null) return;
await _studentRepo.assignRoom(instId: _instId, studentId: studentId, roomNumber: room.isEmpty ? null : room);
await _refresh();
}

Future<void> _assignBed(String studentId) async {
// Block assignment for disabled accounts
try {
final s = _students.firstWhere((e) => e[StudentSchema.id] == studentId);
final enabled = (s[StudentSchema.enabled] as bool?) ?? true;
if (!enabled) {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room assignment is not allowed because the account is disabled.'), backgroundColor: Colors.red));
}
return;
}
} catch (_) {}
// Pick a room, then pick a specific bed in that room
final rooms = await _accomRepo.listRooms(instId: _instId);
// Sort rooms in natural alphanumeric order (e.g., 1, 2, 10; A1, A2, A10)
int _naturalCompare(String a, String b) {
final reg = RegExp(r"(\d+|\D+)");
final ta = reg.allMatches(a).map((m) => m.group(0)!).toList();
final tb = reg.allMatches(b).map((m) => m.group(0)!).toList();
final len = ta.length < tb.length ? ta.length : tb.length;
for (int i = 0; i < len; i++) {
final xa = ta[i];
final xb = tb[i];
final na = int.tryParse(xa);
final nb = int.tryParse(xb);
if (na != null && nb != null) {
final c = na.compareTo(nb);
if (c != 0) return c;
} else {
final c = xa.toLowerCase().compareTo(xb.toLowerCase());
if (c != 0) return c;
}
}
return ta.length.compareTo(tb.length);
}
rooms.sort((a, b) => _naturalCompare((a[RoomSchema.roomNumber] as String?) ?? '', (b[RoomSchema.roomNumber] as String?) ?? ''));
final pricing = await _accomRepo.getFoodPricing(instId: _instId);
if (!mounted) return;
final selectedRoomNumber = await showDialog<String?>(
context: context,
builder: (ctx) {
return AlertDialog(
title: const Text('Assign Bed'),
content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: rooms.isEmpty
? const Text('No rooms created yet')
: ListView.separated(shrinkWrap: true, itemCount: rooms.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
final r = rooms[i];
final rn = r[RoomSchema.roomNumber] as String? ?? '';
final cat = r[RoomSchema.category] as String? ?? 'two_sharing';
final cap = r[RoomSchema.capacity] as int? ?? 2;
final withAmt = pricing['with']?[cat];
final withoutAmt = pricing['without']?[cat];
return FutureBuilder<(int total, int occupied)>(
future: _accomRepo.roomStats(instId: _instId, roomId: r[RoomSchema.id] as String),
builder: (c, snap) {
final total = snap.data?.$1 ?? cap;
final occ = snap.data?.$2 ?? 0;
final free = total - occ;
final extra = (withAmt != null || withoutAmt != null)
? '\nWith: ${withAmt != null ? '₹${withAmt.toString()}' : '-'} • Without: ${withoutAmt != null ? '₹${withoutAmt.toString()}' : '-'}'
: '';
return ListTile(
leading: const Icon(Icons.meeting_room, color: Colors.blue),
title: Text('Room $rn'),
subtitle: Text('${_labelForCategory(cat)} • Beds: $occ/$total occupied$extra'),
trailing: free > 0 ? FilledButton(onPressed: () => Navigator.pop(ctx, rn), child: const Text('Select')) : const Text('Full', style: TextStyle(color: Colors.red)),
);
},
);
})),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
);
},
);
if (selectedRoomNumber == null) return;
try {
// Find roomId and list available beds
final roomRes = await _accomRepo.findRoomByNumber(instId: _instId, roomNumber: selectedRoomNumber);
if (roomRes == null) { throw Exception('Room not found'); }
final roomId = roomRes.$1;
final roomCat = (roomRes.$2[RoomSchema.category] as String?) ?? 'two_sharing';
final beds = await _accomRepo.listBeds(instId: _instId, roomId: roomId);
final freeBeds = beds.where((b) => (b[BedSchema.occupied] as bool? ?? false) == false).toList()..sort((a, b) => (a[BedSchema.bedNumber] as int).compareTo(b[BedSchema.bedNumber] as int));
if (freeBeds.isEmpty) { throw Exception('No free bed available in this room'); }
final selectedBed = await showDialog<int?>(
context: context,
builder: (ctx) => AlertDialog(
title: Text('Select Bed • Room $selectedRoomNumber'),
content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 400), child: ListView.separated(shrinkWrap: true, itemCount: freeBeds.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
final bn = freeBeds[i][BedSchema.bedNumber] as int? ?? 0;
return ListTile(leading: const Icon(Icons.bed, color: Colors.green), title: Text('Bed $bn'), trailing: FilledButton(onPressed: () => Navigator.pop(ctx, bn), child: const Text('Assign')));
})),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
),
);
if (selectedBed == null) return;
await _accomRepo.assignSpecificBed(instId: _instId, roomId: roomId, bedNumber: selectedBed, studentId: studentId);
await FirebaseFirestore.instance
.collection(InstitutionRegistrationSchema.collectionName)
.doc(_instId)
.collection(InstitutionRegistrationSchema.studentsSubcollection)
.doc(studentId)
.update({
StudentSchema.roomNumber: selectedRoomNumber,
StudentSchema.bedNumber: selectedBed,
StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
});

// Prompt for food plan and apply monthly charge
final chosenPlan = await _promptPlanAndApplyCharge(category: roomCat, studentId: studentId);
// Persist food plan and room category on student
if (chosenPlan != null) {
await FirebaseFirestore.instance
.collection(InstitutionRegistrationSchema.collectionName)
.doc(_instId)
.collection(InstitutionRegistrationSchema.studentsSubcollection)
.doc(studentId)
.update({
StudentSchema.foodPlan: chosenPlan,
StudentSchema.roomCategory: roomCat,
StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
});
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Food plan set: ${chosenPlan == 'with' ? 'With Food' : 'Without Food'}')));
}
}

await _refresh();
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assigned Room $selectedRoomNumber • Bed $selectedBed')));
} catch (e) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

String _labelForCategory(String category) {
switch (category) {
case 'single':
return 'Single';
case 'two_sharing':
return 'Two Sharing';
case 'three_sharing':
return 'Three Sharing';
case 'four_sharing':
return 'Four Sharing';
default:
return category;
}
}

Future<String?> _promptPlanAndApplyCharge({required String category, required String studentId}) async {
final pricing = await _accomRepo.getFoodPricing(instId: _instId);
final withAmt = pricing['with']?[category];
final withoutAmt = pricing['without']?[category];
if (withAmt == null && withoutAmt == null) return null;
String plan = 'with';
final chosen = await showDialog<String?>(context: context, builder: (ctx) {
return StatefulBuilder(builder: (ctx, setState) {
return AlertDialog(
title: const Text('Select Food Plan'),
content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
Align(alignment: Alignment.centerLeft, child: Text('Category: ${_labelForCategory(category)}', style: Theme.of(ctx).textTheme.bodyMedium)),
const SizedBox(height: 8),
RadioListTile<String>(
value: 'with',
groupValue: plan,
onChanged: (v) { setState(() => plan = 'with'); },
title: Builder(builder: (_) {
final wf = withAmt != null ? '₹${withAmt.toString()}' : 'N/A';
return Text('With Food • $wf');
}),
),
RadioListTile<String>(
value: 'without',
groupValue: plan,
onChanged: (v) { setState(() => plan = 'without'); },
title: Builder(builder: (_) {
final wof = withoutAmt != null ? '₹${withoutAmt.toString()}' : 'N/A';
return Text('Without Food • $wof');
}),
),
])),
actions: [
TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
FilledButton(onPressed: () => Navigator.pop(ctx, plan), child: const Text('Apply'))
],
);
});
});
if (chosen == null) return null;
final amount = chosen == 'with' ? withAmt : withoutAmt;
if (amount == null || amount <= 0) return chosen;
final now = DateTime.now();
final due = DateTime(now.year, now.month + 1, 0);
try {
await _feeRepo.addMonthlyFee(instId: _instId, studentId: studentId, amount: amount, month: now.month, year: now.year, dueDate: due, recurring: true);
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Monthly charge added (${_labelForCategory(category)} • ${chosen == 'with' ? 'With Food' : 'Without Food'})')));
}
} catch (e) {
if (!mounted) return null; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding charge: $e'), backgroundColor: Colors.red));
}
}



Future<void> _resetStudentPassword(String studentId) async {
try {
await _studentRepo.resetStudentPassword(instId: _instId, studentId: studentId);
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset. OTP email flow simulated.')));
} catch (e) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

Future<void> _setStudentPassword(String studentId) async {
final newPass = await showDialog<String?>(
context: context,
barrierDismissible: false,
builder: (ctx) => const _SetStudentPasswordDialog(),
);
if (newPass == null) return;
try {
await _studentRepo.setStudentPasswordById(instId: _instId, studentId: studentId, newPassword: newPass);
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully.')));
} catch (e) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

Future<void> _manageStudentFees(String studentId) async {
final s = _students.firstWhere((e) => e[StudentSchema.id] == studentId, orElse: () => {});
final bool isDisabled = (s.isNotEmpty ? ((s[StudentSchema.enabled] as bool?) ?? true) == false : false);
await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ManageFeesPage(instId: _instId, studentId: studentId, isDisabled: isDisabled)));
await _refresh();
}

Future<void> _toggleInstitution(bool value) async {
await _instRepo.setInstitutionEnabled(instId: _instId, enabled: value);
setState(() => _institutionEnabled = value);
}

@override
Widget build(BuildContext context) {
final app = context.watch<AppState>();
if (!app.initialized) {
return const Scaffold(body: Center(child: CircularProgressIndicator()));
}
if (!app.isInstitutionAdmin) {
return const _UnauthorizedScaffold(role: 'Institution Admin', loginRoute: '/login');
}
Future<void> _markFeePaidFor(String studentId, Map<String, dynamic> fee) async {
try {
final amount = fee[FeeItemSchema.amount] as num? ?? 0;
final label = (fee[FeeItemSchema.type] == FeeItemSchema.typeMonthly) ? (fee[FeeItemSchema.label] as String? ?? 'Monthly Fee') : (fee[FeeItemSchema.label] as String? ?? 'Other charge');
final result = await showDialog<PaymentSubmissionResult>(context: context, builder: (ctx) => const PaymentSubmissionDialog(title: 'Record Payment', showAdminHint: true));
if (result == null) return;
String? proofUrl;
if (result.proofBytes != null && result.proofExtension != null) {
proofUrl = await FirebaseStorageService().uploadPaymentProof(instId: _instId, studentId: studentId, feeItemId: fee[FeeItemSchema.id] as String, data: result.proofBytes!, fileExtension: result.proofExtension!);
}
final paymentId = await _paymentRepo.addPayment(instId: _instId, studentId: studentId, amount: amount, method: result.method, feeItemId: fee[FeeItemSchema.id] as String?, feeLabel: label, note: result.note, proofUrl: proofUrl, submittedBy: 'institution_admin');
await _feeRepo.markFeePaid(instId: _instId, studentId: studentId, feeItemId: fee[FeeItemSchema.id] as String, paymentId: paymentId);
await _refresh();
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as paid')));
} catch (e) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

return Scaffold(
appBar: AppBar(
toolbarHeight: 56,
elevation: 0,
title: Text(
_instName == null || _instName!.isEmpty ? 'SmartStay PG Manager' : 'SmartStay PG Manager - ${_instName!}',
style: Theme.of(context).textTheme.titleMedium,
overflow: TextOverflow.ellipsis,
),
actions: [
IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
IconButton(onPressed: () => context.read<AppState>().signOut().then((_) => Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false)), icon: const Icon(Icons.logout, color: Colors.red))
],
bottom: TabBar(
controller: _tab,
isScrollable: true,
tabAlignment: TabAlignment.start,
labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
tabs: const [
Tab(text: 'Dashboard'),
Tab(text: 'Students'),
Tab(text: 'Accommodation'),
Tab(text: 'Payments'),
Tab(text: 'Support'),
Tab(text: 'Settings')
],
),
),
body: _loading
? const Center(child: CircularProgressIndicator())
: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
const SizedBox.shrink(),
Expanded(
child: RefreshIndicator(
onRefresh: _refresh,
child: TabBarView(controller: _tab, children: [
_DashboardTab(instId: _instId, students: _students, payments: _payments, feesByStudent: _feesByStudent, complaints: _complaints, onUpdateComplaintStatus: (id, status) async { await _complaintRepo.updateStatus(instId: _instId, complaintId: id, status: status); await _refresh(); }, expected: _expected, paid: _totalPaid, onOpenStudentFees: (sid) async { await _manageStudentFees(sid); }),
_StudentsTab(instId: _instId, students: _students, feesByStudent: _feesByStudent, onApprove: _approveStudent, onEnable: _toggleStudent, onAssignBed: _assignBed, onSetPassword: _setStudentPassword, onManageFees: _manageStudentFees, onFilter: (room) { setState(() => _roomFilter = room); _refresh(); }, searchQuery: _studentSearch, onSearchChanged: (q) { setState(() => _studentSearch = q.trim()); }, onMarkPaid: _markFeePaidFor, onApproveSubmitted: (sid, fee) async {
try {
// Try to find pending payment by fee item
final q = await FirebaseFirestore.instance.collection(InstitutionRegistrationSchema.collectionName).doc(_instId).collection(InstitutionRegistrationSchema.paymentsSubcollection)
.where(PaymentSchema.feeItemId, isEqualTo: fee[FeeItemSchema.id])
.where(PaymentSchema.studentId, isEqualTo: sid)
.where(PaymentSchema.status, isEqualTo: 'pending').limit(1).get();
String? paymentId;
if (q.docs.isNotEmpty) {
paymentId = q.docs.first.id;
await _paymentRepo.approvePendingPayment(instId: _instId, paymentId: paymentId);
} else {
final amt = fee[FeeItemSchema.amount] as num? ?? 0;
final label = (fee[FeeItemSchema.type] == FeeItemSchema.typeMonthly) ? (fee[FeeItemSchema.label] as String? ?? 'Monthly Fee') : (fee[FeeItemSchema.label] as String? ?? 'Other charge');
final method = fee[FeeItemSchema.submissionMethod] as String? ?? 'cash';
final note = fee[FeeItemSchema.submissionNote] as String?;
final proof = fee[FeeItemSchema.submissionProofUrl] as String?;
paymentId = await _paymentRepo.addPayment(instId: _instId, studentId: sid, amount: amt, method: method, feeItemId: fee[FeeItemSchema.id] as String?, feeLabel: label, note: note, proofUrl: proof, submittedBy: 'institution_admin');
}
await _feeRepo.markFeePaid(instId: _instId, studentId: sid, feeItemId: fee[FeeItemSchema.id] as String, paymentId: paymentId!);
await _refresh();
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved and marked as paid')));
} catch (e) {
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}, onRefresh: _refresh),
_AccommodationTab(instId: _instId),
_PaymentsTab(payments: _payments, students: _students, instId: _instId),
_SupportTab(instId: _instId),
_SettingsTab(instId: _instId, enabled: _institutionEnabled, onToggle: _toggleInstitution, onSetAdminPassword: _setAdminPassword),
]),
),
)
]),
bottomNavigationBar: const BrandedFooter(),
);
}
}

class _DashboardTab extends StatelessWidget {
final String instId;
final List<Map<String, dynamic>> students;
final List<Map<String, dynamic>> payments;
final Map<String, List<Map<String, dynamic>>> feesByStudent;
final List<Map<String, dynamic>> complaints;
final Future<void> Function(String complaintId, String status) onUpdateComplaintStatus;
final num expected; final num paid;
final void Function(String studentId) onOpenStudentFees;
const _DashboardTab({required this.instId, required this.students, required this.payments, required this.feesByStudent, required this.complaints, required this.onUpdateComplaintStatus, required this.expected, required this.paid, required this.onOpenStudentFees});

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

@override
Widget build(BuildContext context) {
final now = DateTime.now();
final firstOfMonth = DateTime(now.year, now.month, 1);
final prevMonthDate = DateTime(now.year, now.month - 1, 1);
final firstOfNextMonth = DateTime(now.year, now.month + 1, 1);

// Lookup map for student names
final Map<String, Map<String, dynamic>> studentById = {for (final s in students) s[StudentSchema.id] as String: s};

// Dues for current month
int duesThisMonth = 0;
num duesAmountThisMonth = 0;
num carryForwardAmount = 0;
final List<({String studentId, Map<String, dynamic> fee})> dueItemsThisMonth = [];
final List<({String studentId, Map<String, dynamic> fee})> carryForwardItems = [];

for (final entry in feesByStudent.entries) {
final sid = entry.key; final fees = entry.value;
for (final f in fees) {
final status = f[FeeItemSchema.status] as String? ?? 'pending';
final isDeleted = (f[FeeItemSchema.deleted] as bool?) ?? false;
if (status == 'paid' || isDeleted) continue;
final type = f[FeeItemSchema.type] as String? ?? FeeItemSchema.typeMonthly;
final amt = f[FeeItemSchema.amount] as num? ?? 0;
if (type == FeeItemSchema.typeMonthly) {
final m = f[FeeItemSchema.month] as int?; final y = f[FeeItemSchema.year] as int?;
if (m != null && y != null) {
final isCurrent = (m == now.month && y == now.year);
final isPast = (DateTime(y, m, 1).isBefore(firstOfMonth));
if (isCurrent) { duesThisMonth += 1; duesAmountThisMonth += amt; dueItemsThisMonth.add((studentId: sid, fee: f)); }
if (isPast) { carryForwardAmount += amt; carryForwardItems.add((studentId: sid, fee: f)); }
}
} else {
final dueTs = f[FeeItemSchema.dueDate] as Timestamp?; final due = dueTs?.toDate();
final isCurrent = due == null ? (true) : (due.year == now.year && due.month == now.month);
final isPast = due != null && due.isBefore(firstOfMonth);
if (isCurrent) { duesThisMonth += 1; duesAmountThisMonth += amt; dueItemsThisMonth.add((studentId: sid, fee: f)); }
if (isPast) { carryForwardAmount += amt; carryForwardItems.add((studentId: sid, fee: f)); }
}
}
}

// Previous month collection total
num prevMonthCollection = 0;
final List<Map<String, dynamic>> prevMonthPayments = [];
for (final p in payments) {
final ts = (p[PaymentSchema.paidAt] as Timestamp?)?.toDate();
if (ts == null) continue;
if (ts.year == prevMonthDate.year && ts.month == prevMonthDate.month) {
prevMonthCollection += (p[PaymentSchema.amount] as num? ?? 0);
prevMonthPayments.add(p);
}
}

// Daily totals for current month (for mini and detailed charts)
final int dim = _daysInMonth(now.year, now.month);
final List<double> dailyTotals = List.filled(dim, 0);
for (final p in payments) {
final ts = (p[PaymentSchema.paidAt] as Timestamp?)?.toDate();
if (ts == null) continue;
if (ts.isAfter(firstOfMonth.subtract(const Duration(seconds: 1))) && ts.isBefore(firstOfNextMonth)) {
final dayIndex = ts.day - 1;
dailyTotals[dayIndex] += (p[PaymentSchema.amount] as num? ?? 0).toDouble();
}
}

final receivedThisMonth = dailyTotals.fold<double>(0, (sum, v) => sum + v);
final notReceived = (duesAmountThisMonth - receivedThisMonth).clamp(0, double.infinity);

Future<void> _showStudentsDialog() async {
return showDialog(context: context, builder: (ctx) {
return AlertDialog(
title: const Text('Total Students'),
content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
Align(alignment: Alignment.centerLeft, child: Text('Count: ${students.length}', style: Theme.of(ctx).textTheme.titleMedium)),
const SizedBox(height: 8),
Flexible(child: students.isEmpty ? const Text('No students found') : ListView.separated(shrinkWrap: true, itemCount: students.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
final s = students[i];
final name = '${s[StudentSchema.firstName] ?? ''} ${s[StudentSchema.lastName] ?? ''}'.trim();
final room = s[StudentSchema.roomNumber] as String?;
return ListTile(leading: const Icon(Icons.person, color: Colors.blue), title: Text(name.isEmpty ? (s[StudentSchema.phoneNumber] as String? ?? '-') : name, overflow: TextOverflow.ellipsis), subtitle: Text('Room: ${room ?? '-'}'));
}))
])),
actions: [
OutlinedButton.icon(
onPressed: () async {
final instDoc = await FirebaseFirestore.instance.collection(InstitutionRegistrationSchema.collectionName).doc(instId).get();
if (!context.mounted) return;
await showDialog(
context: context,
builder: (c) => ReceiptViewDialog(
title: 'Students Report',
buildPdf: () async => ReceiptService().buildStudentsReportPdf(students: students, instId: instId, institution: instDoc.data(), title: 'Students Report'),
),
);
},
icon: const Icon(Icons.table_view, color: Colors.blue),
label: const Text('Export'),
),
TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
],
);
});
}

Future<void> _showDuesDialog() async {
return showDialog(context: context, builder: (ctx) {
return AlertDialog(
title: const Text('Payment Dues (This Month)'),
content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, children: [
Align(alignment: Alignment.centerLeft, child: Text('Items: $duesThisMonth • Amount: ₹${duesAmountThisMonth.toStringAsFixed(2)}', style: Theme.of(ctx).textTheme.titleMedium)),
const SizedBox(height: 8),
Flexible(child: dueItemsThisMonth.isEmpty ? const Text('No dues this month') : ListView.separated(shrinkWrap: true, itemCount: dueItemsThisMonth.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
final item = dueItemsThisMonth[i];
final s = studentById[item.studentId];
final name = s == null ? item.studentId : ('${s[StudentSchema.firstName] ?? ''} ${s[StudentSchema.lastName] ?? ''}').trim();
final room = s?[StudentSchema.roomNumber] as String?;
final bed = s?[StudentSchema.bedNumber] as int?;
final f = item.fee; final amt = (f[FeeItemSchema.amount] as num? ?? 0).toStringAsFixed(2);
final label = (f[FeeItemSchema.label] as String?) ?? (f[FeeItemSchema.type] == FeeItemSchema.typeMonthly ? 'Monthly' : 'Other');
final dueTs = f[FeeItemSchema.dueDate] as Timestamp?; final due = dueTs?.toDate();
final String dueStr;
if ((f[FeeItemSchema.type] as String?) == FeeItemSchema.typeMonthly) {
final m = f[FeeItemSchema.month] as int?; final y = f[FeeItemSchema.year] as int?;
dueStr = due != null ? '${due.day}/${due.month}/${due.year}' : ((m != null && y != null) ? '$m/$y' : '-');
} else {
dueStr = due == null ? '-' : '${due.day}/${due.month}/${due.year}';
}
final who = name.isEmpty ? (s?[StudentSchema.phoneNumber] ?? '-') : name;
final rb = room == null ? '' : ' • Room $room${bed != null ? ' • Bed $bed' : ''}';
return ListTile(leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange), title: Text('$label • ₹$amt', overflow: TextOverflow.ellipsis), subtitle: Text('$who$rb • Due: $dueStr', overflow: TextOverflow.ellipsis));
}))
])),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
);
});
}

Future<void> _showMonthlyGraphDialog() async {
return showDialog(context: context, builder: (ctx) {
return AlertDialog(
title: Text('Monthly Collections • ${now.month}/${now.year}') ,
content: SizedBox(width: 560, height: 300, child: Padding(padding: const EdgeInsets.only(top: 8), child: LineChart(LineChartData(
gridData: const FlGridData(show: true),
borderData: FlBorderData(show: true),
titlesData: FlTitlesData(
leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: (dailyTotals.length / 6).clamp(1, 6).toDouble(), getTitlesWidget: (value, meta) {
final d = value.toInt() + 1; if (d < 1 || d > dailyTotals.length) return const SizedBox.shrink(); return Text('$d');
})),
),
lineBarsData: [
LineChartBarData(spots: [for (int i = 0; i < dailyTotals.length; i++) FlSpot(i.toDouble(), dailyTotals[i])], isCurved: true, color: Colors.blue, dotData: const FlDotData(show: false))
],
)))),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
);
});
}

Future<void> _showPrevMonthDialog() async {
return showDialog(context: context, builder: (ctx) {
return AlertDialog(
title: Text('Previous Month Collection • ${prevMonthDate.month}/${prevMonthDate.year}') ,
content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
Align(alignment: Alignment.centerLeft, child: Text('Total: ₹${prevMonthCollection.toStringAsFixed(2)}', style: Theme.of(ctx).textTheme.titleMedium)),
const SizedBox(height: 8),
Flexible(child: prevMonthPayments.isEmpty ? const Text('No payments') : ListView.separated(shrinkWrap: true, itemCount: prevMonthPayments.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
final p = prevMonthPayments[i];
final ts = (p[PaymentSchema.paidAt] as Timestamp?)?.toDate();
final sid = p[PaymentSchema.studentId] as String?;
final s = sid != null ? studentById[sid] : null;
final name = s == null ? (sid ?? '-') : ('${s[StudentSchema.firstName] ?? ''} ${s[StudentSchema.lastName] ?? ''}').trim();
final amt = (p[PaymentSchema.amount] as num? ?? 0).toStringAsFixed(2);
final date = ts == null ? '-' : '${ts.day}/${ts.month}';
return ListTile(leading: const Icon(Icons.payments, color: Colors.green), title: Text('₹$amt • $date'), subtitle: Text(name));
}))
])),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
);
});
}

Future<void> _showCarryForwardDialog() async {
return showDialog(context: context, builder: (ctx) {
return AlertDialog(
title: const Text('Carry Forward Dues'),
content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, children: [
Align(alignment: Alignment.centerLeft, child: Text('Total: ₹${carryForwardAmount.toStringAsFixed(2)}', style: Theme.of(ctx).textTheme.titleMedium)),
const SizedBox(height: 8),
Flexible(child: carryForwardItems.isEmpty ? const Text('No carry forward dues') : ListView.separated(shrinkWrap: true, itemCount: carryForwardItems.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
final item = carryForwardItems[i];
final s = studentById[item.studentId];
final name = s == null ? item.studentId : ('${s[StudentSchema.firstName] ?? ''} ${s[StudentSchema.lastName] ?? ''}').trim();
final f = item.fee; final amt = (f[FeeItemSchema.amount] as num? ?? 0).toStringAsFixed(2);
final label = (f[FeeItemSchema.label] as String?) ?? (f[FeeItemSchema.type] == FeeItemSchema.typeMonthly ? 'Monthly' : 'Other');
return ListTile(leading: const Icon(Icons.pending_actions, color: Colors.orange), title: Text('$label • ₹$amt', overflow: TextOverflow.ellipsis), subtitle: Text(name));
}))
])),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
);
});
}

return LayoutBuilder(builder: (ctx, constraints) {
final padding = constraints.maxWidth < 600 ? 16.0 : 32.0; // ListView horizontal padding
final spacing = 12.0; // Wrap spacing
final available = constraints.maxWidth - padding;
final columns = available > 900 ? 3 : (available > 560 ? 2 : 1);
final tileWidth = (available - spacing * (columns - 1)) / columns;
final cardHeight = constraints.maxWidth < 600 ? 100.0 : 120.0;

// Pending confirmation items
final List<({String studentId, Map<String, dynamic> fee})> pendingConfirmItems = [];
for (final entry in feesByStudent.entries) {
for (final f in entry.value) {
if ((f[FeeItemSchema.status] as String? ?? 'pending') == 'to_confirm') {
pendingConfirmItems.add((studentId: entry.key, fee: f));
}
}
}

Future<void> _showPendingConfirmDialog() async {
return showDialog(context: context, builder: (ctx) {
return AlertDialog(
title: const Text('Payments to Review'),
content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, children: [
Align(alignment: Alignment.centerLeft, child: Text('Requests: ${pendingConfirmItems.length}', style: Theme.of(ctx).textTheme.titleMedium)),
const SizedBox(height: 8),
Flexible(child: pendingConfirmItems.isEmpty ? const Text('No pending confirmations') : ListView.separated(shrinkWrap: true, itemCount: pendingConfirmItems.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
final item = pendingConfirmItems[i];
final s = studentById[item.studentId];
final name = s == null ? item.studentId : ('${s[StudentSchema.firstName] ?? ''} ${s[StudentSchema.lastName] ?? ''}').trim();
final f = item.fee; final amt = (f[FeeItemSchema.amount] as num? ?? 0).toStringAsFixed(2);
final label = (f[FeeItemSchema.label] as String?) ?? (f[FeeItemSchema.type] == FeeItemSchema.typeMonthly ? 'Monthly' : 'Other');
return ListTile(leading: const Icon(Icons.mark_email_unread, color: Colors.blue), title: Text('$label • ₹$amt', overflow: TextOverflow.ellipsis), subtitle: Text(name.isEmpty ? (s?[StudentSchema.phoneNumber] ?? '-') : name), trailing: TextButton(onPressed: () { Navigator.pop(ctx); onOpenStudentFees(item.studentId); }, child: const Text('Open')));
}))
])),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
);
});
}

Future<void> _showComplaintsDialog() async {
return showDialog(context: context, builder: (ctx) {
String labelForStatus(String s) {
switch (s) {
case 'acknowledged': return 'Acknowledge';
case 'in_progress': return 'Work-in-progress';
case 'resolved': return 'Resolved';
case 'no_action': return 'No action at this moment';
default: return s;
}
}
return AlertDialog(
title: const Text('Complaints'),
content: SizedBox(width: 620, child: Column(mainAxisSize: MainAxisSize.min, children: [
Align(alignment: Alignment.centerLeft, child: Text('Total: ${complaints.length}', style: Theme.of(ctx).textTheme.titleMedium)),
const SizedBox(height: 8),
Flexible(child: complaints.isEmpty ? const Text('No complaints') : ListView.separated(shrinkWrap: true, itemCount: complaints.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
final c = complaints[i];
final student = c[ComplaintSchema.studentName] as String? ?? '-';
final room = c[ComplaintSchema.roomNumber] as String?;
final subject = c[ComplaintSchema.subject] as String? ?? '';
final message = c[ComplaintSchema.message] as String? ?? '';
final status = c[ComplaintSchema.status] as String? ?? 'no_action';
return ListTile(
leading: const Icon(Icons.report, color: Colors.orange),
title: Text(subject.isEmpty ? '(No subject)' : subject, overflow: TextOverflow.ellipsis),
subtitle: Text('${student}${room != null ? ' • Room $room' : ''}\n$message', overflow: TextOverflow.ellipsis, maxLines: 2),
trailing: PopupMenuButton<String>(
onSelected: (s) => onUpdateComplaintStatus(c[ComplaintSchema.id] as String, s),
itemBuilder: (_) => const [
PopupMenuItem(value: 'acknowledged', child: Text('Acknowledge')),
PopupMenuItem(value: 'in_progress', child: Text('Work-in-progress')),
PopupMenuItem(value: 'resolved', child: Text('Resolved')),
PopupMenuItem(value: 'no_action', child: Text('No action at this moment')),
],
child: Chip(label: Text(labelForStatus(status)), avatar: const Icon(Icons.edit, size: 18, color: Colors.blue)),
),
);
}))
])),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
);
});
}

return ListView(padding: const EdgeInsets.all(16), children: [
LayoutBuilder(builder: (ctx, c) {
final maxW = c.maxWidth;
final isPhone = maxW < 600;
final isTablet = maxW >= 600 && maxW < 900;
final crossAxisCount = isPhone ? 1 : (isTablet ? 3 : 4);
final aspect = isPhone ? 3.2 : (isTablet ? 3.6 : 4.0);
final accomRepo = FirebaseAccommodationRepository();
Future<List<Map<String, dynamic>>> quickRooms() async {
final rooms = await accomRepo.listRooms(instId: instId);
final List<Map<String, dynamic>> out = [];
for (final r in rooms) {
final id = r[RoomSchema.id] as String; final rn = (r[RoomSchema.roomNumber] as String?) ?? '';
final stats = await accomRepo.roomStats(instId: instId, roomId: id);
final total = stats.$1; final occ = stats.$2; final free = total - occ;
out.add({'rn': rn, 'free': free, 'total': total, 'occ': occ, 'category': r[RoomSchema.category]});
}
out.sort((a, b) => (b['free'] as int).compareTo(a['free'] as int));
return out;
}
void _showRoomsBedsDialog() {
showDialog(context: context, builder: (ctx) {
String labelForCategory(String category) { switch (category) { case 'single': return 'Single'; case 'two_sharing': return 'Two Sharing'; case 'three_sharing': return 'Three Sharing'; case 'four_sharing': return 'Four Sharing'; default: return category; } }
return AlertDialog(
title: const Text('Rooms & Beds Overview'),
content: SizedBox(width: 560, child: FutureBuilder<List<Map<String, dynamic>>>(
future: quickRooms(),
builder: (c, snap) {
if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
final data = snap.data!;
if (data.isEmpty) return const Text('No rooms created yet');
return Column(mainAxisSize: MainAxisSize.min, children: [
Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
onPressed: () async {
final instDoc = await FirebaseFirestore.instance.collection(InstitutionRegistrationSchema.collectionName).doc(instId).get();
if (!context.mounted) return;
await showDialog(
context: context,
builder: (c) => ReceiptViewDialog(
title: 'Rooms & Beds Report',
buildPdf: () async {
final rows = data.map((r) => {
'roomNumber': r['rn'],
'category': r['category'],
'occupied': r['occ'],
'available': (r['total'] as int) - (r['occ'] as int),
}).toList();
return ReceiptService().buildAccommodationRoomsReportPdf(instId: instId, institution: instDoc.data(), rows: rows, title: 'Rooms & Beds Report');
},
),
);
},
icon: const Icon(Icons.table_view, color: Colors.blue),
label: const Text('Export'),
)),
const SizedBox(height: 8),
Flexible(child: ListView.separated(shrinkWrap: true, itemCount: data.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
final r = data[i];
final rn = r['rn'] as String; final free = r['free'] as int; final total = r['total'] as int; final occ = r['occ'] as int; final cat = labelForCategory((r['category'] as String?) ?? 'two_sharing');
return ListTile(leading: Icon(Icons.meeting_room, color: Theme.of(context).colorScheme.primary), title: Text('Room $rn • $cat'), subtitle: Text('Beds: $occ/$total occupied • Available: $free'));
}))
]);
},
)),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
);
});
}
final tiles = [
_DashCard(icon: Icons.groups, color: Colors.blue, title: 'Total Students', subtitle: '${students.length}', onTap: _showStudentsDialog),
_DashCard(icon: Icons.bed, color: Theme.of(context).colorScheme.primary, title: 'Rooms & Beds', subtitle: 'Quick view', onTap: _showRoomsBedsDialog, child: FutureBuilder<List<Map<String, dynamic>>>(
future: quickRooms(),
builder: (c, snap) {
if (!snap.hasData || (snap.data?.isEmpty ?? true)) return const SizedBox.shrink();
final items = snap.data!;
return Padding(
padding: const EdgeInsets.only(top: 6),
child: Align(
alignment: Alignment.centerLeft,
child: Builder(builder: (ctx) {
final isLaptop = MediaQuery.of(ctx).size.width < 1200;
if (isLaptop) {
return ActionChip(
label: const Text('Quick view'),
avatar: Icon(Icons.expand_more, size: 16, color: Theme.of(context).colorScheme.primary),
onPressed: _showRoomsBedsDialog,
backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
);
}
return PopupMenuButton<int>(
tooltip: 'Available rooms',
onSelected: (_) {},
position: PopupMenuPosition.under,
constraints: const BoxConstraints(minWidth: 240, maxWidth: 320, maxHeight: 320),
itemBuilder: (_) => [
for (final r in items)
PopupMenuItem<int>(
value: 0,
child: Row(children: [
Icon(Icons.meeting_room, color: Theme.of(context).colorScheme.primary, size: 18),
const SizedBox(width: 8),
Expanded(child: Text('Room ${r['rn']}', overflow: TextOverflow.ellipsis)),
Text('${r['free']} free/${r['total']}', style: const TextStyle(fontWeight: FontWeight.w500))
]),
),
],
child: Chip(label: const Text('Quick view'), avatar: Icon(Icons.expand_more, size: 16, color: Theme.of(context).colorScheme.primary), backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)),
);
})
),
);
},
)),
_DashCard(icon: Icons.report, color: Colors.red, title: 'Complaints', subtitle: '${complaints.length} items', onTap: _showComplaintsDialog),
_DashCard(icon: Icons.pending_actions, color: Colors.orange, title: 'Payment Dues', subtitle: '$duesThisMonth • ₹${duesAmountThisMonth.toStringAsFixed(0)}', onTap: _showDuesDialog),
_DashCard(icon: Icons.notifications_active, color: Colors.blue, title: 'To Review', subtitle: '${pendingConfirmItems.length} requests', onTap: _showPendingConfirmDialog),
_DashCard(icon: Icons.payments, color: Colors.blueGrey, title: 'Received', subtitle: '₹${paid.toStringAsFixed(0)}', onTap: () => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Received'), content: Text('Total received so far: ₹${paid.toStringAsFixed(2)}'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]))),
];
return GridView.builder(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: aspect),
itemCount: tiles.length,
itemBuilder: (_, i) => tiles[i],
);
}),
const SizedBox(height: 12),
// Secondary insights: use the SAME grid config so all tiles are equal-sized
LayoutBuilder(builder: (ctx, c) {
final maxW = c.maxWidth;
final isPhone = maxW < 600;
final isTablet = maxW >= 600 && maxW < 900;
final crossAxisCount = isPhone ? 1 : (isTablet ? 3 : 4);
final aspect = isPhone ? 3.2 : (isTablet ? 3.6 : 4.0);
final secondary = [
_DashCard(icon: Icons.show_chart, color: Colors.purple, title: 'Monthly Graph', subtitle: 'Collections this month', onTap: _showMonthlyGraphDialog, child: Padding(padding: const EdgeInsets.only(top: 8), child: _MiniLineChart(data: dailyTotals))),
_DashCard(icon: Icons.calendar_month, color: Colors.green, title: 'Prev Month', subtitle: '₹${prevMonthCollection.toStringAsFixed(0)}', onTap: _showPrevMonthDialog),
_DashCard(icon: Icons.report, color: Colors.red, title: 'Carry Forward', subtitle: '₹${carryForwardAmount.toStringAsFixed(0)}', onTap: _showCarryForwardDialog),
_DashCard(icon: Icons.account_balance_wallet, color: Colors.teal, title: 'Expected', subtitle: '₹${expected.toStringAsFixed(0)}', onTap: () => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Expected Total'), content: Text('Total expected (unpaid): ₹${(expected).toStringAsFixed(2)}'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]))),
_DashCard(icon: Icons.warning_amber_rounded, color: Colors.deepOrange, title: 'Not Received', subtitle: '₹${notReceived.toStringAsFixed(0)}', onTap: () => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Not Received (This Month)'), content: Text('Dues: ₹${duesAmountThisMonth.toStringAsFixed(2)}\nReceived: ₹${receivedThisMonth.toStringAsFixed(2)}\nPending: ₹${notReceived.toStringAsFixed(2)}'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]))),
];
return GridView.builder(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: aspect),
itemCount: secondary.length,
itemBuilder: (_, i) => secondary[i],
);
})
]);
});
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

class _StudentsTab extends StatelessWidget {
final String instId;
final List<Map<String, dynamic>> students;
final Map<String, List<Map<String, dynamic>>> feesByStudent;
final void Function(String studentId) onApprove;
final void Function(String studentId, bool enabled) onEnable;

final void Function(String studentId) onAssignBed;
final void Function(String studentId) onSetPassword;
final void Function(String studentId) onManageFees;
final void Function(String? room) onFilter;
final String searchQuery;
final ValueChanged<String> onSearchChanged;
final Future<void> Function(String studentId, Map<String, dynamic> fee) onMarkPaid;
final Future<void> Function(String studentId, Map<String, dynamic> fee) onApproveSubmitted;
final VoidCallback onRefresh;
const _StudentsTab({required this.instId, required this.students, required this.feesByStudent, required this.onApprove, required this.onEnable, required this.onAssignBed, required this.onSetPassword, required this.onManageFees, required this.onFilter, required this.searchQuery, required this.onSearchChanged, required this.onMarkPaid, required this.onApproveSubmitted, required this.onRefresh});
String _labelForCategory(String category) {
switch (category) {
case 'single':
return 'Single';
case 'two_sharing':
return 'Two Sharing';
case 'three_sharing':
return 'Three Sharing';
case 'four_sharing':
return 'Four Sharing';
default:
return category;
}
}
@override
Widget build(BuildContext context) {
return Column(children: [
Padding(
padding: const EdgeInsets.all(12),
child: Align(
alignment: Alignment.centerLeft,
child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
ConstrainedBox(
constraints: const BoxConstraints(maxWidth: 300),
child: Builder(builder: (_) {
final _c = TextEditingController(text: searchQuery);
_c.selection = TextSelection.fromPosition(TextPosition(offset: _c.text.length));
return TextField(
controller: _c,
onChanged: onSearchChanged,
decoration: InputDecoration(
labelText: 'Search',
hintText: 'Name, phone or room',
border: const OutlineInputBorder(),
prefixIcon: const Icon(Icons.search, color: Colors.blue),
suffixIcon: (searchQuery.isEmpty)
? null
: IconButton(onPressed: () => onSearchChanged(''), icon: const Icon(Icons.clear, color: Colors.blue)),
),
);
}),
),
OutlinedButton.icon(
icon: const Icon(Icons.table_view, color: Colors.blue),
label: const Text('Export'),
onPressed: () async {
// Build filtered list (same logic as grid)
final List<Map<String, dynamic>> filtered = students.where((s) {
final first = (s[StudentSchema.firstName] as String?)?.toLowerCase().trim() ?? '';
final last = (s[StudentSchema.lastName] as String?)?.toLowerCase().trim() ?? '';
final phone = (s[StudentSchema.phoneNumber] as String?)?.toLowerCase().trim() ?? '';
final room = (s[StudentSchema.roomNumber] as String?)?.toLowerCase().trim() ?? '';
final name = '$first $last';
final q = searchQuery.toLowerCase();
if (q.isEmpty) return true;
return name.contains(q) || phone.contains(q) || room.contains(q);
}).toList();
final instDoc = await FirebaseFirestore.instance.collection(InstitutionRegistrationSchema.collectionName).doc(instId).get();
if (!context.mounted) return;
await showDialog(
context: context,
builder: (ctx) => ReceiptViewDialog(
title: 'Students Report',
buildPdf: () async => ReceiptService().buildStudentsReportPdf(students: filtered, instId: instId, institution: instDoc.data(), title: 'Students Report'),
),
);
},
),
]),
)
),
Expanded(
child: LayoutBuilder(
builder: (ctx, constraints) {
// Match Accommodation tile sizing: 3 columns on wide screens, 1 column on mobile
const spacing = 12.0;
const horizontalPadding = 24.0; // 12 left + 12 right
final available = constraints.maxWidth - horizontalPadding;
final isDesktop = constraints.maxWidth > 900;
final tileWidth = isDesktop ? (available - spacing * 2) / 3 : available;
final filtered = students.where((s) {
final first = (s[StudentSchema.firstName] as String?)?.toLowerCase().trim() ?? '';
final last = (s[StudentSchema.lastName] as String?)?.toLowerCase().trim() ?? '';
final phone = (s[StudentSchema.phoneNumber] as String?)?.toLowerCase().trim() ?? '';
final room = (s[StudentSchema.roomNumber] as String?)?.toLowerCase().trim() ?? '';
final name = '$first $last';
final q = searchQuery.toLowerCase();
if (q.isEmpty) return true;
return name.contains(q) || phone.contains(q) || room.contains(q);
}).toList();

Widget buildStudentCard(Map<String, dynamic> s) {
final fullName = '${s[StudentSchema.firstName] ?? ''} ${s[StudentSchema.lastName] ?? ''}'.trim();
final pending = s[StudentSchema.status] == StudentSchema.statusPending;
final enabled = s[StudentSchema.enabled] as bool? ?? true;
final room = s[StudentSchema.roomNumber] as String?;
final bed = s[StudentSchema.bedNumber] as int?;
final roomCat = s[StudentSchema.roomCategory] as String?;
final sid = s[StudentSchema.id] as String;
return Card(
child: Padding(
padding: const EdgeInsets.all(12),
child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
Row(children: [
const Icon(Icons.person, color: Colors.blue),
const SizedBox(width: 8),
Expanded(
child: InkWell(
onTap: () async {
await showDialog(context: context, builder: (ctx) => _StudentProfileEditorDialog(instId: instId, student: s));
onRefresh();
},
child: Text(fullName.isEmpty ? (s[StudentSchema.phoneNumber] as String? ?? '') : fullName, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
),
),
const SizedBox(width: 8),
if (pending) Chip(label: const Text('Pending')) else if (!enabled) Chip(label: const Text('Disabled')) else const SizedBox.shrink(),
]),

const SizedBox(height: 6),
const SizedBox(height: 6),
Builder(builder: (ctx) {
final createdTs = s[StudentSchema.createdAt] as Timestamp?; final created = createdTs?.toDate();
final createdStr = created == null ? '-' : '${created.day}/${created.month}/${created.year}';
final disabledReason = s[StudentSchema.disabledReason] as String?;
final disabledAtTs = s[StudentSchema.disabledAt] as Timestamp?; final disabledAt = disabledAtTs?.toDate();
final reenabledAtTs = s[StudentSchema.reenabledAt] as Timestamp?; final reenabledAt = reenabledAtTs?.toDate();
return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
// Row 2: Phone (key + value)
Row(children: [
const Icon(Icons.call, color: Colors.green),
const SizedBox(width: 8),
Expanded(child: Text('Phone: ${s[StudentSchema.phoneNumber] ?? '-'}', style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
]),
const SizedBox(height: 4),
// Row 3: Room/Bed (with icon, tappable to assign)
InkWell(
onTap: enabled
? () async {
// If already assigned, ask to release the room/bed
if (room != null || bed != null) {
final ok = await showDialog<bool>(
context: context,
builder: (ctx) => AlertDialog(
title: const Text('Release Assigned Room?'),
content: Text('This student is assigned to Room ${room ?? '-'}${bed != null ? ', Bed $bed' : ''}. Do you want to release it?'),
actions: [
TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
],
),
);
if (ok == true) {
try {
await FirebaseAccommodationRepository().releaseBedByStudent(instId: instId, studentId: sid);
await FirebaseFirestore.instance
.collection(InstitutionRegistrationSchema.collectionName)
.doc(instId)
.collection(InstitutionRegistrationSchema.studentsSubcollection)
.doc(sid)
.update({
StudentSchema.roomNumber: null,
StudentSchema.bedNumber: null,
StudentSchema.roomCategory: null,
StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
});
if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room released')));
}
onRefresh();
} catch (e) {
if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}
}
return;
}
// Not assigned yet: start assignment flow
onAssignBed(sid);
}
: () {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room assignment is not allowed because the account is disabled.'), backgroundColor: Colors.red));
},
child: Padding(
padding: const EdgeInsets.symmetric(vertical: 2),
child: room != null
? FutureBuilder<(String, Map<String, dynamic>)?>(
future: FirebaseAccommodationRepository().findRoomByNumber(instId: instId, roomNumber: room),
builder: (context, snapshot) {
String displayCategory = '';
if (snapshot.hasData && snapshot.data != null) {
final roomData = snapshot.data!.$2;
final categoryFromRoom = roomData[RoomSchema.category] as String?;
final finalCategory = roomCat ?? categoryFromRoom ?? 'two_sharing';
displayCategory = ' • ${_labelForCategory(finalCategory)}';
} else if (roomCat != null) {
displayCategory = ' • ${_labelForCategory(roomCat)}';
}

return Row(children: [
Icon(Icons.bed, color: Theme.of(context).colorScheme.primary),
const SizedBox(width: 8),
Expanded(child: Text('Room ${room ?? '-'}, Bed ${bed?.toString() ?? '-'}$displayCategory', style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
]);
},
)
: Row(children: [
Icon(Icons.bed, color: Theme.of(context).colorScheme.primary),
const SizedBox(width: 8),
Expanded(child: Text('Room ${room ?? '-'}, Bed ${bed?.toString() ?? '-'}', style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
]),
),
),
const SizedBox(height: 4),
// Row 4: Amount (with icon)
room == null
? Row(children: [
const Icon(Icons.attach_money, color: Colors.green),
const SizedBox(width: 8),
const Expanded(child: Text('-', overflow: TextOverflow.ellipsis)),
])
: FutureBuilder<Map<String, dynamic>?>(
future: FirebaseAccommodationRepository().findRoomByNumber(instId: instId, roomNumber: room).then((v) => v?.$2),
builder: (c, snap) {
if (!snap.hasData) {
return Row(children: [
const Icon(Icons.attach_money, color: Colors.green),
const SizedBox(width: 8),
Expanded(child: Text('Rs. -', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
]);
}
final cat = (snap.data?[RoomSchema.category] as String?) ?? 'two_sharing';
return FutureBuilder<Map<String, Map<String, num>>>(
future: FirebaseAccommodationRepository().getFoodPricing(instId: instId),
builder: (c2, p) {
if (!p.hasData) {
return Row(children: [
const Icon(Icons.attach_money, color: Colors.green),
const SizedBox(width: 8),
Expanded(child: Text('Rs. -', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
]);
}
final pricing = p.data!;
final plan = (s[StudentSchema.foodPlan] as String?) ?? 'with';
final num? amt = pricing[plan]?[cat];
return Row(children: [
const Icon(Icons.attach_money, color: Colors.green),
const SizedBox(width: 8),
Expanded(child: amt == null
? Text('Rs. -', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
: Text.rich(
TextSpan(children: [
TextSpan(text: 'Rs. ${amt.toString()}', style: const TextStyle(fontWeight: FontWeight.bold)),
TextSpan(text: plan == 'with' ? ' (With Food)' : ' (Without Food)')
]),
style: Theme.of(context).textTheme.bodyMedium,
overflow: TextOverflow.ellipsis,
)),
]);
},
);
},
),
if (!enabled && (disabledReason != null || disabledAt != null)) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Disabled${disabledReason != null ? ': $disabledReason' : ''}${disabledAt != null ? ' • ${disabledAt.day}/${disabledAt.month}/${disabledAt.year} ${disabledAt.hour.toString().padLeft(2, '0')}:${disabledAt.minute.toString().padLeft(2, '0')}' : ''}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red.withValues(alpha: 0.85)))) ,
]);
}),
const SizedBox(height: 8),
Wrap(
spacing: 8,
runSpacing: 8,
children: [
if (pending) FilledButton.icon(
onPressed: () => onApprove(s[StudentSchema.id] as String),
icon: const Icon(Icons.check, color: Colors.white),
label: const Text('Approve Login'),
style: FilledButton.styleFrom(backgroundColor: Colors.green),
),
],
),
]),
),
);
}

return SingleChildScrollView(
child: Padding(
padding: const EdgeInsets.all(12),
child: Wrap(
spacing: spacing,
runSpacing: spacing,
children: [
for (final s in filtered) SizedBox(width: tileWidth, child: buildStudentCard(s)),
],
),
),
);
},
),
),
]);
}
}

class _WelcomeBannerTitle extends StatelessWidget {
final String? instName;
final String? adminName;
final String? address;
const _WelcomeBannerTitle({required this.instName, required this.adminName, required this.address});
@override
Widget build(BuildContext context) {
final theme = Theme.of(context);
final isSmallScreen = MediaQuery.of(context).size.width < 600;
final onAppBar = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
final titleStyle = (isSmallScreen ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)
?.copyWith(color: onAppBar, fontWeight: FontWeight.w700);
final subtitleStyle = (isSmallScreen ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
?.copyWith(color: onAppBar.withValues(alpha: 0.9));
final addressStyle = theme.textTheme.bodySmall?.copyWith(color: onAppBar.withValues(alpha: 0.85));
return Align(
alignment: Alignment.centerLeft,
child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
Text('Welcome', style: theme.textTheme.labelSmall?.copyWith(color: onAppBar.withValues(alpha: 0.9))),
const SizedBox(height: 2),
Text(instName?.isNotEmpty == true ? instName! : '-', style: titleStyle, overflow: TextOverflow.ellipsis),
if (adminName != null && adminName!.isNotEmpty && !isSmallScreen) Padding(
padding: const EdgeInsets.only(top: 2),
child: Text('Admin: $adminName', style: subtitleStyle, overflow: TextOverflow.ellipsis),
),
if (address != null && address!.isNotEmpty && !isSmallScreen) Padding(
padding: const EdgeInsets.only(top: 2),
child: Text(address!, style: addressStyle, overflow: TextOverflow.ellipsis, maxLines: 1),
),
]),
);
}
}

class _PaymentsTab extends StatefulWidget {
final List<Map<String, dynamic>> payments;
final List<Map<String, dynamic>> students;
final String instId;
const _PaymentsTab({required this.payments, required this.students, required this.instId});
@override
State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
String _status = 'all'; // all | paid | pending
String? _room;
DateTimeRange? _customRange;
String _quick = 'all'; // all | this_week | this_month | custom

Map<String, Map<String, dynamic>> get _studentById => {for (final s in widget.students) s[StudentSchema.id] as String: s};
String _query = '';
String? _studentId;

DateTimeRange? _computeQuickRange() {
final now = DateTime.now();
if (_quick == 'all') return null;
if (_quick == 'this_week') {
final weekday = now.weekday; // 1=Mon
final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: weekday - 1));
final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
return DateTimeRange(start: start, end: end);
}
if (_quick == 'this_month') {
final start = DateTime(now.year, now.month, 1);
final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
return DateTimeRange(start: start, end: end);
}
return _customRange;
}

bool _within(DateTime? date, DateTimeRange? range) {
if (range == null || date == null) return true;
return !date.isBefore(range.start) && !date.isAfter(range.end);
}

List<Map<String, dynamic>> get _filtered {
final range = _computeQuickRange();
final q = _query.toLowerCase().trim();
return widget.payments.where((p) {
final status = (p[PaymentSchema.status] as String? ?? 'paid');
if (_status != 'all' && status != _status) return false;
// Date filter: paidAt for paid; createdAt for pending
final paidAt = (p[PaymentSchema.paidAt] as Timestamp?)?.toDate();
final created = (p[PaymentSchema.createdAt] as Timestamp?)?.toDate();
final d = status == 'paid' ? paidAt : created;
if (!_within(d, range)) return false;
if (_room != null && _room!.isNotEmpty) {
final sid = p[PaymentSchema.studentId] as String?;
final s = sid != null ? _studentById[sid] : null;
final pRoom = (p[PaymentSchema.roomNumber] as String?);
final sRoom = s != null ? s[StudentSchema.roomNumber] as String? : null;
final roomToCheck = pRoom ?? sRoom;
if (roomToCheck != _room) return false;
}
if (q.isNotEmpty) {
final sid = p[PaymentSchema.studentId] as String?;
final s = sid != null ? _studentById[sid] : null;
final first = (s?[StudentSchema.firstName] as String?)?.toLowerCase().trim() ?? '';
final last = (s?[StudentSchema.lastName] as String?)?.toLowerCase().trim() ?? '';
final phone = (s?[StudentSchema.phoneNumber] as String?)?.toLowerCase().trim() ?? '';
final name = '$first $last'.trim();
if (!(name.contains(q) || phone.contains(q))) return false;
}
return true;
}).toList();
}

@override
Widget build(BuildContext context) {
final rooms = widget.students.map((s) => (s[StudentSchema.roomNumber] as String?) ?? '').where((v) => v.isNotEmpty).toSet().toList()..sort();
final isSmallScreen = MediaQuery.of(context).size.width < 600;
final List<Map<String, dynamic>> studentsForDropdown = (_room != null && _room!.isNotEmpty)
? widget.students.where((s) => (((s[StudentSchema.roomNumber] as String?) ?? '') == _room)).toList()
: widget.students;

// Sort students alphabetically by name
studentsForDropdown.sort((a, b) {
final aFirst = (a[StudentSchema.firstName] as String?)?.trim() ?? '';
final aLast = (a[StudentSchema.lastName] as String?)?.trim() ?? '';
final aName = ('$aFirst $aLast').trim().toLowerCase();

final bFirst = (b[StudentSchema.firstName] as String?)?.trim() ?? '';
final bLast = (b[StudentSchema.lastName] as String?)?.trim() ?? '';
final bName = ('$bFirst $bLast').trim().toLowerCase();

return aName.compareTo(bName);
});

if (widget.payments.isEmpty) return const Center(child: Text('No payments yet'));

String _rangeLabel() {
final r = _computeQuickRange();
if (r == null) return 'All time';
String two(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
return '${two(r.start)} - ${two(r.end)}';
}

Future<void> _navigateToFilters() async {
final result = await Navigator.push<Map<String, dynamic>>(
context,
MaterialPageRoute(
builder: (context) => PaymentFiltersPage(
students: widget.students,
currentQuick: _quick,
currentCustomRange: _customRange,
currentStatus: _status,
currentRoom: _room,
currentStudentId: _studentId,
),
),
);

if (result != null) {
setState(() {
_quick = result['quick'] ?? 'all';
_customRange = result['customRange'];
_status = result['status'] ?? 'all';
_room = result['room'];
_studentId = result['studentId'];
if (_studentId != null) {
final student = widget.students.firstWhere(
(s) => s[StudentSchema.id] == _studentId,
orElse: () => {},
);
final first = (student[StudentSchema.firstName] as String?)?.trim() ?? '';
final last = (student[StudentSchema.lastName] as String?)?.trim() ?? '';
final phone = (student[StudentSchema.phoneNumber] as String?)?.trim() ?? '';
final name = ('$first $last').trim();
_query = name.isNotEmpty ? name : phone;
} else {
_query = '';
}
});
}
}

bool _hasActiveFilters() {
return _quick != 'all' || _status != 'all' || _room != null || _studentId != null;
}

void _clearAllFilters() {
setState(() {
_quick = 'all';
_customRange = null;
_status = 'all';
_room = null;
_studentId = null;
_query = '';
});
}

String _getStudentName(String studentId) {
final student = _studentById[studentId];
if (student == null) return studentId;
final first = (student[StudentSchema.firstName] as String?)?.trim() ?? '';
final last = (student[StudentSchema.lastName] as String?)?.trim() ?? '';
final name = ('$first $last').trim();
return name.isEmpty ? (student[StudentSchema.phoneNumber] as String? ?? studentId) : name;
}

String _getTotalAmount() {
final total = _filtered.fold<double>(0.0, (sum, payment) {
return sum + ((payment[PaymentSchema.amount] as num?) ?? 0).toDouble();
});
return total.toStringAsFixed(2);
}

Future<void> _downloadPdf() async {
final instDoc = await FirebaseFirestore.instance.collection(InstitutionRegistrationSchema.collectionName).doc(widget.instId).get();
final filtersDesc = 'Range: ${_rangeLabel()} • Status: ${_status.toUpperCase()}${_room != null ? ' • Room: $_room' : ''}';
await showDialog(
context: context,
builder: (ctx) => ReceiptViewDialog(
title: 'Payments Report',
buildPdf: () async => ReceiptService().buildPaymentsReportPdf(
payments: _filtered,
studentById: _studentById,
institution: instDoc.data(),
filtersDescription: filtersDesc,
selectedStudentId: _studentId,
),
),
);
}

return ListView(
padding: const EdgeInsets.all(12),
children: [
// Action Buttons Row
Card(
child: Padding(
padding: const EdgeInsets.all(16),
child: Row(
children: [
Expanded(
child: ElevatedButton.icon(
onPressed: () => _navigateToFilters(),
icon: const Icon(Icons.filter_list),
label: const Text('Filter Payments'),
style: ElevatedButton.styleFrom(
padding: const EdgeInsets.symmetric(vertical: 12),
),
),
),
const SizedBox(width: 12),
Expanded(
child: OutlinedButton.icon(
onPressed: _filtered.isEmpty ? null : _downloadPdf,
icon: const Icon(Icons.download),
label: const Text('Download Report'),
style: OutlinedButton.styleFrom(
padding: const EdgeInsets.symmetric(vertical: 12),
),
),
),
],
),
),
),

// Filter Summary
if (_hasActiveFilters()) ...[
Card(
color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
const Icon(Icons.filter_alt, size: 20),
const SizedBox(width: 8),
Text('Active Filters', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
const Spacer(),
TextButton.icon(
onPressed: _clearAllFilters,
icon: const Icon(Icons.clear, size: 16),
label: const Text('Clear All'),
style: TextButton.styleFrom(
padding: EdgeInsets.zero,
minimumSize: const Size(0, 0),
tapTargetSize: MaterialTapTargetSize.shrinkWrap,
),
),
],
),
const SizedBox(height: 8),
Wrap(
spacing: 8,
runSpacing: 4,
children: [
if (_quick != 'all')
Chip(
label: Text('Duration: ${_rangeLabel()}'),
onDeleted: () => setState(() {
_quick = 'all';
_customRange = null;
}),
),
if (_status != 'all')
Chip(
label: Text('Status: ${_status.toUpperCase()}'),
onDeleted: () => setState(() => _status = 'all'),
),
if (_room != null)
Chip(
label: Text('Room: $_room'),
onDeleted: () => setState(() => _room = null),
),
if (_studentId != null)
Chip(
label: Text('Student: ${_getStudentName(_studentId!)}'),
onDeleted: () => setState(() {
_studentId = null;
_query = '';
}),
),
],
),
],
),
),
),
],
if (_room != null && _room!.isNotEmpty) ...[
const SizedBox(height: 8),
Card(
color: Colors.blue.withValues(alpha: 0.03),
child: Padding(
padding: const EdgeInsets.all(8),
child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
Text('Students in Room${_room!}', style: Theme.of(context).textTheme.titleSmall),
const SizedBox(height: 6),
Wrap(spacing: 6, runSpacing: 6, children: [
for (final s in widget.students.where((e) => (((e[StudentSchema.roomNumber] as String?) ?? '') == _room)))
Chip(label: Text((('${(s[StudentSchema.firstName] as String?)?.trim() ?? ''} ${(s[StudentSchema.lastName] as String?)?.trim() ?? ''}').trim().isNotEmpty
? ('${(s[StudentSchema.firstName] as String?)?.trim() ?? ''} ${(s[StudentSchema.lastName] as String?)?.trim() ?? ''}').trim()
: ((s[StudentSchema.phoneNumber] as String?) ?? '-')), overflow: TextOverflow.ellipsis))
]),
]),
),
),
]
,

// Results Summary
Card(
child: Padding(
padding: const EdgeInsets.all(16),
child: Row(
children: [
const Icon(Icons.receipt_long, size: 20),
const SizedBox(width: 12),
Text('${_filtered.length} payment${_filtered.length == 1 ? '' : 's'} found',
style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
const Spacer(),
if (_filtered.isNotEmpty) ...[
Text('Total: ₹${_getTotalAmount()}',
style: Theme.of(context).textTheme.titleMedium?.copyWith(
fontWeight: FontWeight.bold,
color: Theme.of(context).primaryColor,
)),
],
],
),
),
),

const SizedBox(height: 8),
if (_filtered.isEmpty)
const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No payments match filters')))
else ...[
for (final p in _filtered)
_PaymentListCard(payment: p, student: _studentById[p[PaymentSchema.studentId] as String?], instId: widget.instId),
],
],
);
}
}

class _PaymentListCard extends StatelessWidget {
final Map<String, dynamic> payment;
final Map<String, dynamic>? student;
final String instId;
const _PaymentListCard({required this.payment, required this.student, required this.instId});
@override
Widget build(BuildContext context) {
final ts = (payment[PaymentSchema.paidAt] as Timestamp?)?.toDate();
final created = (payment[PaymentSchema.createdAt] as Timestamp?)?.toDate();
final status = payment[PaymentSchema.status] as String? ?? 'paid';
final isPaid = status == 'paid';
final amount = (payment[PaymentSchema.amount] as num? ?? 0).toStringAsFixed(2);
final method = (payment[PaymentSchema.method] as String? ?? '').toUpperCase();
final fee = (payment[PaymentSchema.feeLabel] as String?) ?? '';
final first = (student?[StudentSchema.firstName] as String?)?.trim() ?? '';
final last = (student?[StudentSchema.lastName] as String?)?.trim() ?? '';
final phone = (student?[StudentSchema.phoneNumber] as String?)?.trim();
final name = ('$first $last').trim();
final room = (payment[PaymentSchema.roomNumber] as String?) ?? (student != null ? student![StudentSchema.roomNumber] as String? : null);
final bed = student != null ? student![StudentSchema.bedNumber] as int? : null;
final roomBed = room == null ? '-' : (bed == null ? 'Room $room' : 'Room $room • Bed $bed');

return Card(
child: ListTile(
leading: Icon(Icons.receipt_long, color: isPaid ? Colors.green : Colors.blue),
title: Text(name.isEmpty ? (phone ?? '-') : name, overflow: TextOverflow.ellipsis),
subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
Text('₹$amount • $method • ${status.toUpperCase()}', overflow: TextOverflow.ellipsis),
Text('${roomBed}${fee.isNotEmpty ? ' • $fee' : ''} • ${(isPaid ? ts : created) != null ? '${(isPaid ? ts : created)!.day}/${(isPaid ? ts : created)!.month}/${(isPaid ? ts : created)!.year}' : ''}', overflow: TextOverflow.ellipsis),
]),
trailing: Row(mainAxisSize: MainAxisSize.min, children: []),
),
);
}
}


class _AccommodationTab extends StatefulWidget {
final String instId;
const _AccommodationTab({required this.instId});
@override
State<_AccommodationTab> createState() => _AccommodationTabState();
}

class _AccommodationTabState extends State<_AccommodationTab> {
final _repo = FirebaseAccommodationRepository();
final _feeRepo = FirebaseFeeRepository();
bool _loading = true;
List<Map<String, dynamic>> _rooms = [];
String _bedFilter = 'all'; // all | occupied | available
Map<String, num> _withFood = {};
Map<String, num> _withoutFood = {};

@override
void initState() {
super.initState();
_load();
}

Future<void> _load() async {
setState(() => _loading = true);
final roomsData = await _repo.listRooms(instId: widget.instId);
// Sort rooms by room number (try numeric, fallback to string)
roomsData.sort((a, b) {
final ra = (a[RoomSchema.roomNumber] as String?) ?? '';
final rb = (b[RoomSchema.roomNumber] as String?) ?? '';
final ia = int.tryParse(ra);
final ib = int.tryParse(rb);
if (ia != null && ib != null) return ia.compareTo(ib);
return ra.compareTo(rb);
});
final pricing = await _repo.getFoodPricing(instId: widget.instId);
if (!mounted) return;
setState(() {
_rooms = roomsData;
_withFood = pricing['with'] ?? {};
_withoutFood = pricing['without'] ?? {};
_loading = false;
});
}

Future<void> _addRoom() async {
String? category = 'two_sharing';
final roomCtrl = TextEditingController();
final rn = await showDialog<(String room, String category)?>(context: context, builder: (ctx) => AlertDialog(
title: const Text('Add Room'),
content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room number', border: OutlineInputBorder())),
const SizedBox(height: 8),
DropdownButtonFormField<String>(value: category, items: const [
DropdownMenuItem(value: 'single', child: Text('Single')),
DropdownMenuItem(value: 'two_sharing', child: Text('Two Sharing')),
DropdownMenuItem(value: 'three_sharing', child: Text('Three Sharing')),
DropdownMenuItem(value: 'four_sharing', child: Text('Four Sharing')),
], onChanged: (v) { category = v; }, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder())),
])),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () {
final r = roomCtrl.text.trim(); if (r.isEmpty || category == null) return; Navigator.pop(ctx, (r, category!));
}, child: const Text('Save'))],
));
if (rn == null) return;
try {
await _repo.createRoom(instId: widget.instId, roomNumber: rn.$1, category: rn.$2);
await _load();
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room added')));
} catch (e) {
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

Future<void> _assignInRoom(String roomId, String roomNumber) async {
final ctrl = TextEditingController();
final studentId = await showDialog<String?>(context: context, builder: (ctx) => AlertDialog(
title: Text('Assign Bed • Room $roomNumber'),
content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Student ID', border: OutlineInputBorder())),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Next'))],
));
if (studentId == null || studentId.isEmpty) return;
try {
// Read room category and pricing
final roomSnap = await FirebaseFirestore.instance
.collection(InstitutionRegistrationSchema.collectionName)
.doc(widget.instId)
.collection(RoomSchema.collectionName)
.doc(roomId)
.get();
final category = (roomSnap.data()?[RoomSchema.category] as String?) ?? 'two_sharing';
final pricing = await _repo.getFoodPricing(instId: widget.instId);
final withAmt = pricing['with']?[category];
final withoutAmt = pricing['without']?[category];

// List available beds and let admin pick a specific bed
final beds = await _repo.listBeds(instId: widget.instId, roomId: roomId);
final freeBeds = beds.where((b) => (b[BedSchema.occupied] as bool? ?? false) == false).toList()..sort((a, b) => (a[BedSchema.bedNumber] as int).compareTo(b[BedSchema.bedNumber] as int));
if (freeBeds.isEmpty) { throw Exception('No free bed available in this room'); }
final selectedBed = await showDialog<int?>(context: context, builder: (ctx) => AlertDialog(
title: Text('Select Bed • Room $roomNumber'),
content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
if (withAmt != null || withoutAmt != null)
Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)), child: Builder(builder: (_) {
final wf = withAmt != null ? '₹${withAmt.toString()}' : '-';
final wof = withoutAmt != null ? '₹${withoutAmt.toString()}' : '-';
final charges = 'Charges for ${_labelForCategory(category)} • With Food: $wf • Without Food: $wof';
return Text(charges, style: Theme.of(ctx).textTheme.bodySmall);
})),
Expanded(child: ListView.separated(shrinkWrap: true, itemCount: freeBeds.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
final bn = freeBeds[i][BedSchema.bedNumber] as int? ?? 0;
return ListTile(leading: const Icon(Icons.bed, color: Colors.green), title: Text('Bed $bn'), trailing: FilledButton(onPressed: () => Navigator.pop(ctx, bn), child: const Text('Assign')));
}))
])),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
));
if (selectedBed == null) return;
await _repo.assignSpecificBed(instId: widget.instId, roomId: roomId, bedNumber: selectedBed, studentId: studentId);
await FirebaseFirestore.instance
.collection(InstitutionRegistrationSchema.collectionName)
.doc(widget.instId)
.collection(InstitutionRegistrationSchema.studentsSubcollection)
.doc(studentId)
.update({
StudentSchema.roomNumber: roomNumber,
StudentSchema.bedNumber: selectedBed,
StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
});

// Prompt for plan and apply monthly charge
final chosenPlan = await _promptAndApplyPlan(studentId: studentId, category: category);
if (chosenPlan != null) {
await FirebaseFirestore.instance
.collection(InstitutionRegistrationSchema.collectionName)
.doc(widget.instId)
.collection(InstitutionRegistrationSchema.studentsSubcollection)
.doc(studentId)
.update({
StudentSchema.foodPlan: chosenPlan,
StudentSchema.roomCategory: category,
StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
});
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Food plan set: ${chosenPlan == 'with' ? 'With Food' : 'Without Food'}')));
}
}

await _load();
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assigned Bed $selectedBed in Room $roomNumber')));
} catch (e) {
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

Future<void> _assignToBed(String roomId, String roomNumber, int bedNumber) async {
try {
// Determine room category and pricing info
final roomSnap = await FirebaseFirestore.instance
.collection(InstitutionRegistrationSchema.collectionName)
.doc(widget.instId)
.collection(RoomSchema.collectionName)
.doc(roomId)
.get();
final category = (roomSnap.data()?[RoomSchema.category] as String?) ?? 'two_sharing';
final pricing = await _repo.getFoodPricing(instId: widget.instId);
final withAmt = pricing['with']?[category];
final withoutAmt = pricing['without']?[category];

final snap = await FirebaseFirestore.instance
.collection(InstitutionRegistrationSchema.collectionName)
.doc(widget.instId)
.collection(InstitutionRegistrationSchema.studentsSubcollection)
.where(StudentSchema.enabled, isEqualTo: true)
.where(StudentSchema.status, isEqualTo: StudentSchema.statusApproved)
.get();
final List<Map<String, dynamic>> eligible = [];
for (final d in snap.docs) {
final data = d.data();
if (data[StudentSchema.bedNumber] == null) {
if ((data[StudentSchema.id] as String?) == null) {
data[StudentSchema.id] = d.id;
}
eligible.add(data);
}
}
if (!mounted) return;
final selectedId = await showDialog<String?>(
context: context,
builder: (ctx) => AlertDialog(
title: Text('Assign Bed $bedNumber • Room $roomNumber'),
content: SizedBox(
width: 420,
child: Column(mainAxisSize: MainAxisSize.min, children: [
if (withAmt != null || withoutAmt != null)
Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)), child: Builder(builder: (_) {
final wf = withAmt != null ? '₹${withAmt.toString()}' : '-';
final wof = withoutAmt != null ? '₹${withoutAmt.toString()}' : '-';
final charges = 'Charges for ${_labelForCategory(category)} • With Food: $wf • Without Food: $wof';
return Text(charges, style: Theme.of(ctx).textTheme.bodySmall);
})),
Expanded(child: eligible.isEmpty
? const Text('No eligible students available')
: ListView.separated(
shrinkWrap: true,
itemCount: eligible.length,
separatorBuilder: (_, __) => const Divider(height: 1),
itemBuilder: (_, i) {
final s = eligible[i];
final sid = (s[StudentSchema.id] as String?) ?? '';
final name = ('${s[StudentSchema.firstName] ?? ''} ${s[StudentSchema.lastName] ?? ''}').trim();
final phone = (s[StudentSchema.phoneNumber] as String?) ?? '';
return ListTile(
leading: const Icon(Icons.person, color: Colors.blue),
title: Text(name.isEmpty ? phone : name, overflow: TextOverflow.ellipsis),
subtitle: Text(phone, overflow: TextOverflow.ellipsis),
trailing: FilledButton(onPressed: () => Navigator.pop(ctx, sid), child: const Text('Assign')),
onTap: () => Navigator.pop(ctx, sid),
);
},
)),
]),),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
),
);
if (selectedId == null) return;
await _repo.assignSpecificBed(instId: widget.instId, roomId: roomId, bedNumber: bedNumber, studentId: selectedId);
await FirebaseFirestore.instance
.collection(InstitutionRegistrationSchema.collectionName)
.doc(widget.instId)
.collection(InstitutionRegistrationSchema.studentsSubcollection)
.doc(selectedId)
.update({
StudentSchema.roomNumber: roomNumber,
StudentSchema.bedNumber: bedNumber,
StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
});
// Prompt for plan and apply monthly charge
final chosenPlan = await _promptAndApplyPlan(studentId: selectedId, category: category);
if (chosenPlan != null) {
await FirebaseFirestore.instance
.collection(InstitutionRegistrationSchema.collectionName)
.doc(widget.instId)
.collection(InstitutionRegistrationSchema.studentsSubcollection)
.doc(selectedId)
.update({
StudentSchema.foodPlan: chosenPlan,
StudentSchema.roomCategory: category,
StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
});
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Food plan set: ${chosenPlan == 'with' ? 'With Food' : 'Without Food'}')));
}
}
await _load();
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assigned Bed $bedNumber in Room $roomNumber')));
} catch (e) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

Future<void> _releaseBed(String roomId, String bedId, String roomNumber, int bedNumber) async {
final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
title: const Text('Release Bed?'),
content: Text('Release Bed $bedNumber in Room $roomNumber?'),
actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes'))],
));
if (confirm != true) return;
try {
await FirebaseFirestore.instance
.collection(InstitutionRegistrationSchema.collectionName)
.doc(widget.instId)
.collection(RoomSchema.collectionName)
.doc(roomId)
.collection(BedSchema.subcollectionName)
.doc(bedId)
.update({
BedSchema.occupied: false,
BedSchema.studentId: null,
BedSchema.assignedAt: null,
});
// Also clear from student if found
final q = await FirebaseFirestore.instance
.collection(InstitutionRegistrationSchema.collectionName)
.doc(widget.instId)
.collection(InstitutionRegistrationSchema.studentsSubcollection)
.where(StudentSchema.roomNumber, isEqualTo: roomNumber)
.where(StudentSchema.bedNumber, isEqualTo: bedNumber)
.limit(1)
.get();
if (q.docs.isNotEmpty) {
await q.docs.first.reference.update({
StudentSchema.roomNumber: null,
StudentSchema.bedNumber: null,
StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
});
}
await _load();
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bed released')));
} catch (e) {
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

DateTime _endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

Future<String?> _promptAndApplyPlan({required String studentId, required String category}) async {
final pricing = await _repo.getFoodPricing(instId: widget.instId);
final withAmt = pricing['with']?[category];
final withoutAmt = pricing['without']?[category];
if (withAmt == null && withoutAmt == null) return null;
String plan = 'with';
final selected = await showDialog<String?>(context: context, builder: (ctx) {
return StatefulBuilder(builder: (ctx, setState) {
return AlertDialog(
title: const Text('Select Food Plan'),
content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
Align(alignment: Alignment.centerLeft, child: Text('Category: ${_labelForCategory(category)}', style: Theme.of(ctx).textTheme.bodyMedium)),
const SizedBox(height: 8),
RadioListTile<String>(
value: 'with',
groupValue: plan,
onChanged: (v) { setState(() => plan = 'with'); },
title: Builder(builder: (_) {
final wf = withAmt != null ? '₹${withAmt.toString()}' : 'N/A';
return Text('With Food • $wf');
}),
),
RadioListTile<String>(
value: 'without',
groupValue: plan,
onChanged: (v) { setState(() => plan = 'without'); },
title: Builder(builder: (_) {
final wof = withoutAmt != null ? '₹${withoutAmt.toString()}' : 'N/A';
return Text('Without Food • $wof');
}),
),
])),
actions: [
TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
FilledButton(onPressed: () => Navigator.pop(ctx, plan), child: const Text('Apply'))
],
);
});
});
if (selected == null) return null;
final amount = selected == 'with' ? withAmt : withoutAmt;
if (amount == null || amount <= 0) return selected;
final now = DateTime.now();
final due = _endOfMonth(now);
try {
await _feeRepo.addMonthlyFee(instId: widget.instId, studentId: studentId, amount: amount, month: now.month, year: now.year, dueDate: due, recurring: true);
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Monthly charge added (${_labelForCategory(category)} • ${selected == 'with' ? 'With Food' : 'Without Food'})')));
}
} catch (e) {
if (!mounted) return null; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding charge: $e'), backgroundColor: Colors.red));
}
return selected;
}

Future<void> _editRoom(String roomId, String currentNumber, String currentCategory) async {
String category = currentCategory;
final roomCtrl = TextEditingController(text: currentNumber);
final res = await showDialog<(String room, String category)?>(context: context, builder: (ctx) => AlertDialog(
title: const Text('Edit Room'),
content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room number', border: OutlineInputBorder())),
const SizedBox(height: 8),
DropdownButtonFormField<String>(value: category, items: const [
DropdownMenuItem(value: 'single', child: Text('Single')),
DropdownMenuItem(value: 'two_sharing', child: Text('Two Sharing')),
DropdownMenuItem(value: 'three_sharing', child: Text('Three Sharing')),
DropdownMenuItem(value: 'four_sharing', child: Text('Four Sharing')),
], onChanged: (v) { if (v != null) category = v; }, decoration: const InputDecoration(labelText: 'Sharing', border: OutlineInputBorder())),
])),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () {
final r = roomCtrl.text.trim(); if (r.isEmpty) return; Navigator.pop(ctx, (r, category));
}, child: const Text('Save'))],
));
if (res == null) return;
try {
await _repo.updateRoom(instId: widget.instId, roomId: roomId, newRoomNumber: res.$1, newCategory: res.$2);
await _load();
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room updated')));
} catch (e) {
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

Future<void> _deleteRoom(String roomId, String roomNumber) async {
// Fetch assigned students to display
final assigned = await _repo.listAssignedStudents(instId: widget.instId, roomId: roomId);
final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
title: const Text('Delete Room?'),
content: SizedBox(width: 480, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
Text('Room $roomNumber will be deleted.'),
const SizedBox(height: 8),
if (assigned.isEmpty) const Text('No students are assigned to this room.') else ...[
const Text('The following students are currently assigned and will be detached:'),
const SizedBox(height: 6),
SizedBox(height: 180, child: ListView.separated(shrinkWrap: true, itemCount: assigned.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
final s = assigned[i];
final name = ('${s[StudentSchema.firstName] ?? ''} ${s[StudentSchema.lastName] ?? ''}').trim();
final phone = (s[StudentSchema.phoneNumber] as String?) ?? '';
return ListTile(leading: const Icon(Icons.person, color: Colors.blue), title: Text(name.isEmpty ? phone : name, overflow: TextOverflow.ellipsis), subtitle: Text(phone, overflow: TextOverflow.ellipsis));
}))
]
])),
actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
));
if (ok != true) return;
try {
await _repo.deleteRoomAndCleanup(instId: widget.instId, roomId: roomId);
await _load();
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room $roomNumber deleted and allocations cleared')));
} catch (e) {
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

@override
Widget build(BuildContext context) {
if (_loading) return const Center(child: CircularProgressIndicator());
if (_rooms.isEmpty) {
return Center(
child: Column(mainAxisSize: MainAxisSize.min, children: [
const Text('No rooms yet'),
const SizedBox(height: 8),
FilledButton.icon(onPressed: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ManageRoomsPage(instId: widget.instId))); await _load(); }, icon: const Icon(Icons.settings), label: const Text('Manage Room')),
]),
);
}
return RefreshIndicator(
onRefresh: _load,
child: LayoutBuilder(
builder: (ctx, constraints) {
const spacing = 12.0;
final horizontalPadding = 24.0; // 12 left + 12 right
final available = constraints.maxWidth - horizontalPadding;
// Use single column on mobile screens
final isDesktop = constraints.maxWidth > 900;
final tileWidth = isDesktop ? (available - spacing * 2) / 3 : available;
return SingleChildScrollView(
physics: const AlwaysScrollableScrollPhysics(),
child: Padding(
padding: const EdgeInsets.all(12),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Align(
alignment: Alignment.centerLeft,
child: Padding(
padding: const EdgeInsets.only(bottom: 8),
child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
FilledButton.icon(onPressed: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ManageRoomsPage(instId: widget.instId))); await _load(); }, icon: const Icon(Icons.settings), label: const Text('Manage Room')),
FilledButton.icon(
onPressed: () async {
// Select a student then open Manage Fees dialog
final selected = await showDialog<String?>(
context: context,
builder: (ctx) => _SelectStudentForFeesDialog(instId: widget.instId),
);
if (selected != null && selected.isNotEmpty) {
if (!mounted) return;
await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ManageFeesPage(instId: widget.instId, studentId: selected)));
// Optional refresh if anything changed
if (mounted) await _load();
}
},
icon: const Icon(Icons.account_balance_wallet),
label: const Text('Manage Fees'),
),
_FoodPricingTile(
title: 'With Food',
color: Colors.green,
pricing: _withFood,
onTap: () async {
final updated = await showDialog<Map<String, num>?>(context: context, builder: (ctx) => _EditFoodPricingDialog(title: 'With Food Pricing', initial: _withFood));
if (updated != null) {
await _repo.updateFoodPricing(instId: widget.instId, withFood: updated);
final p = await _repo.getFoodPricing(instId: widget.instId);
if (!mounted) return;
setState(() { _withFood = p['with'] ?? {}; });
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('With Food pricing saved')));
}
},
),
_FoodPricingTile(
title: 'Without Food',
color: Colors.orange,
pricing: _withoutFood,
onTap: () async {
final updated = await showDialog<Map<String, num>?>(context: context, builder: (ctx) => _EditFoodPricingDialog(title: 'Without Food Pricing', initial: _withoutFood));
if (updated != null) {
await _repo.updateFoodPricing(instId: widget.instId, withoutFood: updated);
final p = await _repo.getFoodPricing(instId: widget.instId);
if (!mounted) return;
setState(() { _withoutFood = p['without'] ?? {}; });
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Without Food pricing saved')));
}
},
),
]),
),
),
Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
const Text('Filter:'),
ChoiceChip(label: const Text('All'), selected: _bedFilter == 'all', onSelected: (_) => setState(() => _bedFilter = 'all')),
ChoiceChip(label: const Text('Occupied'), selected: _bedFilter == 'occupied', onSelected: (_) => setState(() => _bedFilter = 'occupied')),
ChoiceChip(label: const Text('Available'), selected: _bedFilter == 'available', onSelected: (_) => setState(() => _bedFilter = 'available')),
OutlinedButton.icon(
icon: const Icon(Icons.table_view, color: Colors.blue),
label: const Text('Export'),
onPressed: () async {
final instDoc = await FirebaseFirestore.instance.collection(InstitutionRegistrationSchema.collectionName).doc(widget.instId).get();
final List<Map<String, dynamic>> rows = [];
for (final r in _rooms) {
final roomId = r[RoomSchema.id] as String;
final rn = (r[RoomSchema.roomNumber] as String?) ?? '';
final cat = (r[RoomSchema.category] as String?) ?? 'two_sharing';
final stats = await _repo.roomStats(instId: widget.instId, roomId: roomId);
final total = stats.$1; final occ = stats.$2; final free = total - occ;
bool include = true;
if (_bedFilter == 'occupied') include = occ > 0;
if (_bedFilter == 'available') include = free > 0;
if (include) rows.add({'roomNumber': rn, 'category': cat, 'occupied': occ, 'available': free});
}
if (!context.mounted) return;
await showDialog(
context: context,
builder: (ctx) => ReceiptViewDialog(
title: 'Accommodation Report',
buildPdf: () async => ReceiptService().buildAccommodationRoomsReportPdf(
instId: widget.instId,
institution: instDoc.data(),
rows: rows,
title: 'Accommodation Report',
filtersDescription: 'Filter: ${_bedFilter[0].toUpperCase()}${_bedFilter.substring(1)}',
),
),
);
},
),
]),
const SizedBox(height: 8),
],
),
isDesktop
? Wrap(
spacing: spacing,
runSpacing: spacing,
children: [
for (final r in _rooms)
SizedBox(
width: tileWidth,
child: _RoomTileCard(
repo: _repo,
instId: widget.instId,
roomId: r[RoomSchema.id] as String,
roomNumber: (r[RoomSchema.roomNumber] as String?) ?? '',
category: (r[RoomSchema.category] as String?) ?? 'two_sharing',
capacity: (r[RoomSchema.capacity] as int?) ?? 2,
bedFilter: _bedFilter,
onAssign: _assignToBed,
onRelease: _releaseBed,
onEdit: _editRoom,
onDelete: _deleteRoom,
),
),
],
)
: Column(
children: [
for (final r in _rooms) ...[
_RoomTileCard(
repo: _repo,
instId: widget.instId,
roomId: r[RoomSchema.id] as String,
roomNumber: (r[RoomSchema.roomNumber] as String?) ?? '',
category: (r[RoomSchema.category] as String?) ?? 'two_sharing',
capacity: (r[RoomSchema.capacity] as int?) ?? 2,
bedFilter: _bedFilter,
onAssign: _assignToBed,
onRelease: _releaseBed,
onEdit: _editRoom,
onDelete: _deleteRoom,
),
const SizedBox(height: 12),
]
],
)
],
),
),
);
},
),
);
}


String _labelForCategory(String category) {
switch (category) {
case 'single':
return 'Single';
case 'two_sharing':
return 'Two Sharing';
case 'three_sharing':
return 'Three Sharing';
case 'four_sharing':
return 'Four Sharing';
default:
return category;
}
}
}

class _RoomTileCard extends StatelessWidget {
final FirebaseAccommodationRepository repo;
final String instId;
final String roomId;
final String roomNumber;
final String category;
final int capacity;
final String bedFilter; // all | occupied | available
final Future<void> Function(String roomId, String roomNumber, int bedNumber) onAssign;
final Future<void> Function(String roomId, String bedId, String roomNumber, int bedNumber) onRelease;
final Future<void> Function(String roomId, String currentNumber, String currentCategory) onEdit;
final Future<void> Function(String roomId, String roomNumber) onDelete;
_RoomTileCard({required this.repo, required this.instId, required this.roomId, required this.roomNumber, required this.category, required this.capacity, required this.bedFilter, required this.onAssign, required this.onRelease, required this.onEdit, required this.onDelete});
String _labelForCategory(String category) {
switch (category) {
case 'single':
return 'Single';
case 'two_sharing':
return 'Two Sharing';
case 'three_sharing':
return 'Three Sharing';
case 'four_sharing':
return 'Four Sharing';
default:
return category;
}
}
@override
Widget build(BuildContext context) {
final isPhone = MediaQuery.of(context).size.width < 600;
return Card(
child: Padding(
padding: const EdgeInsets.all(12),
child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
// Header row: room title with inline stats and action icons
Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
const Icon(Icons.meeting_room, color: Colors.blue),
const SizedBox(width: 8),
Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
Row(children: [
Flexible(child: Text('Room $roomNumber', style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
]),
const SizedBox(height: 2),
FutureBuilder<(int total, int occupied)>(
future: repo.roomStats(instId: instId, roomId: roomId),
builder: (c, snap) {
final total = snap.data?.$1 ?? capacity;
final occ = snap.data?.$2 ?? 0;
final free = total - occ;
return Row(children: [
Flexible(child: Text(_labelForCategory(category), style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
const SizedBox(width: 8),
const Icon(Icons.person, color: Colors.orange, size: 16),
Text(' $occ', style: Theme.of(context).textTheme.bodySmall),
const SizedBox(width: 8),
const Icon(Icons.bed, color: Colors.green, size: 16),
Text(' $free', style: Theme.of(context).textTheme.bodySmall),
]);
},
),
const SizedBox(height: 6),
const SizedBox(height: 6),
])),

]),
const SizedBox(height: 8),
FutureBuilder<(int total, int occupied)>(
future: repo.roomStats(instId: instId, roomId: roomId),
builder: (c, snap) {
final total = snap.data?.$1 ?? capacity;
final occ = snap.data?.$2 ?? 0;
final free = total - occ;
return const SizedBox.shrink();
},
),
const SizedBox(height: 8),
FutureBuilder<List<Map<String, dynamic>>>(
future: repo.listBeds(instId: instId, roomId: roomId),
builder: (c, snap) {
final allBeds = snap.data ?? const [];
if (allBeds.isEmpty) return const Text('No beds created');
List<Map<String, dynamic>> beds = allBeds;
if (bedFilter == 'occupied') {
beds = allBeds.where((b) => (b[BedSchema.occupied] as bool? ?? false)).toList();
} else if (bedFilter == 'available') {
beds = allBeds.where((b) => (b[BedSchema.occupied] as bool? ?? false) == false).toList();
}
if (beds.isEmpty) return const Text('No beds match filter');
return Wrap(
spacing: 6,
runSpacing: 6,
alignment: WrapAlignment.start,
children: [
for (final b in beds) _BedChip(
roomId: roomId,
roomNumber: roomNumber,
bedId: b[BedSchema.id] as String,
bedNumber: (b[BedSchema.bedNumber] as int? ?? 0),
occupied: (b[BedSchema.occupied] as bool? ?? false),
studentId: b[BedSchema.studentId] as String?,
onAssign: onAssign,
onRelease: onRelease,
)
]);
},
)
]),
),
);
}
}

class _FoodPricingTile extends StatelessWidget {
final String title;
final Color color;
final Map<String, num> pricing;
final VoidCallback onTap;
const _FoodPricingTile({required this.title, required this.color, required this.pricing, required this.onTap});
String _s(num? v) => v == null ? '-' : '₹${v.toString()}';
@override
Widget build(BuildContext context) {
final isSmall = MediaQuery.of(context).size.width < 600;
final single = pricing['single'];
final two = pricing['two_sharing'];
final three = pricing['three_sharing'];
final four = pricing['four_sharing'];
final subtitle = '1: ${_s(single)} • 2: ${_s(two)} • 3: ${_s(three)} • 4: ${_s(four)}';
return SizedBox(
height: isSmall ? 64 : 72,
child: AspectRatio(
aspectRatio: isSmall ? 4.0 : 5.0,
child: Card(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
child: InkWell(
borderRadius: BorderRadius.circular(10),
onTap: onTap,
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
child: Row(children: [
CircleAvatar(radius: isSmall ? 14 : 16, backgroundColor: color.withValues(alpha: 0.15), child: Icon(Icons.restaurant, color: color, size: isSmall ? 14 : 16)),
SizedBox(width: isSmall ? 8 : 10),
Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
Text(title, style: isSmall ? Theme.of(context).textTheme.bodyMedium : Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
const SizedBox(height: 2),
Text(subtitle, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)
])),
Icon(Icons.edit, color: Colors.blue, size: isSmall ? 16 : 18)
]),
),
),
),
),
);
}
}

class _SelectStudentForFeesDialog extends StatefulWidget {
final String instId;
const _SelectStudentForFeesDialog({required this.instId});
@override
State<_SelectStudentForFeesDialog> createState() => _SelectStudentForFeesDialogState();
}

class _SelectStudentForFeesDialogState extends State<_SelectStudentForFeesDialog> {
List<Map<String, dynamic>> _students = [];
bool _loading = true;
String? _selectedId;

@override
void initState() {
super.initState();
_load();
}

Future<void> _load() async {
setState(() => _loading = true);
final snap = await FirebaseFirestore.instance
.collection(InstitutionRegistrationSchema.collectionName)
.doc(widget.instId)
.collection(InstitutionRegistrationSchema.studentsSubcollection)
.get();
final list = snap.docs.map((d) {
final data = d.data();
data[StudentSchema.id] = d.id;
return data;
}).toList();
list.sort((a, b) {
final aFirst = (a[StudentSchema.firstName] as String?)?.trim().toLowerCase() ?? '';
final aLast = (a[StudentSchema.lastName] as String?)?.trim().toLowerCase() ?? '';
final bFirst = (b[StudentSchema.firstName] as String?)?.trim().toLowerCase() ?? '';
final bLast = (b[StudentSchema.lastName] as String?)?.trim().toLowerCase() ?? '';
return ('$aFirst $aLast').compareTo('$bFirst $bLast');
});
if (!mounted) return;
setState(() { _students = list; _loading = false; });
}

@override
Widget build(BuildContext context) {
return AlertDialog(
title: const Text('Select Student'),
content: SizedBox(
width: 420,
child: _loading
? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
: Column(mainAxisSize: MainAxisSize.min, children: [
DropdownButtonFormField<String?>(
value: _selectedId,
isDense: true,
items: _students.map((s) {
final id = s[StudentSchema.id] as String?;
final first = (s[StudentSchema.firstName] as String?)?.trim() ?? '';
final last = (s[StudentSchema.lastName] as String?)?.trim() ?? '';
final phone = (s[StudentSchema.phoneNumber] as String?)?.trim();
final name = ('$first $last').trim().isEmpty ? (phone ?? '-') : ('$first $last').trim();
final room = s[StudentSchema.roomNumber] as String?;
final bed = s[StudentSchema.bedNumber] as int?;
final suffix = '(${room != null ? 'Room $room' : 'Room -'}, ${bed != null ? 'Bed $bed' : 'Bed -'})';
return DropdownMenuItem<String?>(
value: id,
child: Text('$name $suffix', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
);
}).toList(),
onChanged: (v) => setState(() => _selectedId = v),
decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Student', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
),
]),
),
actions: [
TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
FilledButton(onPressed: _selectedId == null ? null : () => Navigator.pop<String?>(context, _selectedId), child: const Text('Continue')),
],
);
}
}

class _EditFoodPricingDialog extends StatefulWidget {
final String title;
final Map<String, num> initial;
const _EditFoodPricingDialog({required this.title, required this.initial});
@override
State<_EditFoodPricingDialog> createState() => _EditFoodPricingDialogState();
}

class _EditFoodPricingDialogState extends State<_EditFoodPricingDialog> {
late final TextEditingController _single;
late final TextEditingController _two;
late final TextEditingController _three;
late final TextEditingController _four;
@override
void initState() {
super.initState();
_single = TextEditingController(text: (widget.initial['single'] ?? '').toString());
_two = TextEditingController(text: (widget.initial['two_sharing'] ?? '').toString());
_three = TextEditingController(text: (widget.initial['three_sharing'] ?? '').toString());
_four = TextEditingController(text: (widget.initial['four_sharing'] ?? '').toString());
}
@override
void dispose() { _single.dispose(); _two.dispose(); _three.dispose(); _four.dispose(); super.dispose(); }
@override
Widget build(BuildContext context) {
InputDecoration deco(String label) => InputDecoration(labelText: label, border: const OutlineInputBorder());
return AlertDialog(
title: Text(widget.title),
content: SizedBox(
width: 420,
child: Column(mainAxisSize: MainAxisSize.min, children: [
Row(children: [
const Expanded(child: Text('Single')),
const SizedBox(width: 8),
Expanded(child: TextField(controller: _single, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: deco('Amount')))
]),
const SizedBox(height: 8),
Row(children: [
const Expanded(child: Text('Two Sharing')),
const SizedBox(width: 8),
Expanded(child: TextField(controller: _two, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: deco('Amount')))
]),
const SizedBox(height: 8),
Row(children: [
const Expanded(child: Text('Three Sharing')),
const SizedBox(width: 8),
Expanded(child: TextField(controller: _three, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: deco('Amount')))
]),
const SizedBox(height: 8),
Row(children: [
const Expanded(child: Text('Four Sharing')),
const SizedBox(width: 8),
Expanded(child: TextField(controller: _four, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: deco('Amount')))
]),
]),
),
actions: [
TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
FilledButton(onPressed: () {
Map<String, num> out = {};
final s = num.tryParse(_single.text.trim()); if (s != null) out['single'] = s;
final t = num.tryParse(_two.text.trim()); if (t != null) out['two_sharing'] = t;
final th = num.tryParse(_three.text.trim()); if (th != null) out['three_sharing'] = th;
final f = num.tryParse(_four.text.trim()); if (f != null) out['four_sharing'] = f;
Navigator.pop<Map<String, num>>(context, out);
}, child: const Text('Save')),
],
);
}
}

class _BedChip extends StatelessWidget {
final String roomId;
final String roomNumber;
final String bedId;
final int bedNumber;
final bool occupied;
final String? studentId;
final Future<void> Function(String roomId, String roomNumber, int bedNumber) onAssign;
final Future<void> Function(String roomId, String bedId, String roomNumber, int bedNumber) onRelease;
const _BedChip({required this.roomId, required this.roomNumber, required this.bedId, required this.bedNumber, required this.occupied, required this.studentId, required this.onAssign, required this.onRelease});
@override
Widget build(BuildContext context) {
final color = occupied ? Colors.red : Colors.green;
final bg = occupied ? Colors.red.withValues(alpha: 0.10) : Colors.green.withValues(alpha: 0.10);
final instId = (context.read<AppState>().user as InstitutionAdminSessionUser).instId;
return InkWell(
onTap: occupied ? () => onRelease(roomId, bedId, roomNumber, bedNumber) : () => onAssign(roomId, roomNumber, bedNumber),
child: Container(
decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
child: Row(mainAxisSize: MainAxisSize.min, children: [
Icon(Icons.bed, color: color, size: 16),
const SizedBox(width: 4),
Text('Bed $bedNumber', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
if (occupied && studentId != null && studentId!.isNotEmpty) ...[
const SizedBox(width: 4),
const Text('•', style: TextStyle(fontSize: 12)),
const SizedBox(width: 4),
Flexible(child: _StudentNameText(instId: instId, studentId: studentId!))
]
]),
),
);
}
}

class _StudentNameText extends StatelessWidget {
final String instId;
final String studentId;
const _StudentNameText({required this.instId, required this.studentId});
@override
Widget build(BuildContext context) {
return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
future: FirebaseFirestore.instance
.collection(InstitutionRegistrationSchema.collectionName)
.doc(instId)
.collection(InstitutionRegistrationSchema.studentsSubcollection)
.doc(studentId)
.get(),
builder: (ctx, snap) {
String label = studentId;
if (snap.hasData && snap.data?.data() != null) {
final data = snap.data!.data()!;
final first = (data[StudentSchema.firstName] as String?)?.trim() ?? '';
final last = (data[StudentSchema.lastName] as String?)?.trim() ?? '';
final name = ('$first $last').trim();
final phone = (data[StudentSchema.phoneNumber] as String?)?.trim();
if (name.isNotEmpty) {
label = name;
} else if (phone != null && phone.isNotEmpty) {
label = phone;
}
}
return Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1);
},
);
}
}

class _SettingsTab extends StatelessWidget {
final String instId; final bool enabled; final ValueChanged<bool> onToggle; final VoidCallback onSetAdminPassword;
const _SettingsTab({required this.instId, required this.enabled, required this.onToggle, required this.onSetAdminPassword});
@override
Widget build(BuildContext context) {
return ListView(padding: const EdgeInsets.all(16), children: [
ListTile(leading: const Icon(Icons.badge, color: Colors.blue), title: const Text('InstId'), subtitle: Text(instId)),
const SizedBox(height: 12),
SwitchListTile(value: enabled, onChanged: onToggle, title: const Text('Institution Enabled')),
const SizedBox(height: 12),
OutlinedButton.icon(onPressed: onSetAdminPassword, icon: const Icon(Icons.lock_reset, color: Colors.blue), label: const Text('Set Institution Admin Password')),
const SizedBox(height: 12),
Card(child: Padding(padding: const EdgeInsets.all(12), child: Text('''Export:
• Reports (CSV) coming soon.
• Use filters in Students/Payments to view subsets.
''' , style: Theme.of(context).textTheme.bodyMedium))),
]);
}
}

class _SetStudentPasswordDialog extends StatefulWidget {
const _SetStudentPasswordDialog();
@override
State<_SetStudentPasswordDialog> createState() => _SetStudentPasswordDialogState();
}

class _SetStudentPasswordDialogState extends State<_SetStudentPasswordDialog> {
final TextEditingController _pass1 = TextEditingController();
final TextEditingController _pass2 = TextEditingController();
String? _error;
bool _ob1 = true;
bool _ob2 = true;

@override
void dispose() {
_pass1.dispose();
_pass2.dispose();
super.dispose();
}

void _save() {
final p1 = _pass1.text.trim();
final p2 = _pass2.text.trim();
if (p1.isEmpty || p2.isEmpty) { setState(() => _error = 'Password cannot be empty'); return; }
if (p1.length < 6) { setState(() => _error = 'Password must be at least 6 characters'); return; }
if (p1 != p2) { setState(() => _error = 'Passwords do not match'); return; }
Navigator.pop<String>(context, p1);
}

@override
Widget build(BuildContext context) {
return AlertDialog(
title: const Text('Set Student Password'),
content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
TextField(controller: _pass1, obscureText: _ob1, decoration: InputDecoration(labelText: 'New Password', border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => _ob1 = !_ob1), icon: Icon(_ob1 ? Icons.visibility : Icons.visibility_off, color: Colors.blue)))),
const SizedBox(height: 10),
TextField(controller: _pass2, obscureText: _ob2, decoration: InputDecoration(labelText: 'Confirm Password', border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => _ob2 = !_ob2), icon: Icon(_ob2 ? Icons.visibility : Icons.visibility_off, color: Colors.blue)))) ,
if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
])),
actions: [
TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
FilledButton(onPressed: _save, child: const Text('Save')),
],
);
}
}

class _SetInstitutionAdminPasswordDialog extends StatefulWidget {
const _SetInstitutionAdminPasswordDialog();
@override
State<_SetInstitutionAdminPasswordDialog> createState() => _SetInstitutionAdminPasswordDialogState();
}

class _SetInstitutionAdminPasswordDialogState extends State<_SetInstitutionAdminPasswordDialog> {
final TextEditingController _pass1 = TextEditingController();
final TextEditingController _pass2 = TextEditingController();
String? _error;
bool _ob1 = true;
bool _ob2 = true;

@override
void dispose() {
_pass1.dispose();
_pass2.dispose();
super.dispose();
}

void _save() {
final p1 = _pass1.text.trim();
final p2 = _pass2.text.trim();
if (p1.isEmpty || p2.isEmpty) { setState(() => _error = 'Password cannot be empty'); return; }
if (p1.length < 6) { setState(() => _error = 'Password must be at least 6 characters'); return; }
if (p1 != p2) { setState(() => _error = 'Passwords do not match'); return; }
Navigator.pop<String>(context, p1);
}

@override
Widget build(BuildContext context) {
return AlertDialog(
title: const Text('Set Institution Admin Password'),
content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
TextField(controller: _pass1, obscureText: _ob1, decoration: InputDecoration(labelText: 'New Password', border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => _ob1 = !_ob1), icon: Icon(_ob1 ? Icons.visibility : Icons.visibility_off, color: Colors.blue)))),
const SizedBox(height: 10),
TextField(controller: _pass2, obscureText: _ob2, decoration: InputDecoration(labelText: 'Confirm Password', border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => _ob2 = !_ob2), icon: Icon(_ob2 ? Icons.visibility : Icons.visibility_off, color: Colors.blue)))) ,
if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
])),
actions: [
TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
FilledButton(onPressed: _save, child: const Text('Save')),
],
);
}
}

// Legacy _FeeDialog removed in favor of per-charge Manage Charges flow.

class _StudentProfileDialog extends StatelessWidget {
final Map<String, dynamic> data;
const _StudentProfileDialog({required this.data});
@override
Widget build(BuildContext context) {
String field(String key) => data[key] as String? ?? '';
String nullableField(String key) => data[key] as String? ?? '-';
return AlertDialog(
title: const Text('Student Profile'),
content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
ListTile(leading: const Icon(Icons.person), title: const Text('Name'), subtitle: Text('${field(StudentSchema.firstName)} ${field(StudentSchema.lastName)}'.trim())),
ListTile(leading: const Icon(Icons.phone), title: const Text('Phone'), subtitle: Text(field(StudentSchema.phoneNumber))),
ListTile(leading: const Icon(Icons.email), title: const Text('Email'), subtitle: Text(field(StudentSchema.email))),
ListTile(leading: const Icon(Icons.home), title: const Text('Address'), subtitle: Text(field(StudentSchema.address))),
ListTile(leading: const Icon(Icons.badge), title: const Text('Aadhaar'), subtitle: Text(field(StudentSchema.aadhaar))),
ListTile(leading: const Icon(Icons.family_restroom), title: const Text('Parent'), subtitle: Text('${field(StudentSchema.parentName)} (${field(StudentSchema.parentPhone)})')),
ListTile(leading: const Icon(Icons.school), title: const Text('College/Course/Class'), subtitle: Text(field(StudentSchema.collegeCourseClass))),
ListTile(leading: const Icon(Icons.meeting_room), title: const Text('Room'), subtitle: Text(nullableField(StudentSchema.roomNumber))),
ListTile(leading: const Icon(Icons.event), title: const Text('Joining Date'), subtitle: Text((((data[StudentSchema.createdAt] as Timestamp?)?.toDate())?.toString().split(' ').first) ?? '-')),
ListTile(leading: const Icon(Icons.refresh), title: const Text('Re-Enabled Date'), subtitle: Text((((data[StudentSchema.reenabledAt] as Timestamp?)?.toDate())?.toString().split(' ').first) ?? '-')),
]))),
actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
);
}
}

class _StudentProfileEditorDialog extends StatefulWidget {
final String instId; final Map<String, dynamic> student;
const _StudentProfileEditorDialog({required this.instId, required this.student});
@override
State<_StudentProfileEditorDialog> createState() => _StudentProfileEditorDialogState();
}

class _StudentProfileEditorDialogState extends State<_StudentProfileEditorDialog> {
final _repo = FirebaseStudentRepository();
final _storage = FirebaseStorageService();
late TextEditingController _first;
late TextEditingController _last;
late TextEditingController _phone;
late TextEditingController _email;
late TextEditingController _address;
late TextEditingController _aadhaar;
late TextEditingController _parentName;
late TextEditingController _parentPhone;
late TextEditingController _college;
String? _photoUrl;
bool _saving = false;

String get _sid => (widget.student[StudentSchema.id] as String?) ?? '';

@override
void initState() {
super.initState();
_first = TextEditingController(text: (widget.student[StudentSchema.firstName] as String?) ?? '');
_last = TextEditingController(text: (widget.student[StudentSchema.lastName] as String?) ?? '');
_phone = TextEditingController(text: (widget.student[StudentSchema.phoneNumber] as String?) ?? '');
_email = TextEditingController(text: (widget.student[StudentSchema.email] as String?) ?? '');
_address = TextEditingController(text: (widget.student[StudentSchema.address] as String?) ?? '');
_aadhaar = TextEditingController(text: (widget.student[StudentSchema.aadhaar] as String?) ?? '');
_parentName = TextEditingController(text: (widget.student[StudentSchema.parentName] as String?) ?? '');
_parentPhone = TextEditingController(text: (widget.student[StudentSchema.parentPhone] as String?) ?? '');
_college = TextEditingController(text: (widget.student[StudentSchema.collegeCourseClass] as String?) ?? '');
_photoUrl = widget.student[StudentSchema.photoUrl] as String?;
}

@override
void dispose() {
_first.dispose(); _last.dispose(); _phone.dispose(); _email.dispose(); _address.dispose(); _aadhaar.dispose(); _parentName.dispose(); _parentPhone.dispose(); _college.dispose();
super.dispose();
}

Future<void> _pickAndUploadPhoto() async {
try {
final ImagePicker picker = ImagePicker();
final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
if (file == null) return;
final Uint8List bytes = await file.readAsBytes();
String ext = 'jpg';
final name = file.name.toLowerCase();
if (name.endsWith('.png')) ext = 'png'; else if (name.endsWith('.webp')) ext = 'webp';
final url = await _storage.uploadStudentProfilePhoto(instId: widget.instId, studentId: _sid, data: bytes, fileExtension: ext);
await _repo.setStudentPhotoUrl(instId: widget.instId, studentId: _sid, photoUrl: url);
if (!mounted) return;
setState(() => _photoUrl = url);
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo uploaded')));
} catch (e) {
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

Future<void> _save() async {
setState(() => _saving = true);
try {
await _repo.updateStudentProfile(instId: widget.instId, studentId: _sid, data: {
StudentSchema.firstName: _first.text.trim(),
StudentSchema.lastName: _last.text.trim(),
StudentSchema.phoneNumber: _phone.text.trim(),
StudentSchema.email: _email.text.trim(),
StudentSchema.address: _address.text.trim(),
StudentSchema.aadhaar: _aadhaar.text.trim(),
StudentSchema.parentName: _parentName.text.trim(),
StudentSchema.parentPhone: _parentPhone.text.trim(),
StudentSchema.collegeCourseClass: _college.text.trim(),
});
if (!mounted) return; Navigator.pop(context);
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
} catch (e) {
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
} finally {
if (mounted) setState(() => _saving = false);
}
}

Future<void> _downloadPdf() async {
final doc = pw.Document();
pw.ImageProvider? img;
try {
if (_photoUrl != null && _photoUrl!.isNotEmpty) {
img = await networkImage(_photoUrl!);
}
} catch (_) {}
doc.addPage(pw.Page(build: (pw.Context ctx) {
pw.Widget row(String k, String v) => pw.Row(children: [pw.Expanded(flex: 4, child: pw.Text(k)), pw.SizedBox(width: 8), pw.Expanded(flex: 6, child: pw.Text(v))]);
return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
pw.Text('Student Profile', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
pw.SizedBox(height: 8),
if (img != null) pw.Center(child: pw.Container(width: 96, height: 96, decoration: pw.BoxDecoration(shape: pw.BoxShape.circle), child: pw.ClipOval(child: pw.Image(img!, fit: pw.BoxFit.cover)))),
pw.SizedBox(height: 8),
row('First Name', _first.text.trim()),
row('Last Name', _last.text.trim()),
row('Phone', _phone.text.trim()),
row('Email', _email.text.trim()),
row('Address', _address.text.trim()),
row('Aadhaar', _aadhaar.text.trim()),
row('Parent Name', _parentName.text.trim()),
row('Parent Phone', _parentPhone.text.trim()),
row('College/Course/Class', _college.text.trim()),
]);
}));
await Printing.sharePdf(bytes: await doc.save(), filename: 'student_${_first.text.trim()}_${_last.text.trim()}.pdf');
}

InputDecoration get _inputDeco => const InputDecoration(border: OutlineInputBorder());

@override
Widget build(BuildContext context) {
final initials = (() {
final a = _first.text.trim().isNotEmpty ? _first.text.trim()[0].toUpperCase() : '';
final b = _last.text.trim().isNotEmpty ? _last.text.trim()[0].toUpperCase() : '';
return (a + b).isEmpty ? 'S' : (a + b);
})();

final isSmallScreen = MediaQuery.of(context).size.width < 600;

return AlertDialog(
title: const Text('Student Profile'),
content: ConstrainedBox(
constraints: BoxConstraints(
maxWidth: isSmallScreen ? MediaQuery.of(context).size.width * 0.9 : 480,
maxHeight: MediaQuery.of(context).size.height * 0.7,
),
child: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
// Profile Photo Section
Row(
children: [
CircleAvatar(
radius: isSmallScreen ? 24 : 32,
backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty ? NetworkImage(_photoUrl!) : null,
child: _photoUrl == null || _photoUrl!.isEmpty ? Text(initials, style: TextStyle(fontSize: isSmallScreen ? 16 : 20)) : null,
),
SizedBox(width: isSmallScreen ? 8 : 12),
Expanded(
child: OutlinedButton.icon(
onPressed: _pickAndUploadPhoto,
icon: const Icon(Icons.photo_camera, size: 18, color: Colors.blue),
label: Text(isSmallScreen ? 'Photo' : 'Upload Photo', style: const TextStyle(fontSize: 12)),
),
),
],
),
SizedBox(height: isSmallScreen ? 8 : 12),

// Form Fields in Column Layout for Mobile
if (isSmallScreen) ...[
_buildCompactField('First Name', _first),
_buildCompactField('Last Name', _last),
_buildCompactField('Phone', _phone, TextInputType.phone),
_buildCompactField('Email', _email, TextInputType.emailAddress),
_buildCompactField('Address', _address, TextInputType.multiline, 2),
_buildCompactField('Aadhaar', _aadhaar),
_buildCompactField('Parent Name', _parentName),
_buildCompactField('Parent Phone', _parentPhone, TextInputType.phone),
_buildCompactField('College/Course/Class', _college),
] else ...[
// Two Column Layout for Desktop
_buildTwoColumnField('First Name', _first, 'Last Name', _last),
_buildTwoColumnField('Phone', _phone, 'Email', _email,
leftType: TextInputType.phone, rightType: TextInputType.emailAddress),
_buildSingleField('Address', _address, TextInputType.multiline, 2),
_buildTwoColumnField('Aadhaar', _aadhaar, 'Parent Name', _parentName),
_buildTwoColumnField('Parent Phone', _parentPhone, 'College/Course/Class', _college,
leftType: TextInputType.phone),
],
],
),
),
),
actions: [
if (isSmallScreen) ...[
// Stack buttons vertically on mobile
Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
OutlinedButton.icon(
onPressed: _downloadPdf,
icon: const Icon(Icons.download, size: 16, color: Colors.blue),
label: const Text('Download', style: TextStyle(fontSize: 12)),
),
const SizedBox(height: 8),
FilledButton(
onPressed: _saving ? null : _save,
child: _saving
? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
: const Text('Save'),
),
const SizedBox(height: 8),
TextButton(
onPressed: _saving ? null : () => Navigator.pop(context),
child: const Text('Close'),
),
],
),
] else ...[
// Horizontal layout for desktop
TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Close')),
OutlinedButton.icon(
onPressed: _downloadPdf,
icon: const Icon(Icons.download, color: Colors.blue),
label: const Text('Download'),
),
FilledButton(
onPressed: _saving ? null : _save,
child: _saving
? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
: const Text('Save'),
),
],
],
);
}
}

Widget _buildCompactField(String label, TextEditingController controller, [TextInputType? keyboardType, int? maxLines]) {
return Padding(
padding: const EdgeInsets.symmetric(vertical: 4),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
const SizedBox(height: 4),
TextField(
controller: controller,
decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), isDense: true),
keyboardType: keyboardType,
maxLines: maxLines ?? 1,
style: const TextStyle(fontSize: 14),
),
],
),
);
}

Widget _buildTwoColumnField(String leftLabel, TextEditingController leftController,
String rightLabel, TextEditingController rightController,
{TextInputType? leftType, TextInputType? rightType}) {
return Padding(
padding: const EdgeInsets.symmetric(vertical: 6),
child: Row(
children: [
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(leftLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
const SizedBox(height: 4),
TextField(
controller: leftController,
decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10), isDense: true),
keyboardType: leftType,
style: const TextStyle(fontSize: 14),
),
],
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(rightLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
const SizedBox(height: 4),
TextField(
controller: rightController,
decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10), isDense: true),
keyboardType: rightType,
style: const TextStyle(fontSize: 14),
),
],
),
),
],
),
);
}

Widget _buildSingleField(String label, TextEditingController controller, TextInputType keyboardType, [int? maxLines]) {
return Padding(
padding: const EdgeInsets.symmetric(vertical: 6),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
const SizedBox(height: 4),
TextField(
controller: controller,
decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10), isDense: true),
keyboardType: keyboardType,
maxLines: maxLines ?? 1,
style: const TextStyle(fontSize: 14),
),
],
),
);
}

class _MetricCard extends StatelessWidget {
final IconData icon; final Color color; final String label; final String value;
const _MetricCard({required this.icon, required this.color, required this.label, required this.value});
@override
Widget build(BuildContext context) {
return Card(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
child: Padding(
padding: const EdgeInsets.all(16),
child: Row(children: [
CircleAvatar(radius: 24, backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
const SizedBox(width: 12),
Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.titleMedium), Text(value, style: Theme.of(context).textTheme.headlineSmall)])),
]),
),
);
}
}

class _DashCard extends StatelessWidget {
final IconData icon; final Color color; final String title; final String subtitle; final VoidCallback onTap; final Widget? child;
const _DashCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap, this.child});
@override
Widget build(BuildContext context) {
final isSmallScreen = MediaQuery.of(context).size.width < 600;
return Card(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
child: InkWell(
borderRadius: BorderRadius.circular(12),
onTap: onTap,
child: Padding(
padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
CircleAvatar(
radius: isSmallScreen ? 16 : 20,
backgroundColor: color.withValues(alpha: 0.15),
child: Icon(icon, color: color, size: isSmallScreen ? 16 : 20)
),
SizedBox(width: isSmallScreen ? 8 : 10),
Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
Text(
title,
style: isSmallScreen
? Theme.of(context).textTheme.bodyMedium
: Theme.of(context).textTheme.titleSmall,
overflow: TextOverflow.ellipsis
),
const SizedBox(height: 4),
Text(
subtitle,
style: isSmallScreen
? Theme.of(context).textTheme.bodySmall
: Theme.of(context).textTheme.bodyMedium,
overflow: TextOverflow.ellipsis
),
if (child != null) child!
])),
Icon(Icons.chevron_right, color: Colors.blue, size: isSmallScreen ? 16 : 20)
]),
),
),
);
}
}

class _MiniLineChart extends StatelessWidget {
final List<double> data;
const _MiniLineChart({required this.data});
@override
Widget build(BuildContext context) {
if (data.isEmpty) return const SizedBox.shrink();
final maxY = (data.fold<double>(0, (p, e) => e > p ? e : p));
final hasData = maxY > 0;
final isSmall = MediaQuery.of(context).size.width < 600;
final h = isSmall ? 28.0 : 36.0;
return SizedBox(height: h, child: hasData ? LineChart(LineChartData(
gridData: const FlGridData(show: false),
titlesData: const FlTitlesData(show: false),
borderData: FlBorderData(show: false),
lineBarsData: [LineChartBarData(spots: [for (int i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i])], isCurved: true, color: Colors.purple, dotData: const FlDotData(show: false), barWidth: 2)],
minY: 0,
maxY: maxY * 1.2,
)) : Center(child: Text('No data', style: Theme.of(context).textTheme.bodySmall)));
}
}

class _ManageFeesDialog extends StatefulWidget {
final String instId; final String studentId; final bool isDisabled;
const _ManageFeesDialog({required this.instId, required this.studentId, this.isDisabled = false});
@override
State<_ManageFeesDialog> createState() => _ManageFeesDialogState();
}

class _ManageFeesDialogState extends State<_ManageFeesDialog> {
final _feeRepo = FirebaseFeeRepository();
final _payRepo = FirebasePaymentRepository();
final _receipt = ReceiptService();
List<Map<String, dynamic>> _fees = [];
bool _loading = true;

@override
void initState() {
super.initState();
_load();
}

Future<void> _load() async {
setState(() => _loading = true);
final data = await _feeRepo.listFees(instId: widget.instId, studentId: widget.studentId);
if (!mounted) return;
setState(() { _fees = data; _loading = false; });
}

Future<void> _addMonthly() async {
final amountCtrl = TextEditingController();
DateTime now = DateTime.now();
int month = now.month; int year = now.year; DateTime? due;
final res = await showDialog<(num amount, int month, int year, DateTime? due, bool recurring)>(context: context, builder: (ctx) => _AddMonthlyDialog(initialMonth: month, initialYear: year));
if (res == null) return;
await _feeRepo.addMonthlyFee(instId: widget.instId, studentId: widget.studentId, amount: res.$1, month: res.$2, year: res.$3, dueDate: res.$4, recurring: res.$5);
await _load();
}

Future<void> _addOther() async {
final res = await showDialog<(num amount, String reason, DateTime? due)>(context: context, builder: (ctx) => const _AddOtherChargeDialog());
if (res == null) return;
await _feeRepo.addOtherCharge(instId: widget.instId, studentId: widget.studentId, amount: res.$1, reason: res.$2, dueDate: res.$3);
await _load();
}

Future<void> _markPaid(Map<String, dynamic> fee) async {
final amount = fee[FeeItemSchema.amount] as num? ?? 0;
final label = (fee[FeeItemSchema.type] == FeeItemSchema.typeMonthly) ? (fee[FeeItemSchema.label] as String? ?? 'Monthly Fee') : (fee[FeeItemSchema.label] as String? ?? 'Other charge');
// Mark as cash by default in Institution Admin portal; could extend to choose method later
final paymentId = await _payRepo.addPayment(instId: widget.instId, studentId: widget.studentId, amount: amount, method: 'cash', feeItemId: fee[FeeItemSchema.id] as String?, feeLabel: label);
await _feeRepo.markFeePaid(instId: widget.instId, studentId: widget.studentId, feeItemId: fee[FeeItemSchema.id] as String, paymentId: paymentId);
await _load();
}

Future<void> _editFee(Map<String, dynamic> fee) async {
final dueTs = fee[FeeItemSchema.dueDate] as Timestamp?; final due = dueTs?.toDate();
final amtVal = fee[FeeItemSchema.amount] as num? ?? 0;
final res = await showDialog<(num amount, DateTime? due)>(context: context, builder: (ctx) => _EditFeeItemDialog(initialAmount: amtVal, initialDue: due));
if (res == null) return;
await _feeRepo.updateFeeItem(instId: widget.instId, studentId: widget.studentId, feeItemId: fee[FeeItemSchema.id] as String, amount: res.$1, dueDate: res.$2);
await _load();
}

Future<void> _deleteFee(Map<String, dynamic> fee) async {
final reasonCtrl = TextEditingController();
final reason = await showDialog<String?>(context: context, builder: (ctx) => AlertDialog(
title: const Text('Delete Unpaid Amount'),
content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
const Align(alignment: Alignment.centerLeft, child: Text('Please provide a reason for deleting this unpaid amount.')),
const SizedBox(height: 8),
TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()))
])),
actions: [
TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
FilledButton(onPressed: () { final r = reasonCtrl.text.trim(); if (r.isEmpty) return; Navigator.pop(ctx, r); }, child: const Text('Delete')),
],
));
if (reason == null || reason.trim().isEmpty) return;
try {
await _feeRepo.deleteFeeItem(instId: widget.instId, studentId: widget.studentId, feeItemId: fee[FeeItemSchema.id] as String, reason: reason.trim());
await _load();
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount deleted and excluded from totals.')));
}
} catch (e) {
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

@override
Widget build(BuildContext context) {
return AlertDialog(
title: const Text('Manage Charges'),
content: SizedBox(width: 520, child: _loading ? const Center(child: CircularProgressIndicator()) : Column(mainAxisSize: MainAxisSize.min, children: [
if (widget.isDisabled) Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)), child: const Text('This account is disabled. You cannot assign charges.', style: TextStyle(color: Colors.red))),
Row(children: [
FilledButton.icon(onPressed: widget.isDisabled ? null : _addMonthly, icon: const Icon(Icons.calendar_month), label: const Text('Add Monthly')),
const SizedBox(width: 8),
OutlinedButton.icon(onPressed: widget.isDisabled ? null : _addOther, icon: const Icon(Icons.add), label: const Text('Add Other')),
]),
const SizedBox(height: 12),
Flexible(child: _fees.isEmpty
? const Center(child: Text('No charges yet'))
: ListView.separated(shrinkWrap: true, itemCount: _fees.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (ctx, i) {
final f = _fees[i];
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
return Card(child: ListTile(
leading: Icon(type == FeeItemSchema.typeMonthly ? Icons.calendar_month : Icons.attach_money, color: color),
title: Text('$label • ₹$amt', style: titleStyle),
subtitle: isDeleted
? Text('Deleted${delAt != null ? ' on ${delAt.day}/${delAt.month}/${delAt.year}' : ''} • Reason: ${delReason ?? '-'} • Excluded from total amount calculations.', style: TextStyle(color: Colors.red.withValues(alpha: 0.85)))
: Text('Due: $dueStr • ${type == FeeItemSchema.typeMonthly ? ((f[FeeItemSchema.recurring] as bool? ?? false) ? 'Monthly (Recurring)' : 'Monthly') : 'Other'} • ${isToConfirm ? 'TO CONFIRM' : status.toUpperCase()}'),
trailing: isDeleted ? null : Row(mainAxisSize: MainAxisSize.min, children: [
if (isToConfirm) ...[
IconButton(onPressed: () { showDialog(context: context, builder: (ctx) { final method = (f[FeeItemSchema.submissionMethod] as String? ?? '').toUpperCase(); final note = f[FeeItemSchema.submissionNote] as String?; final proof = f[FeeItemSchema.submissionProofUrl] as String?; return AlertDialog(title: const Text('Submitted Payment'), content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Method: $method'), const SizedBox(height: 6), if (note != null && note.isNotEmpty) Text('Comment: $note') else const Text('No comment'), const SizedBox(height: 8), if (proof != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(proof, height: 180, fit: BoxFit.cover)) else const Text('No screenshot attached')])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))]); }); }, icon: const Icon(Icons.visibility, color: Colors.blue)),
IconButton(onPressed: () => _editFee(f), icon: const Icon(Icons.edit, color: Colors.blue)),
IconButton(onPressed: () async { await _markPaid(f); }, icon: const Icon(Icons.check_circle, color: Colors.green)),
IconButton(onPressed: () => _deleteFee(f), icon: const Icon(Icons.delete, color: Colors.red))
] else if (status != 'paid') ...[
IconButton(onPressed: () => _editFee(f), icon: const Icon(Icons.edit, color: Colors.blue)),
IconButton(onPressed: () => _markPaid(f), icon: const Icon(Icons.check_circle, color: Colors.green)),
IconButton(onPressed: () => _deleteFee(f), icon: const Icon(Icons.delete, color: Colors.red))
],
if (paymentId != null) IconButton(onPressed: () async {
final payDoc = await FirebaseFirestore.instance.collection(InstitutionRegistrationSchema.collectionName).doc(widget.instId).collection(InstitutionRegistrationSchema.paymentsSubcollection).doc(paymentId).get();
final data = payDoc.data(); if (data != null && mounted) { await showDialog(context: context, builder: (ctx) => ReceiptViewDialog.forPayment(instId: widget.instId, payment: data)); }
}, icon: const Icon(Icons.download, color: Colors.blue)),
]),
));

}))
])),
actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
);
}
}

class _AddMonthlyDialog extends StatefulWidget {
final int initialMonth; final int initialYear;
const _AddMonthlyDialog({required this.initialMonth, required this.initialYear});
@override
State<_AddMonthlyDialog> createState() => _AddMonthlyDialogState();
}

class _AddMonthlyDialogState extends State<_AddMonthlyDialog> {
final _amount = TextEditingController();
int _m = 1; int _y = 2025; DateTime? _due; bool _recurring = true;
@override
void initState() { super.initState(); _m = widget.initialMonth; _y = widget.initialYear; }
@override
void dispose() { _amount.dispose(); super.dispose(); }
@override
Widget build(BuildContext context) {
return AlertDialog(
title: const Text('Add Monthly Fee'),
content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
TextField(controller: _amount, decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()), keyboardType: TextInputType.number),
const SizedBox(height: 8),
Row(children: [
Expanded(child: DropdownButtonFormField<int>(value: _m, items: List.generate(12, (i) => DropdownMenuItem(value: i+1, child: Text('Month ${i+1}'))), onChanged: (v) => setState(() => _m = v ?? _m), decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Month'))),
const SizedBox(width: 8),
Expanded(child: DropdownButtonFormField<int>(value: _y, items: List.generate(6, (i) => DropdownMenuItem(value: DateTime.now().year - 1 + i, child: Text('${DateTime.now().year - 1 + i}'))), onChanged: (v) => setState(() => _y = v ?? _y), decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Year'))),
]),
const SizedBox(height: 8),
Row(children: [
const Icon(Icons.event, color: Colors.orange), const SizedBox(width: 8),
Expanded(child: Text(_due == null ? 'No due date selected' : 'Due: ${_due!.day}/${_due!.month}/${_due!.year}')),
TextButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: _due ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) setState(() => _due = d); }, child: const Text('Pick date'))
]),
const SizedBox(height: 8),
SwitchListTile.adaptive(value: _recurring, onChanged: (v) => setState(() => _recurring = v), title: const Text('Recurring monthly'))
])),
actions: [
TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
FilledButton(onPressed: () { final a = num.tryParse(_amount.text.trim()); if (a == null) return; Navigator.pop(context, (a, _m, _y, _due, _recurring)); }, child: const Text('Save')),
],
);
}
}

class _AddOtherChargeDialog extends StatefulWidget {
const _AddOtherChargeDialog();
@override
State<_AddOtherChargeDialog> createState() => _AddOtherChargeDialogState();
}

class _AddOtherChargeDialogState extends State<_AddOtherChargeDialog> {
final _amount = TextEditingController();
final _reason = TextEditingController();
DateTime? _due;
@override
void dispose() { _amount.dispose(); _reason.dispose(); super.dispose(); }
@override
Widget build(BuildContext context) {
return AlertDialog(
title: const Text('Add Other Charge'),
content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder())),
const SizedBox(height: 8),
TextField(controller: _amount, decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()), keyboardType: TextInputType.number),
const SizedBox(height: 8),
Row(children: [
const Icon(Icons.event, color: Colors.orange), const SizedBox(width: 8),
Expanded(child: Text(_due == null ? 'No due date selected' : 'Due: ${_due!.day}/${_due!.month}/${_due!.year}')),
TextButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: _due ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) setState(() => _due = d); }, child: const Text('Pick date'))
])
])),
actions: [
TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
FilledButton(onPressed: () { final a = num.tryParse(_amount.text.trim()); final r = _reason.text.trim(); if (a == null || r.isEmpty) return; Navigator.pop(context, (a, r, _due)); }, child: const Text('Save')),
],
);
}
}

class _EditFeeItemDialog extends StatefulWidget {
final num initialAmount; final DateTime? initialDue;
const _EditFeeItemDialog({required this.initialAmount, required this.initialDue});
@override
State<_EditFeeItemDialog> createState() => _EditFeeItemDialogState();
}

class _EditFeeItemDialogState extends State<_EditFeeItemDialog> {
late TextEditingController _amount;
DateTime? _due;
@override
void initState() { super.initState(); _amount = TextEditingController(text: widget.initialAmount.toString()); _due = widget.initialDue; }
@override
void dispose() { _amount.dispose(); super.dispose(); }
@override
Widget build(BuildContext context) {
return AlertDialog(
title: const Text('Edit Due/Amount'),
content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder())),
const SizedBox(height: 8),
Row(children: [
const Icon(Icons.event, color: Colors.orange), const SizedBox(width: 8),
Expanded(child: Text(_due == null ? 'No due date' : 'Due: ${_due!.day}/${_due!.month}/${_due!.year}')),
TextButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: _due ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) setState(() => _due = d); }, child: const Text('Pick date'))
])
])),
actions: [
TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
FilledButton(onPressed: () {
final a = num.tryParse(_amount.text.trim());
if (a == null) return;
Navigator.pop<(num, DateTime?)>(context, (a, _due));
}, child: const Text('Save')),
],
);
}
}

class _SupportTab extends StatefulWidget {
final String instId;
const _SupportTab({required this.instId});
@override
State<_SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends State<_SupportTab> {
final _repo = FirebaseSupportTicketRepository();
String _status = 'all'; // all | new | acknowledged | in_progress | resolved | closed | reopened
bool _loading = true;
List<Map<String, dynamic>> _tickets = [];

@override
void initState() { super.initState(); _load(); }

Future<void> _load() async {
setState(() => _loading = true);
final data = await _repo.listTicketsForInstitution(instId: widget.instId, status: _status);
if (!mounted) return; setState(() { _tickets = data; _loading = false; });
}

Future<void> _newTicket() async {
final res = await showDialog<(String subject, String category, String priority, String description, List<_LocalAttachment>)>(context: context, builder: (ctx) => const _NewTicketDialog());
if (res == null) return;
try {
final name = 'Inst ${widget.instId}';
final id = await _repo.createTicket(instId: widget.instId, createdByName: name, category: res.$2, priority: res.$3, subject: res.$1, description: res.$4, attachmentUrls: const []);
// Upload attachments as an update
if (res.$5.isNotEmpty) {
final storage = FirebaseStorageService();
final urls = <String>[];
for (final a in res.$5) {
final url = await storage.uploadSupportAttachment(instId: widget.instId, ticketId: id, data: a.bytes, fileExtension: a.extension);
urls.add(url);
}
await _repo.addUpdate(ticketId: id, authorRole: 'institution_admin', authorName: name, message: 'Attachments added', attachmentUrls: urls);
}
await _load();
if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket created')));
} catch (e) {
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

String _labelStatus(String s) {
switch (s) {
case 'new': return 'New';
case 'acknowledged': return 'Acknowledged';
case 'in_progress': return 'In Progress';
case 'resolved': return 'Resolved';
case 'closed': return 'Closed';
case 'reopened': return 'Reopened';
default: return s;
}
}

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
const Text('Filter:'),
ChoiceChip(label: const Text('All'), selected: _status == 'all', onSelected: (_) => setState(() { _status = 'all'; _load(); })),
ChoiceChip(label: const Text('New'), selected: _status == 'new', onSelected: (_) => setState(() { _status = 'new'; _load(); })),
ChoiceChip(label: const Text('Acknowledged'), selected: _status == 'acknowledged', onSelected: (_) => setState(() { _status = 'acknowledged'; _load(); })),
ChoiceChip(label: const Text('In Progress'), selected: _status == 'in_progress', onSelected: (_) => setState(() { _status = 'in_progress'; _load(); })),
ChoiceChip(label: const Text('Resolved'), selected: _status == 'resolved', onSelected: (_) => setState(() { _status = 'resolved'; _load(); })),
ChoiceChip(label: const Text('Closed'), selected: _status == 'closed', onSelected: (_) => setState(() { _status = 'closed'; _load(); })),
ChoiceChip(label: const Text('Reopened'), selected: _status == 'reopened', onSelected: (_) => setState(() { _status = 'reopened'; _load(); })),
const SizedBox(width: 8),
FilledButton.icon(onPressed: _newTicket, icon: const Icon(Icons.add), label: const Text('New Ticket')),
]),
),
),
const SizedBox(height: 8),
if (_loading) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())) else if (_tickets.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No tickets yet'))) else ...[
for (final t in _tickets)
Card(
child: ListTile(
leading: CircleAvatar(backgroundColor: _statusColor((t[SupportTicketSchema.status] as String?) ?? 'new').withValues(alpha: 0.15), child: Icon(Icons.support_agent, color: _statusColor((t[SupportTicketSchema.status] as String?) ?? 'new'))),
title: Text((t[SupportTicketSchema.subject] as String?) ?? '-', overflow: TextOverflow.ellipsis),
subtitle: Text('${(t[SupportTicketSchema.category] as String?) ?? ''} • Priority: ${(t[SupportTicketSchema.priority] as String?) ?? ''} • Status: ${_labelStatus((t[SupportTicketSchema.status] as String?) ?? 'new')}', overflow: TextOverflow.ellipsis),
trailing: IconButton(icon: const Icon(Icons.open_in_new, color: Colors.blue), onPressed: () async { await showDialog(context: context, builder: (ctx) => _TicketDetailsDialog(instId: widget.instId, ticket: t)); await _load(); }),
),
)
]
],
),
);
}
}

class _LocalAttachment {
final Uint8List bytes; final String extension;
_LocalAttachment(this.bytes, this.extension);
}

class _NewTicketDialog extends StatefulWidget {
const _NewTicketDialog();
@override
State<_NewTicketDialog> createState() => _NewTicketDialogState();
}

class _NewTicketDialogState extends State<_NewTicketDialog> {
final _subject = TextEditingController();
final _desc = TextEditingController();
String _category = 'complaint';
String _priority = 'medium';
final List<_LocalAttachment> _attachments = [];
bool _busy = false;

@override
void dispose() { _subject.dispose(); _desc.dispose(); super.dispose(); }

Future<void> _pick() async {
final picker = ImagePicker();
final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
if (f == null) return;
final bytes = await f.readAsBytes();
String ext = 'jpg'; final name = f.name.toLowerCase();
if (name.endsWith('.png')) ext = 'png'; else if (name.endsWith('.webp')) ext = 'webp'; else if (name.endsWith('.jpeg')) ext = 'jpeg';
setState(() => _attachments.add(_LocalAttachment(bytes, ext)));
}

void _submit() {
final s = _subject.text.trim(); final d = _desc.text.trim();
if (s.isEmpty || d.isEmpty) return;
Navigator.pop<(String, String, String, String, List<_LocalAttachment>)>(context, (s, _category, _priority, d, _attachments));
}

@override
Widget build(BuildContext context) {
return AlertDialog(
title: const Text('New Support Ticket'),
content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
DropdownButtonFormField<String>(value: _category, onChanged: (v) => setState(() => _category = v ?? _category), items: const [
DropdownMenuItem(value: 'complaint', child: Text('Complaint')),
DropdownMenuItem(value: 'feedback', child: Text('Feedback')),
DropdownMenuItem(value: 'suggestion', child: Text('Suggestion')),
DropdownMenuItem(value: 'technical', child: Text('Technical Assistance')),
DropdownMenuItem(value: 'enhancement', child: Text('Enhancement Request')),
DropdownMenuItem(value: 'feature', child: Text('Feature Addition')),
DropdownMenuItem(value: 'other', child: Text('Other')),
], decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder())),
const SizedBox(height: 8),
DropdownButtonFormField<String>(value: _priority, onChanged: (v) => setState(() => _priority = v ?? _priority), items: const [
DropdownMenuItem(value: 'low', child: Text('Low')),
DropdownMenuItem(value: 'medium', child: Text('Medium')),
DropdownMenuItem(value: 'high', child: Text('High')),
DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
], decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder())),
const SizedBox(height: 8),
TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder())),
const SizedBox(height: 8),
TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()), minLines: 4, maxLines: 8),
const SizedBox(height: 8),
Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
OutlinedButton.icon(onPressed: _busy ? null : _pick, icon: const Icon(Icons.attach_file, color: Colors.blue), label: const Text('Add attachment')),
if (_attachments.isNotEmpty) ...[
for (int i = 0; i < _attachments.length; i++) Chip(label: Text('Attachment ${i + 1}'), onDeleted: () => setState(() => _attachments.removeAt(i)))
]
])),
]))),
actions: [
TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create')),
],
);
}
}

class _TicketDetailsDialog extends StatefulWidget {
final String instId; final Map<String, dynamic> ticket;
const _TicketDetailsDialog({required this.instId, required this.ticket});
@override
State<_TicketDetailsDialog> createState() => _TicketDetailsDialogState();
}

class _TicketDetailsDialogState extends State<_TicketDetailsDialog> {
final _repo = FirebaseSupportTicketRepository();
final _message = TextEditingController();
String? _statusChange;
final List<_LocalAttachment> _newAttachments = [];
bool _busy = false;
List<Map<String, dynamic>> _updates = [];
bool _loading = true;

@override
void initState() { super.initState(); _load(); }

Future<void> _load() async {
setState(() => _loading = true);
final u = await _repo.listUpdates(ticketId: widget.ticket[SupportTicketSchema.id] as String);
if (!mounted) return; setState(() { _updates = u; _loading = false; });
}

Future<void> _pick() async {
final picker = ImagePicker();
final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
if (f == null) return; final bytes = await f.readAsBytes();
String ext = 'jpg'; final name = f.name.toLowerCase(); if (name.endsWith('.png')) ext = 'png'; else if (name.endsWith('.webp')) ext = 'webp'; else if (name.endsWith('.jpeg')) ext = 'jpeg';
setState(() => _newAttachments.add(_LocalAttachment(bytes, ext)));
}

Future<void> _send() async {
final msg = _message.text.trim();
if (msg.isEmpty && _statusChange == null && _newAttachments.isEmpty) return;
setState(() => _busy = true);
try {
final name = 'Inst ${widget.instId}';
List<String> urls = [];
if (_newAttachments.isNotEmpty) {
final storage = FirebaseStorageService();
for (final a in _newAttachments) {
final url = await storage.uploadSupportAttachment(instId: widget.instId, ticketId: widget.ticket[SupportTicketSchema.id] as String, data: a.bytes, fileExtension: a.extension);
urls.add(url);
}
}
await _repo.addUpdate(ticketId: widget.ticket[SupportTicketSchema.id] as String, authorRole: 'institution_admin', authorName: name, statusChange: _statusChange, message: msg.isEmpty ? (_statusChange != null ? 'Status updated' : 'Attachment') : msg, attachmentUrls: urls);
_message.clear(); _newAttachments.clear(); _statusChange = null; await _load();
if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Update sent')));
} catch (e) {
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
} finally {
if (mounted) setState(() => _busy = false);
}
}

Widget _chip(String label, Color color, [IconData? icon]) => Chip(label: Text(label), avatar: icon != null ? Icon(icon, size: 16, color: color) : null, backgroundColor: color.withValues(alpha: 0.10));

@override
Widget build(BuildContext context) {
final t = widget.ticket; final status = (t[SupportTicketSchema.status] as String?) ?? 'new';
return AlertDialog(
title: const Text('Ticket Details'),
content: SizedBox(
width: 640,
child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
Text((t[SupportTicketSchema.subject] as String?) ?? '-', style: Theme.of(context).textTheme.titleMedium),
const SizedBox(height: 4),
Wrap(spacing: 6, runSpacing: 6, children: [
_chip('Status: $status', Colors.blue, Icons.info_outline),
_chip('Category: ${t[SupportTicketSchema.category]}', Colors.purple, Icons.category),
_chip('Priority: ${t[SupportTicketSchema.priority]}', Colors.orange, Icons.priority_high),
if ((t[SupportTicketSchema.assignee] as String?) != null) _chip('Assignee: ${t[SupportTicketSchema.assignee]}', Theme.of(context).colorScheme.primary, Icons.person),
]),
const SizedBox(height: 8),
Align(alignment: Alignment.centerLeft, child: Text((t[SupportTicketSchema.description] as String?) ?? '-', softWrap: true)),
const Divider(height: 16),
Text('Updates', style: Theme.of(context).textTheme.titleSmall),
const SizedBox(height: 6),
Flexible(
child: _loading
? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
: (_updates.isEmpty
? const Text('No updates yet')
: ListView.separated(shrinkWrap: true, itemCount: _updates.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (ctx, i) {
final u = _updates[i];
final role = (u[SupportUpdateSchema.authorRole] as String?) ?? 'institution_admin';
final name = (u[SupportUpdateSchema.authorName] as String?) ?? role;
final msg = (u[SupportUpdateSchema.message] as String?) ?? '';
final stat = (u[SupportUpdateSchema.statusChange] as String?);
final att = (u[SupportUpdateSchema.attachmentUrls] as List?)?.cast<String>() ?? const [];
return ListTile(
leading: Icon(role == 'admin' ? Icons.shield : Icons.account_circle, color: Theme.of(context).colorScheme.primary),
title: Text(name, overflow: TextOverflow.ellipsis),
subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
if (stat != null) Text('Status: $stat'),
if (msg.isNotEmpty) Text(msg, softWrap: true),
if (att.isNotEmpty)
Wrap(spacing: 6, runSpacing: 6, children: [
for (final url in att) InkWell(onTap: () {}, child: Chip(label: const Text('Attachment'), avatar: const Icon(Icons.attachment, size: 16, color: Colors.blue)))
])
]),
);
})),
),
const Divider(height: 16),
Text('Reply / Update', style: Theme.of(context).textTheme.titleSmall),
const SizedBox(height: 6),
DropdownButtonFormField<String?>(
value: _statusChange,
items: const [
DropdownMenuItem(value: null, child: Text('No status change')),
DropdownMenuItem(value: 'acknowledged', child: Text('Acknowledge')),
DropdownMenuItem(value: 'in_progress', child: Text('Work in Progress')),
DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
DropdownMenuItem(value: 'closed', child: Text('Closed')),
DropdownMenuItem(value: 'reopened', child: Text('Reopened')),
],
onChanged: (v) => setState(() => _statusChange = v),
decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Status'),
),
const SizedBox(height: 8),
TextField(controller: _message, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Message'), minLines: 2, maxLines: 5),
const SizedBox(height: 8),
Wrap(spacing: 8, runSpacing: 8, children: [
OutlinedButton.icon(onPressed: _busy ? null : _pick, icon: const Icon(Icons.attach_file, color: Colors.blue), label: const Text('Attach')),
if (_newAttachments.isNotEmpty) ...[
for (int i = 0; i < _newAttachments.length; i++) Chip(label: Text('Attachment ${i + 1}'), onDeleted: () => setState(() => _newAttachments.removeAt(i)))
]
])
]),
),
actions: [
TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
FilledButton(onPressed: _busy ? null : _send, child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send')),
],
);
}
}

class _PaymentsHistoryDialog extends StatefulWidget {
final String instId; final String studentId;
const _PaymentsHistoryDialog({required this.instId, required this.studentId});
@override
State<_PaymentsHistoryDialog> createState() => _PaymentsHistoryDialogState();
}

class _PaymentsHistoryDialogState extends State<_PaymentsHistoryDialog> {
final _payRepo = FirebasePaymentRepository();
final _feeRepo = FirebaseFeeRepository();
List<Map<String, dynamic>> _payments = [];
List<Map<String, dynamic>> _unpaidFees = [];
bool _loading = true;
String? _error;

@override
void initState() { super.initState(); _load(); }

Future<void> _load() async {
setState(() { _loading = true; _error = null; });
try {
final pays = await _payRepo.listPaymentsForStudent(instId: widget.instId, studentId: widget.studentId);
final fees = await _feeRepo.listFees(instId: widget.instId, studentId: widget.studentId);
if (!mounted) return;
setState(() {
_payments = pays;
_unpaidFees = fees.where((f) => ((f[FeeItemSchema.deleted] as bool?) ?? false) == false && (f[FeeItemSchema.status] as String? ?? 'pending') != 'paid').toList();
});
} catch (e) {
if (!mounted) return;
setState(() {
_error = e.toString();
_payments = [];
_unpaidFees = [];
});
} finally {
if (!mounted) return;
setState(() { _loading = false; });
}
}

Future<void> _markAsPaidFlow() async {
if (_unpaidFees.isEmpty) return;
final selected = await showDialog<Map<String, dynamic>?>(context: context, builder: (ctx) {
return AlertDialog(
title: const Text('Select Fee to Mark Paid'),
content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: _unpaidFees.isEmpty ? const Text('No unpaid items') : ListView.separated(shrinkWrap: true, itemCount: _unpaidFees.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
final f = _unpaidFees[i];
final label = (f[FeeItemSchema.label] as String?) ?? ((f[FeeItemSchema.type] as String?) == FeeItemSchema.typeMonthly ? 'Monthly Fee' : 'Other charge');
final amt = (f[FeeItemSchema.amount] as num? ?? 0).toStringAsFixed(2);
final dueTs = f[FeeItemSchema.dueDate] as Timestamp?; final due = dueTs?.toDate();
final dueStr = due == null ? '-' : '${due.day}/${due.month}/${due.year}';
return ListTile(
leading: const Icon(Icons.payments, color: Colors.blue),
title: Text('$label • ₹$amt', overflow: TextOverflow.ellipsis),
subtitle: Text('Due: $dueStr', overflow: TextOverflow.ellipsis),
trailing: FilledButton(onPressed: () => Navigator.pop(ctx, f), child: const Text('Select')),
onTap: () => Navigator.pop(ctx, f),
);
})),
actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
);
});
if (selected == null) return;
final result = await showDialog<PaymentSubmissionResult>(context: context, builder: (ctx) => const PaymentSubmissionDialog(title: 'Record Payment', showAdminHint: true));
if (result == null) return;
try {
String? proofUrl;
if (result.proofBytes != null && result.proofExtension != null) {
proofUrl = await FirebaseStorageService().uploadPaymentProof(instId: widget.instId, studentId: widget.studentId, feeItemId: selected[FeeItemSchema.id] as String, data: result.proofBytes!, fileExtension: result.proofExtension!);
}
final label = (selected[FeeItemSchema.label] as String?) ?? ((selected[FeeItemSchema.type] as String?) == FeeItemSchema.typeMonthly ? 'Monthly Fee' : 'Other charge');
final amount = selected[FeeItemSchema.amount] as num? ?? 0;
final paymentId = await _payRepo.addPayment(instId: widget.instId, studentId: widget.studentId, amount: amount, method: result.method, feeItemId: selected[FeeItemSchema.id] as String?, feeLabel: label, note: result.note, proofUrl: proofUrl, submittedBy: 'institution_admin');
await _feeRepo.markFeePaid(instId: widget.instId, studentId: widget.studentId, feeItemId: selected[FeeItemSchema.id] as String, paymentId: paymentId);
await _load();
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as paid')));
}
} catch (e) {
if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
}
}

@override
Widget build(BuildContext context) {
return AlertDialog(
title: const Text('Payments History'),
content: SizedBox(
width: 560,
child: _loading
? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
: (_error != null
? Center(
child: Padding(
padding: const EdgeInsets.all(12),
child: Column(mainAxisSize: MainAxisSize.min, children: [
const Icon(Icons.error_outline, color: Colors.red),
const SizedBox(height: 8),
const Text('Could not load payments'),
const SizedBox(height: 4),
Text(_error!, style: Theme.of(context).textTheme.bodySmall, softWrap: true, overflow: TextOverflow.ellipsis),
const SizedBox(height: 8),
FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
]),
),
)
: Column(mainAxisSize: MainAxisSize.min, children: [
Align(
alignment: Alignment.centerLeft,
child: FilledButton.icon(onPressed: _unpaidFees.isEmpty ? null : _markAsPaidFlow, icon: const Icon(Icons.check_circle), label: const Text('Mark As Paid')),
),
const SizedBox(height: 8),
Flexible(
child: _payments.isEmpty
? const Center(child: Text('No payments yet'))
: ListView.separated(
shrinkWrap: true,
itemCount: _payments.length,
separatorBuilder: (_, __) => const SizedBox(height: 8),
itemBuilder: (ctx, i) {
final p = _payments[i];
final ts = (p[PaymentSchema.paidAt] as Timestamp?)?.toDate();
final created = (p[PaymentSchema.createdAt] as Timestamp?)?.toDate();
final status = p[PaymentSchema.status] as String? ?? 'paid';
final isPaid = status == 'paid';
return Card(
child: ListTile(
leading: Icon(Icons.receipt_long, color: isPaid ? Colors.green : Colors.blue),
title: Text('₹${(p[PaymentSchema.amount] as num? ?? 0).toString()} • ${p[PaymentSchema.method]} • ${status.toUpperCase()}', overflow: TextOverflow.ellipsis),
subtitle: Text(
isPaid
? '${(p[PaymentSchema.feeLabel] as String?) != null ? '${p[PaymentSchema.feeLabel]} • ' : ''}Receipt: ${p[PaymentSchema.receiptNo]} • ${ts != null ? '${ts.day}/${ts.month}/${ts.year}' : ''}'
: '${(p[PaymentSchema.feeLabel] as String?) != null ? '${p[PaymentSchema.feeLabel]} • ' : ''}Submitted: ${created != null ? '${created.day}/${created.month}/${created.year}' : ''}',
overflow: TextOverflow.ellipsis,
),
trailing: Row(mainAxisSize: MainAxisSize.min, children: [
if (isPaid)
IconButton(
tooltip: 'View Receipt',
icon: const Icon(Icons.visibility, color: Colors.blue),
onPressed: () async {
await showDialog(context: context, builder: (ctx) => ReceiptViewDialog.forPayment(instId: widget.instId, payment: p));
},
),
]),
),
);
},
),
),
])),
),
actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
);
}
}

