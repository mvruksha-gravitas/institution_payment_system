import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';

class FirebaseFeeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _instRef() => _firestore.collection(InstitutionRegistrationSchema.collectionName);

  Future<String> addMonthlyFee({
    required String instId,
    required String studentId,
    required num amount,
    required int month,
    required int year,
    required DateTime? dueDate,
    bool recurring = false,
  }) async {
    final now = DateTime.now();
    final feesRef = _instRef().doc(instId).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId).collection(FeeItemSchema.subcollectionName);
    // Generate a label e.g. "Monthly Fee Aug 2025"
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final label = 'Monthly Fee ${months[(month - 1).clamp(0, 11)]} $year';
    final doc = feesRef.doc();
    await doc.set({
      FeeItemSchema.id: doc.id,
      FeeItemSchema.instId: instId,
      FeeItemSchema.studentId: studentId,
      FeeItemSchema.type: FeeItemSchema.typeMonthly,
      FeeItemSchema.label: label,
      FeeItemSchema.amount: amount,
      FeeItemSchema.month: month,
      FeeItemSchema.year: year,
      FeeItemSchema.dueDate: dueDate != null ? Timestamp.fromDate(dueDate) : null,
      FeeItemSchema.status: 'pending',
      FeeItemSchema.paymentId: null,
      FeeItemSchema.recurring: recurring,
      FeeItemSchema.createdAt: Timestamp.fromDate(now),
      FeeItemSchema.updatedAt: Timestamp.fromDate(now),
    });
    return doc.id;
  }

  Future<String> addOtherCharge({
    required String instId,
    required String studentId,
    required num amount,
    required String reason,
    required DateTime? dueDate,
  }) async {
    final now = DateTime.now();
    final feesRef = _instRef().doc(instId).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId).collection(FeeItemSchema.subcollectionName);
    final doc = feesRef.doc();
    await doc.set({
      FeeItemSchema.id: doc.id,
      FeeItemSchema.instId: instId,
      FeeItemSchema.studentId: studentId,
      FeeItemSchema.type: FeeItemSchema.typeOther,
      FeeItemSchema.label: reason,
      FeeItemSchema.amount: amount,
      FeeItemSchema.month: null,
      FeeItemSchema.year: null,
      FeeItemSchema.dueDate: dueDate != null ? Timestamp.fromDate(dueDate) : null,
      FeeItemSchema.status: 'pending',
      FeeItemSchema.paymentId: null,
      FeeItemSchema.createdAt: Timestamp.fromDate(now),
      FeeItemSchema.updatedAt: Timestamp.fromDate(now),
    });
    return doc.id;
  }

  Future<List<Map<String, dynamic>>> listFees({required String instId, required String studentId}) async {
    final snap = await _instRef()
        .doc(instId)
        .collection(InstitutionRegistrationSchema.studentsSubcollection)
        .doc(studentId)
        .collection(FeeItemSchema.subcollectionName)
        .orderBy(FeeItemSchema.createdAt, descending: true)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<void> markFeePaid({
    required String instId,
    required String studentId,
    required String feeItemId,
    required String paymentId,
  }) async {
    final ref = _instRef().doc(instId).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId).collection(FeeItemSchema.subcollectionName).doc(feeItemId);
    await ref.update({
      FeeItemSchema.status: 'paid',
      FeeItemSchema.paymentId: paymentId,
      FeeItemSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> submitFeeForConfirmation({
    required String instId,
    required String studentId,
    required String feeItemId,
    required String method,
    String? note,
    String? proofUrl,
  }) async {
    final ref = _instRef().doc(instId).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId).collection(FeeItemSchema.subcollectionName).doc(feeItemId);
    await ref.update({
      FeeItemSchema.status: 'to_confirm',
      FeeItemSchema.submissionMethod: method,
      FeeItemSchema.submissionNote: note,
      FeeItemSchema.submissionProofUrl: proofUrl,
      FeeItemSchema.submittedBy: 'student',
      FeeItemSchema.submittedAt: Timestamp.fromDate(DateTime.now()),
      FeeItemSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> updateFeeItem({
    required String instId,
    required String studentId,
    required String feeItemId,
    num? amount,
    DateTime? dueDate,
  }) async {
    final ref = _instRef().doc(instId).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId).collection(FeeItemSchema.subcollectionName).doc(feeItemId);
    final Map<String, dynamic> patch = {};
    if (amount != null) patch[FeeItemSchema.amount] = amount;
    patch[FeeItemSchema.dueDate] = dueDate != null ? Timestamp.fromDate(dueDate) : null;
    patch[FeeItemSchema.updatedAt] = Timestamp.fromDate(DateTime.now());
    await ref.update(patch);
  }

  Future<void> deleteFeeItem({
    required String instId,
    required String studentId,
    required String feeItemId,
    required String reason,
  }) async {
    final ref = _instRef()
        .doc(instId)
        .collection(InstitutionRegistrationSchema.studentsSubcollection)
        .doc(studentId)
        .collection(FeeItemSchema.subcollectionName)
        .doc(feeItemId);
    final snap = await ref.get();
    final data = snap.data();
    final status = data != null ? (data[FeeItemSchema.status] as String? ?? 'pending') : 'pending';
    if (status == 'paid') {
      throw Exception('Cannot delete a paid item');
    }
    // Soft delete: keep the row but exclude from totals
    await ref.update({
      FeeItemSchema.deleted: true,
      FeeItemSchema.deletedReason: reason,
      FeeItemSchema.deletedAt: Timestamp.fromDate(DateTime.now()),
      FeeItemSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
  }
}
