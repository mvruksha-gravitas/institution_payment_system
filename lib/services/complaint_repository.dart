import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';

class FirebaseComplaintRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _instRef() => _firestore.collection(InstitutionRegistrationSchema.collectionName);

  String _normalizeInstId(String id) => id.trim().toUpperCase();

  Future<String> addComplaint({
    required String instId,
    required String studentId,
    required String studentName,
    String? roomNumber,
    required String subject,
    required String message,
  }) async {
    final ref = _instRef().doc(_normalizeInstId(instId)).collection(ComplaintSchema.collectionName).doc();
    final now = Timestamp.fromDate(DateTime.now());
    await ref.set({
      ComplaintSchema.id: ref.id,
      ComplaintSchema.studentId: studentId,
      ComplaintSchema.studentName: studentName,
      ComplaintSchema.roomNumber: roomNumber,
      ComplaintSchema.subject: subject,
      ComplaintSchema.message: message,
      ComplaintSchema.status: 'no_action',
      ComplaintSchema.createdAt: now,
      ComplaintSchema.updatedAt: now,
    });
    return ref.id;
  }

  Future<List<Map<String, dynamic>>> listComplaints({required String instId}) async {
    final snap = await _instRef()
        .doc(_normalizeInstId(instId))
        .collection(ComplaintSchema.collectionName)
        .orderBy(ComplaintSchema.createdAt, descending: true)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<void> updateStatus({required String instId, required String complaintId, required String status}) async {
    final now = Timestamp.fromDate(DateTime.now());
    await _instRef()
        .doc(_normalizeInstId(instId))
        .collection(ComplaintSchema.collectionName)
        .doc(complaintId)
        .update({ComplaintSchema.status: status, ComplaintSchema.updatedAt: now});
  }
}
