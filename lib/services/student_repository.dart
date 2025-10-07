import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';
import 'package:institutation_payment_system/models/institution_models.dart';
import 'package:institutation_payment_system/services/accommodation_repository.dart';

class FirebaseStudentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _instRef() => _firestore.collection(InstitutionRegistrationSchema.collectionName);

  String _normalizeInstId(String id) => id.trim().toUpperCase();

  // Validate that the institution exists and is enabled
  Future<bool> validateInstId(String instId) async {
    final doc = await _instRef().doc(_normalizeInstId(instId)).get();
    if (!doc.exists) return false;
    final enabled = (doc.data()?[InstitutionRegistrationSchema.enabled] as bool?) ?? true;
    return enabled;
  }

  // Find a student by phone within an institution (for duplicate detection & reset)
  Future<Map<String, dynamic>?> findStudentByPhone({required String instId, required String phone}) async {
    final q = await _instRef()
        .doc(_normalizeInstId(instId))
        .collection(InstitutionRegistrationSchema.studentsSubcollection)
        .where(StudentSchema.phoneNumber, isEqualTo: phone)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.data();
  }

  // List all memberships for a phone across institutions (approved and enabled only)
  // Returns a list of tuples: (instId, studentId, data)
  Future<List<(String instId, String studentId, Map<String, dynamic> data)>> listMembershipsByPhone({required String phone}) async {
    final List<(String, String, Map<String, dynamic>)> out = [];
    try {
      final q = await _firestore
          .collectionGroup(InstitutionRegistrationSchema.studentsSubcollection)
          .where(StudentSchema.phoneNumber, isEqualTo: phone)
          .limit(50)
          .get();
      for (final doc in q.docs) {
        final data = doc.data();
        if ((data[StudentSchema.enabled] as bool?) == false) continue;
        if (data[StudentSchema.status] != StudentSchema.statusApproved) continue;
        final instId = doc.reference.parent.parent?.id;
        if (instId == null) continue;
        out.add((instId, doc.id, data));
      }
      return out;
    } catch (e) {
      // Fallback: manually search through institutions
      return await _fallbackMembershipSearch(phone);
    }
  }

  // Fallback method when collection group query fails due to missing index
  Future<List<(String instId, String studentId, Map<String, dynamic> data)>> _fallbackMembershipSearch(String phone) async {
    final List<(String, String, Map<String, dynamic>)> out = [];
    try {
      final instQuery = await _instRef()
          .where(InstitutionRegistrationSchema.status, isEqualTo: InstitutionRegistrationSchema.statusApproved)
          .get();
      for (final instDoc in instQuery.docs) {
        final instId = instDoc.id;
        try {
          final studentQuery = await _instRef()
              .doc(instId)
              .collection(InstitutionRegistrationSchema.studentsSubcollection)
              .where(StudentSchema.phoneNumber, isEqualTo: phone)
              .get();
          for (final studentDoc in studentQuery.docs) {
            final data = studentDoc.data();
            if ((data[StudentSchema.enabled] as bool?) == false) continue;
            if (data[StudentSchema.status] != StudentSchema.statusApproved) continue;
            out.add((instId, studentDoc.id, data));
          }
        } catch (_) {}
      }
    } catch (_) {}
    return out;
  }

  // Check if a phone exists as a student in ANY institution (any status)
  Future<bool> existsAnyStudentByPhoneGlobal(String phone) async {
    try {
      final q = await _firestore
          .collectionGroup(InstitutionRegistrationSchema.studentsSubcollection)
          .where(StudentSchema.phoneNumber, isEqualTo: phone)
          .limit(1)
          .get();
      return q.docs.isNotEmpty;
    } catch (_) {
      // Fallback: scan all institutions
      try {
        final instQuery = await _instRef().get();
        for (final instDoc in instQuery.docs) {
          final q = await _instRef()
              .doc(instDoc.id)
              .collection(InstitutionRegistrationSchema.studentsSubcollection)
              .where(StudentSchema.phoneNumber, isEqualTo: phone)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) return true;
        }
      } catch (_) {}
      return false;
    }
  }

  // Check if a phone exists as a student in ANY OTHER institution (excludeInstId)
  Future<bool> existsStudentPhoneInOtherInstitution({required String phone, required String excludeInstId}) async {
    final exclude = _normalizeInstId(excludeInstId);
    try {
      final q = await _firestore
          .collectionGroup(InstitutionRegistrationSchema.studentsSubcollection)
          .where(StudentSchema.phoneNumber, isEqualTo: phone)
          .limit(20)
          .get();
      for (final d in q.docs) {
        final inst = (d.reference.parent.parent?.id ?? '').toUpperCase();
        if (inst != exclude) return true;
      }
      return false;
    } catch (_) {
      // Fallback: scan all institutions
      try {
        final instQuery = await _instRef().get();
        for (final instDoc in instQuery.docs) {
          final inst = instDoc.id.toUpperCase();
          if (inst == exclude) continue;
          final q = await _instRef()
              .doc(instDoc.id)
              .collection(InstitutionRegistrationSchema.studentsSubcollection)
              .where(StudentSchema.phoneNumber, isEqualTo: phone)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) return true;
        }
      } catch (_) {}
      return false;
    }
  }

  // Submit student registration (status: pending)
  Future<String> submitStudentRegistration({
    required String instId,
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String aadhaar,
    String? photoUrl,
    required String parentName,
    required String parentPhone,
    required String address,
    required String occupation,
    required String collegeCourseClass,
    required bool termsAccepted,
  }) async {
    final instDoc = await _instRef().doc(_normalizeInstId(instId)).get();
    if (!instDoc.exists) {
      throw Exception('Invalid InstId');
    }
    if ((instDoc.data()?[InstitutionRegistrationSchema.enabled] as bool?) == false) {
      throw Exception('Institution is disabled');
    }

    // Check duplicate phone for same institution
    final dupe = await _instRef()
        .doc(_normalizeInstId(instId))
        .collection(InstitutionRegistrationSchema.studentsSubcollection)
        .where(StudentSchema.phoneNumber, isEqualTo: phone)
        .limit(1)
        .get();
    if (dupe.docs.isNotEmpty) {
      throw Exception('Phone number already registered');
    }

    // Cross-collection uniqueness enforcement:
    // 1) The phone must not be used by another Institution Admin.
    final adminQ = await _instRef().where(InstitutionRegistrationSchema.phoneNumber, isEqualTo: phone).limit(1).get();
    if (adminQ.docs.isNotEmpty) {
      throw Exception('This phone number is already registered as an Institution Admin');
    }
    // 2) Cross-institution phone uniqueness check temporarily disabled
    // This requires Firestore indexes to be deployed first
    // TODO: Re-enable after deploying firestore.indexes.json to Firebase Console

    final now = DateTime.now();
    final ref = _instRef().doc(_normalizeInstId(instId)).collection(InstitutionRegistrationSchema.studentsSubcollection).doc();
    await ref.set({
      StudentSchema.id: ref.id,
      StudentSchema.instId: instId,
      StudentSchema.firstName: firstName,
      StudentSchema.lastName: lastName,
      StudentSchema.phoneNumber: phone,
      StudentSchema.email: email,
      StudentSchema.aadhaar: aadhaar,
      StudentSchema.photoUrl: photoUrl,
      StudentSchema.parentName: parentName,
      StudentSchema.parentPhone: parentPhone,
      StudentSchema.address: address,
      StudentSchema.occupation: occupation,
      StudentSchema.collegeCourseClass: collegeCourseClass,
      StudentSchema.termsAccepted: termsAccepted,
      StudentSchema.status: StudentSchema.statusPending,
      StudentSchema.enabled: true,
      StudentSchema.loginCredentials: null, // set on approval
      StudentSchema.feeAmount: 0,
      StudentSchema.feeType: StudentSchema.feeTypeRecurring,
      StudentSchema.feeDueDate: null,
      StudentSchema.roomNumber: null,
      StudentSchema.createdAt: Timestamp.fromDate(now),
      StudentSchema.updatedAt: Timestamp.fromDate(now),
    });
    return ref.id;
  }

  // Approve student (institution_admin action): sets status approved and username=phone. Password must be set manually by institution_admin.
  Future<void> approveStudent({required String instId, required String studentId}) async {
    final studentDocRef = _instRef().doc(_normalizeInstId(instId)).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId);
    final snapshot = await studentDocRef.get();
    if (!snapshot.exists) throw Exception('Student not found');
    final data = snapshot.data()!;
    final phone = data[StudentSchema.phoneNumber] as String;
    await studentDocRef.update({
      StudentSchema.status: StudentSchema.statusApproved,
      // Initialize login_credentials with username only; password to be set by institution_admin manually
      StudentSchema.loginCredentials: const GeneratedCredentials(username: '', password: '').toMap()
        ..update('username', (_) => phone, ifAbsent: () => phone),
      StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> setStudentEnabled({required String instId, required String studentId, required bool enabled, String? reason}) async {
    final now = DateTime.now();
    // If disabling, release any assigned bed
    if (!enabled) {
      try {
        // ignore: avoid_dynamic_calls
        await FirebaseAccommodationRepository().releaseBedByStudent(instId: _normalizeInstId(instId), studentId: studentId);
        // Clear room and bed on student document as well
        await _instRef()
            .doc(_normalizeInstId(instId))
            .collection(InstitutionRegistrationSchema.studentsSubcollection)
            .doc(studentId)
            .update({
          StudentSchema.roomNumber: null,
          StudentSchema.bedNumber: null,
        });
      } catch (_) {
        // best-effort release
      }
    }
    final payload = <String, dynamic>{
      StudentSchema.enabled: enabled,
      StudentSchema.status: enabled ? StudentSchema.statusApproved : StudentSchema.statusDisabled,
      StudentSchema.updatedAt: Timestamp.fromDate(now),
    };
    if (!enabled) {
      payload[StudentSchema.disabledReason] = reason ?? 'Disabled by admin';
      payload[StudentSchema.disabledAt] = Timestamp.fromDate(now);
    } else {
      payload[StudentSchema.reenabledAt] = Timestamp.fromDate(now);
    }
    await _instRef().doc(_normalizeInstId(instId)).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId).update(payload);
  }

  Future<void> setStudentFee({required String instId, required String studentId, required num amount, required String feeType, required DateTime? dueDate}) async {
    await _instRef().doc(_normalizeInstId(instId)).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId).update({
      StudentSchema.feeAmount: amount,
      StudentSchema.feeType: feeType,
      StudentSchema.feeDueDate: dueDate != null ? Timestamp.fromDate(dueDate) : null,
      StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> assignRoom({required String instId, required String studentId, required String? roomNumber}) async {
    await _instRef().doc(_normalizeInstId(instId)).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId).update({
      StudentSchema.roomNumber: roomNumber,
      StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<List<Map<String, dynamic>>> listStudents({required String instId, String? roomFilter}) async {
    Query<Map<String, dynamic>> q = _instRef().doc(_normalizeInstId(instId)).collection(InstitutionRegistrationSchema.studentsSubcollection);
    if (roomFilter != null && roomFilter.isNotEmpty) {
      q = q.where(StudentSchema.roomNumber, isEqualTo: roomFilter);
    }
    final snap = await q.orderBy(StudentSchema.createdAt, descending: true).get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<int> countStudents({required String instId}) async {
    final q = _instRef().doc(_normalizeInstId(instId)).collection(InstitutionRegistrationSchema.studentsSubcollection).count();
    final agg = await q.get();
    return agg.count ?? 0;
  }

  // Student-side profile updates
  Future<void> updateStudentContact({required String instId, required String studentId, required String phone, required String email}) async {
    await _instRef().doc(_normalizeInstId(instId)).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId).update({
      StudentSchema.phoneNumber: phone,
      StudentSchema.email: email,
      StudentSchema.loginCredentials: const GeneratedCredentials(username: '', password: '').toMap()
        ..update('username', (_) => phone, ifAbsent: () => phone),
      StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> updateStudentProfile({required String instId, required String studentId, required Map<String, dynamic> data}) async {
    final payload = Map<String, dynamic>.from(data);
    payload[StudentSchema.updatedAt] = Timestamp.fromDate(DateTime.now());
    await _instRef().doc(_normalizeInstId(instId)).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId).update(payload);
  }

  Future<void> setStudentPhotoUrl({required String instId, required String studentId, required String photoUrl}) async {
    await _instRef().doc(_normalizeInstId(instId)).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId).update({
      StudentSchema.photoUrl: photoUrl,
      StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> resetStudentPassword({required String instId, required String studentId}) async {
    final newPass = 'sp_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    await _instRef().doc(_normalizeInstId(instId)).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId).update({
      StudentSchema.loginCredentials: const GeneratedCredentials(username: '', password: '').toMap()
        ..update('password', (_) => newPass, ifAbsent: () => newPass),
      StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
  }

  // Update student password explicitly (OTP flow)
  Future<void> setStudentPasswordById({required String instId, required String studentId, required String newPassword}) async {
    final studentDocRef = _instRef().doc(_normalizeInstId(instId)).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId);
    final snapshot = await studentDocRef.get();
    if (!snapshot.exists) throw Exception('Student not found');
    final data = snapshot.data()!;
    final phone = data[StudentSchema.phoneNumber] as String;
    await studentDocRef.update({
      StudentSchema.loginCredentials: {
        'username': phone,
        'password': newPassword,
      },
      StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
  }

  // Manually set student password from institution_admin portal
  Future<void> setStudentPassword({required String instId, required String studentId, required String password}) async {
    final studentDocRef = _instRef().doc(_normalizeInstId(instId)).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId);
    final snapshot = await studentDocRef.get();
    if (!snapshot.exists) throw Exception('Student not found');
    final data = snapshot.data()!;
    final phone = data[StudentSchema.phoneNumber] as String;
    await studentDocRef.update({
      StudentSchema.loginCredentials: {
        'username': phone,
        'password': password,
      },
      StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });
  }

  // Validate student login using InstId + phone + password
  Future<(bool ok, String? studentId)> validateStudentLogin({required String instId, required String phone, required String password}) async {
    final q = await _instRef()
        .doc(_normalizeInstId(instId))
        .collection(InstitutionRegistrationSchema.studentsSubcollection)
        .where(StudentSchema.phoneNumber, isEqualTo: phone)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return (false, null);
    final d = q.docs.first.data();
    if ((d[StudentSchema.enabled] as bool?) == false) return (false, null);
    if (d[StudentSchema.status] != StudentSchema.statusApproved) return (false, null);
    final creds = d[StudentSchema.loginCredentials] as Map<String, dynamic>?;
    if (creds == null) return (false, null);
    final ok = (creds['username'] == phone) && (creds['password'] == password);
    return (ok, q.docs.first.id);
  }

  // New: Validate student login using phone + password only, without InstId
  // Returns (ok, instId, studentId) if successful. Uses collectionGroup for performance.
  Future<(bool ok, String? instId, String? studentId)> validateStudentLoginByPhone({required String phone, required String password}) async {
    final q = await _firestore
        .collectionGroup(InstitutionRegistrationSchema.studentsSubcollection)
        .where(StudentSchema.phoneNumber, isEqualTo: phone)
        .limit(5)
        .get();
    for (final doc in q.docs) {
      final data = doc.data();
      if ((data[StudentSchema.enabled] as bool?) == false) continue;
      if (data[StudentSchema.status] != StudentSchema.statusApproved) continue;
      final creds = data[StudentSchema.loginCredentials] as Map<String, dynamic>?;
      if (creds == null) continue;
      final ok = (creds['username'] == phone) && (creds['password'] == password);
      if (ok) {
        final instId = doc.reference.parent.parent?.id;
        return (true, instId, doc.id);
      }
    }
    return (false, null, null);
  }

  // Find a student globally by phone across all institutions (for password reset)
  // Returns (instId, studentId, data) if found and approved. Uses collectionGroup for performance.
  Future<(String? instId, String? studentId, Map<String, dynamic>? data)> findStudentGlobalByPhone({required String phone}) async {
    try {
      final q = await _firestore
          .collectionGroup(InstitutionRegistrationSchema.studentsSubcollection)
          .where(StudentSchema.phoneNumber, isEqualTo: phone)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return (null, null, null);
      final doc = q.docs.first;
      final data = doc.data();
      if ((data[StudentSchema.enabled] as bool?) == false) return (null, null, null);
      if (data[StudentSchema.status] != StudentSchema.statusApproved) return (null, null, null);
      final instId = doc.reference.parent.parent?.id;
      return (instId, doc.id, data);
    } catch (e) {
      // Fallback to manual search
      final memberships = await _fallbackMembershipSearch(phone);
      if (memberships.isNotEmpty) {
        final first = memberships.first;
        return (first.$1, first.$2, first.$3);
      }
      return (null, null, null);
    }
  }
}
