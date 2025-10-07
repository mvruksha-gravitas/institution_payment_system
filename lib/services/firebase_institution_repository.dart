import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:institutation_payment_system/models/institution_models.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';

class FirebaseInstitutionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get reference to institutions collection
  CollectionReference<Map<String, dynamic>> get _institutionsRef => _firestore.collection(InstitutionRegistrationSchema.collectionName);

  // Submit a new institution registration request (legacy: creates a pending request)
  Future<String> submitInstitutionRequest({
    required String institutionName,
    required String personName,
    required String phoneNumber,
    required String email,
  }) async {
    try {
      final now = DateTime.now();
      final docRef = await _institutionsRef.add({
        InstitutionRegistrationSchema.institutionName: institutionName,
        InstitutionRegistrationSchema.personName: personName,
        InstitutionRegistrationSchema.phoneNumber: phoneNumber,
        InstitutionRegistrationSchema.email: email,
        InstitutionRegistrationSchema.status: InstitutionRegistrationSchema.statusPending,
        InstitutionRegistrationSchema.enabled: true,
        InstitutionRegistrationSchema.createdAt: Timestamp.fromDate(now),
        InstitutionRegistrationSchema.updatedAt: Timestamp.fromDate(now),
        InstitutionRegistrationSchema.approvedAt: null,
        InstitutionRegistrationSchema.rejectedAt: null,
        InstitutionRegistrationSchema.adminNotes: '',
        InstitutionRegistrationSchema.uniqueInstitutionId: null,
        InstitutionRegistrationSchema.loginCredentials: null,
      });
      // Update the document with its own ID
      await docRef.update({InstitutionRegistrationSchema.id: docRef.id});
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to submit institution request: $e');
    }
  }

  // Legacy immediate registration (kept for backward compatibility in case route is used)
  // Generates InstId and approves instantly. Institution Admin username is the phone number; password is a temp value.
  Future<(String instId, GeneratedCredentials adminCredentials)> registerInstitutionImmediate({
    required String institutionName,
    required String personName,
    required String phoneNumber,
    required String email,
  }) async {
    try {
      // Enforce uniqueness of Institution Admin phone across institutions
      final adminQ = await _institutionsRef.where(InstitutionRegistrationSchema.phoneNumber, isEqualTo: phoneNumber).limit(1).get();
      if (adminQ.docs.isNotEmpty) {
        throw Exception('This phone number is already registered for an Institution Admin');
      }
      // Enforce that this phone is not used by any student in any institution
      final studentQ = await _firestore
          .collectionGroup(InstitutionRegistrationSchema.studentsSubcollection)
          .where(StudentSchema.phoneNumber, isEqualTo: phoneNumber)
          .limit(1)
          .get();
      if (studentQ.docs.isNotEmpty) {
        throw Exception('This phone number is already registered to a student account');
      }

      final now = DateTime.now();
      final instId = await generateUniqueInstitutionId();
      final adminCreds = GeneratedCredentials(username: phoneNumber, password: 'op_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
      // Use InstId as the document id for easy lookups and to host students subcollection
      final docRef = _institutionsRef.doc(instId);
      await docRef.set({
        InstitutionRegistrationSchema.id: instId,
        InstitutionRegistrationSchema.institutionName: institutionName,
        InstitutionRegistrationSchema.personName: personName,
        InstitutionRegistrationSchema.phoneNumber: phoneNumber,
        InstitutionRegistrationSchema.email: email,
        InstitutionRegistrationSchema.status: InstitutionRegistrationSchema.statusApproved,
        InstitutionRegistrationSchema.enabled: true,
        InstitutionRegistrationSchema.createdAt: Timestamp.fromDate(now),
        InstitutionRegistrationSchema.updatedAt: Timestamp.fromDate(now),
        InstitutionRegistrationSchema.approvedAt: Timestamp.fromDate(now),
        InstitutionRegistrationSchema.rejectedAt: null,
        InstitutionRegistrationSchema.adminNotes: '',
        InstitutionRegistrationSchema.uniqueInstitutionId: instId,
        InstitutionRegistrationSchema.loginCredentials: adminCreds.toMap(),
      });
      return (instId, adminCreds);
    } catch (e) {
      throw Exception('Failed to register institution: $e');
    }
  }

  // Create a student account under an institution (InstId is required)
  Future<String> createStudentAccount({
    required String instId,
    required String name,
    required String phoneNumber,
    required String email,
  }) async {
    try {
      // Ensure institution exists by doc id (instId)
      final instDoc = await _institutionsRef.doc(_normalizeInstId(instId)).get();
      if (!instDoc.exists) {
        throw Exception('Institution not found for InstId: $instId');
      }
      if ((instDoc.data()?[InstitutionRegistrationSchema.enabled] as bool?) == false) {
        throw Exception('Institution is disabled');
      }
      final studentRef = _institutionsRef.doc(_normalizeInstId(instId)).collection(InstitutionRegistrationSchema.studentsSubcollection).doc();
      await studentRef.set({
        'id': studentRef.id,
        'inst_id': _normalizeInstId(instId),
        'name': name,
        'phone_number': phoneNumber,
        'email': email,
        'created_at': Timestamp.fromDate(DateTime.now()),
      });
      return studentRef.id;
    } catch (e) {
      throw Exception('Failed to create student account: $e');
    }
  }

  // Get a single institution by InstId (doc id)
  Future<DocumentSnapshot<Map<String, dynamic>>> getInstitutionDoc(String instId) async {
    final ref = await _resolveInstitutionRef(instId);
    return ref.get();
  }

  // Find an approved institution by Institution Admin phone (used to detect duplicates and reset)
  Future<Map<String, dynamic>?> findApprovedByPhone(String phone) async {
    try {
      final q = await _institutionsRef
          .where(InstitutionRegistrationSchema.phoneNumber, isEqualTo: phone)
          .limit(10)
          .get();
      
      // Filter approved entries in client side to avoid composite index requirement
      for (final doc in q.docs) {
        final data = doc.data();
        if (data[InstitutionRegistrationSchema.status] == InstitutionRegistrationSchema.statusApproved) {
          return data;
        }
      }
      return null;
    } catch (e) {
      // Fallback: scan all institutions if needed
      print('findApprovedByPhone fallback: $e');
      return null;
    }
  }

  // Find any institution (any status) by Institution Admin phone (for duplicate enforcement)
  Future<Map<String, dynamic>?> findAnyByPhone(String phone) async {
    final q = await _institutionsRef
        .where(InstitutionRegistrationSchema.phoneNumber, isEqualTo: phone)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.data();
  }

  // Enable/disable institution
  Future<void> setInstitutionEnabled({required String instId, required bool enabled}) async {
    final ref = await _resolveInstitutionRef(instId);
    await ref.update({
      InstitutionRegistrationSchema.enabled: enabled,
      InstitutionRegistrationSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
  }

  // Validate Institution Admin login using InstId + phone (as username) + password
  Future<bool> validateInstitutionAdminLogin({required String instId, required String phone, required String password}) async {
    final ref = await _resolveInstitutionRef(instId);
    final doc = await ref.get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    if ((data[InstitutionRegistrationSchema.enabled] as bool?) == false) return false;
    final creds = data[InstitutionRegistrationSchema.loginCredentials] as Map<String, dynamic>?;
    if (creds == null) return false;
    return (creds['username'] == phone) && (creds['password'] == password);
  }

  // New: Validate Institution Admin login using phone (username) + password only, without InstId
  // Returns (ok, instId) if successful
  Future<(bool ok, String? instId)> validateInstitutionAdminLoginByPhone({required String phone, required String password}) async {
    final q = await _institutionsRef
        .where(InstitutionRegistrationSchema.phoneNumber, isEqualTo: phone)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return (false, null);
    final doc = q.docs.first;
    final data = doc.data();
    if ((data[InstitutionRegistrationSchema.enabled] as bool?) == false) return (false, null);
    if (data[InstitutionRegistrationSchema.status] != InstitutionRegistrationSchema.statusApproved) return (false, null);
    final creds = data[InstitutionRegistrationSchema.loginCredentials] as Map<String, dynamic>?;
    if (creds == null) return (false, null);
    final ok = (creds['username'] == phone) && (creds['password'] == password);
    return (ok, ok ? doc.id : null);
  }

  // Update Institution Admin password to a specific value (OTP flow)
  Future<void> setInstitutionAdminPassword({required String instId, required String newPassword}) async {
    final ref = await _resolveInstitutionRef(instId);
    final doc = await ref.get();
    if (!doc.exists) throw Exception('Institution not found');
    final data = doc.data()!;
    final phone = data[InstitutionRegistrationSchema.phoneNumber] as String? ?? '';
    await ref.update({
      InstitutionRegistrationSchema.loginCredentials: GeneratedCredentials(username: phone, password: newPassword).toMap(),
      InstitutionRegistrationSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
  }

  // Get all pending institution requests
  Future<List<InstitutionRequestModel>> getPendingRequests() async {
    try {
      final querySnapshot = await _institutionsRef
          .where(InstitutionRegistrationSchema.status, isEqualTo: InstitutionRegistrationSchema.statusPending)
          .orderBy(InstitutionRegistrationSchema.createdAt, descending: true)
          .limit(50)
          .get();
      return querySnapshot.docs.map((doc) => InstitutionRequestModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch pending requests: $e');
    }
  }

  // Get all approved institutions
  Future<List<InstitutionRequestModel>> getApprovedInstitutions() async {
    try {
      final querySnapshot = await _institutionsRef
          .where(InstitutionRegistrationSchema.status, isEqualTo: InstitutionRegistrationSchema.statusApproved)
          .orderBy(InstitutionRegistrationSchema.createdAt, descending: true)
          .limit(50)
          .get();
      return querySnapshot.docs.map((doc) => InstitutionRequestModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch approved institutions: $e');
    }
  }

  // Approve an institution request (admin flow)
  // Creates a new document whose id equals the generated InstId, sets Institution Admin credentials with username=phone
  // and deletes the original pending request document. Returns (instId, username=phone, password)
  Future<(String instId, GeneratedCredentials adminCreds)> approveInstitutionRequest({
    required String documentId,
    String? adminNotes,
  }) async {
    try {
      final pendingDoc = await _institutionsRef.doc(documentId).get();
      if (!pendingDoc.exists) throw Exception('Request not found');
      final data = pendingDoc.data()!;
      final institutionName = data[InstitutionRegistrationSchema.institutionName] as String? ?? '';
      final personName = data[InstitutionRegistrationSchema.personName] as String? ?? '';
      final phoneNumber = data[InstitutionRegistrationSchema.phoneNumber] as String? ?? '';
      final email = data[InstitutionRegistrationSchema.email] as String? ?? '';
      final instId = await generateUniqueInstitutionId();
      final password = 'op_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final adminCreds = GeneratedCredentials(username: phoneNumber, password: password);
      final now = DateTime.now();
      final approvedDoc = _institutionsRef.doc(instId);
      await approvedDoc.set({
        InstitutionRegistrationSchema.id: instId,
        InstitutionRegistrationSchema.institutionName: institutionName,
        InstitutionRegistrationSchema.personName: personName,
        InstitutionRegistrationSchema.phoneNumber: phoneNumber,
        InstitutionRegistrationSchema.email: email,
        InstitutionRegistrationSchema.status: InstitutionRegistrationSchema.statusApproved,
        InstitutionRegistrationSchema.enabled: true,
        InstitutionRegistrationSchema.createdAt: data[InstitutionRegistrationSchema.createdAt] ?? Timestamp.fromDate(now),
        InstitutionRegistrationSchema.updatedAt: Timestamp.fromDate(now),
        InstitutionRegistrationSchema.approvedAt: Timestamp.fromDate(now),
        InstitutionRegistrationSchema.rejectedAt: null,
        InstitutionRegistrationSchema.adminNotes: adminNotes ?? 'Approved',
        InstitutionRegistrationSchema.uniqueInstitutionId: instId,
        InstitutionRegistrationSchema.loginCredentials: adminCreds.toMap(),
      });
      // Delete the original document to avoid duplicates
      await _institutionsRef.doc(documentId).delete();
      return (instId, adminCreds);
    } catch (e) {
      throw Exception('Failed to approve institution request: $e');
    }
  }

  // Reject an institution request
  Future<void> rejectInstitutionRequest({
    required String documentId,
    String? adminNotes,
  }) async {
    try {
      final now = DateTime.now();
      await _institutionsRef.doc(documentId).update({
        InstitutionRegistrationSchema.status: InstitutionRegistrationSchema.statusRejected,
        InstitutionRegistrationSchema.updatedAt: Timestamp.fromDate(now),
        InstitutionRegistrationSchema.rejectedAt: Timestamp.fromDate(now),
        InstitutionRegistrationSchema.adminNotes: adminNotes ?? 'Rejected',
      });
    } catch (e) {
      throw Exception('Failed to reject institution request: $e');
    }
  }

  // Stream of pending requests for real-time updates
  Stream<List<InstitutionRequestModel>> getPendingRequestsStream() {
    return _institutionsRef
        .where(InstitutionRegistrationSchema.status, isEqualTo: InstitutionRegistrationSchema.statusPending)
        .orderBy(InstitutionRegistrationSchema.createdAt, descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => InstitutionRequestModel.fromFirestore(doc)).toList());
  }

  // Stream of approved institutions for real-time updates
  Stream<List<InstitutionRequestModel>> getApprovedInstitutionsStream() {
    return _institutionsRef
        .where(InstitutionRegistrationSchema.status, isEqualTo: InstitutionRegistrationSchema.statusApproved)
        .orderBy(InstitutionRegistrationSchema.createdAt, descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => InstitutionRequestModel.fromFirestore(doc)).toList());
  }

  // Generate unique institution ID in format INST#### (case-insensitive, stored uppercase). Random, not sequential.
  Future<String> generateUniqueInstitutionId() async {
    try {
      final rnd = Random.secure();
      for (int i = 0; i < 100; i++) {
        final n = rnd.nextInt(10000); // 0000..9999
        final candidate = 'INST${n.toString().padLeft(4, '0')}'.toUpperCase();
        final exists = await _institutionsRef.doc(candidate).get();
        if (!exists.exists) {
          return candidate; // store uppercase
        }
      }
      throw Exception('Exhausted attempts to generate a unique InstId');
    } catch (e) {
      throw Exception('Failed to generate unique institution ID: $e');
    }
  }

  String _normalizeInstId(String id) => id.trim().toUpperCase();

  // Resolve an institution DocumentReference from either document id or stored unique code fields.
  Future<DocumentReference<Map<String, dynamic>>> _resolveInstitutionRef(String instIdOrCode) async {
    final norm = _normalizeInstId(instIdOrCode);
    // 1) Direct doc id
    final direct = _institutionsRef.doc(norm);
    final directSnap = await direct.get();
    if (directSnap.exists) return direct;
    // 2) Match by unique_institution_id field
    final byUnique = await _institutionsRef.where(InstitutionRegistrationSchema.uniqueInstitutionId, isEqualTo: norm).limit(1).get();
    if (byUnique.docs.isNotEmpty) return byUnique.docs.first.reference;
    // 3) Match by id field
    final byIdField = await _institutionsRef.where(InstitutionRegistrationSchema.id, isEqualTo: norm).limit(1).get();
    if (byIdField.docs.isNotEmpty) return byIdField.docs.first.reference;
    // 4) Try compact form without non-alphanumeric (handles INST-2025-001 vs INST2025001)
    final compact = norm.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact != norm) {
      final alt = _institutionsRef.doc(compact);
      final altSnap = await alt.get();
      if (altSnap.exists) return alt;
      final unique2 = await _institutionsRef.where(InstitutionRegistrationSchema.uniqueInstitutionId, isEqualTo: compact).limit(1).get();
      if (unique2.docs.isNotEmpty) return unique2.docs.first.reference;
      final id2 = await _institutionsRef.where(InstitutionRegistrationSchema.id, isEqualTo: compact).limit(1).get();
      if (id2.docs.isNotEmpty) return id2.docs.first.reference;
    }
    throw Exception('Institution document $norm does not exist');
  }

  // Generate credentials from name (legacy for admin portal preview)
  GeneratedCredentials generateCredentials(String institutionName) {
    final username = institutionName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').replaceAll(' ', '_').substring(0, institutionName.length > 20 ? 20 : institutionName.length);
    final password = 'temp_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    return GeneratedCredentials(username: username, password: password);
  }

  // Reset Institution Admin password (admin action)
  Future<GeneratedCredentials> resetInstitutionAdminPassword({required String instId}) async {
    final newPass = 'op_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final ref = await _resolveInstitutionRef(instId);
    final doc = await ref.get();
    if (!doc.exists) throw Exception('Institution not found');
    final data = doc.data()!;
    final phone = data[InstitutionRegistrationSchema.phoneNumber] as String? ?? '';
    final creds = GeneratedCredentials(username: phone, password: newPass);
    await ref.update({
      InstitutionRegistrationSchema.loginCredentials: creds.toMap(),
      InstitutionRegistrationSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
    return creds;
  }

  // Delete institution (admin action) with cascading cleanup of subcollections
  Future<void> deleteInstitution({required String instId}) async {
    final norm = _normalizeInstId(instId);
    print('Deleting institution: original=$instId, normalized=$norm');
    try {
      final instDocRef = await _resolveInstitutionRef(norm);

      // 1) Delete students and their fee subcollections
      final studentsSnap = await instDocRef.collection(InstitutionRegistrationSchema.studentsSubcollection).get();
      for (final s in studentsSnap.docs) {
        try {
          final feesSnap = await s.reference.collection(FeeItemSchema.subcollectionName).get();
          for (final f in feesSnap.docs) {
            await f.reference.delete();
          }
          await s.reference.delete();
        } catch (_) {}
      }
      // 2) Delete payments
      try {
        final paymentsSnap = await instDocRef.collection(InstitutionRegistrationSchema.paymentsSubcollection).get();
        for (final p in paymentsSnap.docs) {
          await p.reference.delete();
        }
      } catch (_) {}
      // 3) Delete complaints
      try {
        final complaintsSnap = await instDocRef.collection(ComplaintSchema.collectionName).get();
        for (final c in complaintsSnap.docs) {
          await c.reference.delete();
        }
      } catch (_) {}
      // 4) Delete rooms and their beds
      try {
        final roomsSnap = await instDocRef.collection(InstitutionRegistrationSchema.roomsSubcollection).get();
        for (final r in roomsSnap.docs) {
          try {
            final bedsSnap = await r.reference.collection(BedSchema.subcollectionName).get();
            for (final b in bedsSnap.docs) {
              await b.reference.delete();
            }
          } catch (_) {}
          await r.reference.delete();
        }
      } catch (_) {}
      // 5) Finally delete the institution document
      print('Deleting main institution document: ${instDocRef.id}');
      await instDocRef.delete();
      print('Institution ${instDocRef.id} deleted successfully from Firestore');
    } catch (e) {
      print('Error during institution deletion: $e');
      throw Exception('Failed to delete institution with cascade: $e');
    }
  }
}
