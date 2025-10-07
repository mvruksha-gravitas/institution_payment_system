import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';

class FirebasePaymentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _instRef() => _firestore.collection(InstitutionRegistrationSchema.collectionName);

  Future<String> addPayment({
    required String instId,
    required String studentId,
    required num amount,
    required String method, // 'cash' | 'upi' | 'netbanking' | 'online'
    String? roomNumber,
    String? feeItemId,
    String? feeLabel,
    String? note,
    String? proofUrl,
    String submittedBy = 'institution_admin',
  }) async {
    final now = DateTime.now();
    final payments = _instRef().doc(instId).collection(InstitutionRegistrationSchema.paymentsSubcollection);
    final doc = payments.doc();
    await doc.set({
      PaymentSchema.id: doc.id,
      PaymentSchema.studentId: studentId,
      PaymentSchema.instId: instId,
      PaymentSchema.amount: amount,
      PaymentSchema.status: 'paid',
      PaymentSchema.method: method,
      PaymentSchema.receiptNo: 'R${now.millisecondsSinceEpoch}',
      PaymentSchema.paidAt: Timestamp.fromDate(now),
      PaymentSchema.createdAt: Timestamp.fromDate(now),
      PaymentSchema.roomNumber: roomNumber,
      PaymentSchema.feeItemId: feeItemId,
      PaymentSchema.feeLabel: feeLabel,
      PaymentSchema.note: note,
      PaymentSchema.proofUrl: proofUrl,
      PaymentSchema.submittedBy: submittedBy,
    });
    return doc.id;
  }

  Future<String> addPendingPayment({
    required String instId,
    required String studentId,
    required num amount,
    required String method,
    String? feeItemId,
    String? feeLabel,
    String? note,
    String? proofUrl,
  }) async {
    final now = DateTime.now();
    final payments = _instRef().doc(instId).collection(InstitutionRegistrationSchema.paymentsSubcollection);
    final doc = payments.doc();
    await doc.set({
      PaymentSchema.id: doc.id,
      PaymentSchema.studentId: studentId,
      PaymentSchema.instId: instId,
      PaymentSchema.amount: amount,
      PaymentSchema.status: 'pending',
      PaymentSchema.method: method,
      PaymentSchema.receiptNo: null,
      PaymentSchema.paidAt: null,
      PaymentSchema.createdAt: Timestamp.fromDate(now),
      PaymentSchema.roomNumber: null,
      PaymentSchema.feeItemId: feeItemId,
      PaymentSchema.feeLabel: feeLabel,
      PaymentSchema.note: note,
      PaymentSchema.proofUrl: proofUrl,
      PaymentSchema.submittedBy: 'student',
    });
    return doc.id;
  }

  Future<void> approvePendingPayment({required String instId, required String paymentId}) async {
    final payments = _instRef().doc(instId).collection(InstitutionRegistrationSchema.paymentsSubcollection).doc(paymentId);
    final now = DateTime.now();
    await payments.update({
      PaymentSchema.status: 'paid',
      PaymentSchema.receiptNo: 'R${now.millisecondsSinceEpoch}',
      PaymentSchema.paidAt: Timestamp.fromDate(now),
      PaymentSchema.submittedBy: 'institution_admin',
    });
  }

  Future<List<Map<String, dynamic>>> listPayments({required String instId, String? roomFilter}) async {
    Query<Map<String, dynamic>> q = _instRef().doc(instId).collection(InstitutionRegistrationSchema.paymentsSubcollection);
    
    // To avoid composite index requirements, we'll handle filtering in memory if roomFilter is provided
    if (roomFilter != null && roomFilter.isNotEmpty) {
      // Get all payments ordered by createdAt
      final snap = await q.orderBy(PaymentSchema.createdAt, descending: true).get();
      // Filter in memory for the specific room
      return snap.docs
          .where((doc) => doc.data()[PaymentSchema.roomNumber] == roomFilter)
          .map((d) => d.data())
          .toList();
    } else {
      // No room filter, just order by createdAt
      final snap = await q.orderBy(PaymentSchema.createdAt, descending: true).get();
      return snap.docs.map((d) => d.data()).toList();
    }
  }

  Future<List<Map<String, dynamic>>> listPaymentsForStudent({required String instId, required String studentId}) async {
    // To avoid composite index requirements, get all payments first then filter
    final q = _instRef()
        .doc(instId)
        .collection(InstitutionRegistrationSchema.paymentsSubcollection)
        .orderBy(PaymentSchema.createdAt, descending: true);
    final snap = await q.get();
    
    // Filter in memory for the specific student
    return snap.docs
        .where((doc) => doc.data()[PaymentSchema.studentId] == studentId)
        .map((d) => d.data())
        .toList();
  }

  Future<num> totalPaidAmount({required String instId}) async {
    final snap = await _instRef().doc(instId).collection(InstitutionRegistrationSchema.paymentsSubcollection).get();
    num sum = 0;
    for (final d in snap.docs) {
      sum += (d.data()[PaymentSchema.amount] as num? ?? 0);
    }
    return sum;
  }
}
