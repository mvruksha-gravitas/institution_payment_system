import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';

class FirebaseSupportTicketRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tickets() => _firestore.collection(SupportTicketSchema.collectionName);

  Future<String> createTicket({
    required String instId,
    required String createdByName,
    required String category,
    required String priority,
    required String subject,
    required String description,
    List<String>? attachmentUrls,
  }) async {
    final now = Timestamp.fromDate(DateTime.now());
    final ref = _tickets().doc();
    await ref.set({
      SupportTicketSchema.id: ref.id,
      SupportTicketSchema.instId: instId,
      SupportTicketSchema.subject: subject,
      SupportTicketSchema.description: description,
      SupportTicketSchema.category: category,
      SupportTicketSchema.priority: priority,
      SupportTicketSchema.status: SupportTicketSchema.statusNew,
      SupportTicketSchema.assignee: null,
      SupportTicketSchema.createdByRole: 'institution_admin',
      SupportTicketSchema.createdByName: createdByName,
      SupportTicketSchema.createdAt: now,
      SupportTicketSchema.updatedAt: now,
      SupportTicketSchema.attachmentUrls: attachmentUrls ?? <String>[],
    });
    return ref.id;
  }

  Future<void> addUpdate({
    required String ticketId,
    required String authorRole, // admin | institution_admin
    required String authorName,
    String? statusChange,
    required String message,
    List<String>? attachmentUrls,
  }) async {
    final now = Timestamp.fromDate(DateTime.now());
    final upd = _tickets().doc(ticketId).collection(SupportUpdateSchema.subcollectionName).doc();
    await upd.set({
      SupportUpdateSchema.id: upd.id,
      SupportUpdateSchema.authorRole: authorRole,
      SupportUpdateSchema.authorName: authorName,
      SupportUpdateSchema.message: message,
      SupportUpdateSchema.statusChange: statusChange,
      SupportUpdateSchema.attachmentUrls: attachmentUrls ?? <String>[],
      SupportUpdateSchema.createdAt: now,
    });
    await _tickets().doc(ticketId).update({SupportTicketSchema.updatedAt: now, if (statusChange != null) SupportTicketSchema.status: statusChange});
  }

  Future<void> setStatus({required String ticketId, required String status}) async {
    await _tickets().doc(ticketId).update({
      SupportTicketSchema.status: status,
      SupportTicketSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> assignTo({required String ticketId, required String assignee}) async {
    await _tickets().doc(ticketId).update({
      SupportTicketSchema.assignee: assignee,
      SupportTicketSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<List<Map<String, dynamic>>> listTicketsForInstitution({required String instId, String status = 'all'}) async {
    // Remove orderBy to avoid composite index requirement - sort in memory instead
    Query<Map<String, dynamic>> q = _tickets().where(SupportTicketSchema.instId, isEqualTo: instId);
    final snap = await q.get();
    var results = snap.docs.map((d) => d.data()).toList();
    
    // Filter by status after fetching if needed
    if (status != 'all') {
      results = results.where((ticket) => ticket[SupportTicketSchema.status] == status).toList();
    }
    
    // Sort by updatedAt in memory
    results.sort((a, b) {
      final aTime = a[SupportTicketSchema.updatedAt] as Timestamp?;
      final bTime = b[SupportTicketSchema.updatedAt] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime); // descending order
    });
    
    return results;
  }

  Future<List<Map<String, dynamic>>> listAllTickets({String status = 'all'}) async {
    final snap = await _tickets().orderBy(SupportTicketSchema.updatedAt, descending: true).get();
    var results = snap.docs.map((d) => d.data()).toList();
    
    // Filter by status after fetching if needed
    if (status != 'all') {
      results = results.where((ticket) => ticket[SupportTicketSchema.status] == status).toList();
    }
    
    return results;
  }

  Future<List<Map<String, dynamic>>> listUpdates({required String ticketId}) async {
    final snap = await _tickets().doc(ticketId).collection(SupportUpdateSchema.subcollectionName).orderBy(SupportUpdateSchema.createdAt, descending: false).get();
    return snap.docs.map((d) => d.data()).toList();
  }
}
