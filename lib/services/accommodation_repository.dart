import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';

class FirebaseAccommodationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _normalizeInstId(String id) => id.trim().toUpperCase();

  CollectionReference<Map<String, dynamic>> _instRef() => _firestore.collection(InstitutionRegistrationSchema.collectionName);

  CollectionReference<Map<String, dynamic>> _roomsRef(String instId) => _instRef().doc(_normalizeInstId(instId)).collection(RoomSchema.collectionName);

  DocumentReference<Map<String, dynamic>> _roomDoc(String instId, String roomId) => _roomsRef(instId).doc(roomId);

  CollectionReference<Map<String, dynamic>> _bedsRef(String instId, String roomId) => _roomDoc(instId, roomId).collection(BedSchema.subcollectionName);

  DocumentReference<Map<String, dynamic>> _pricingDoc(String instId) => _instRef().doc(_normalizeInstId(instId)).collection(AccommodationPricingSchema.collectionName).doc(AccommodationPricingSchema.pricingDocId);

  Future<int> _capacityForCategory(String category) {
    switch (category) {
      case 'single':
        return Future.value(1);
      case 'two_sharing':
        return Future.value(2);
      case 'three_sharing':
        return Future.value(3);
      case 'four_sharing':
        return Future.value(4);
      default:
        // Default to two_sharing to be safe
        return Future.value(2);
    }
  }

  // Create a room with auto-generated beds matching capacity via legacy category
  Future<String> createRoom({required String instId, required String roomNumber, required String category}) async {
    final normInst = _normalizeInstId(instId);
    final capacity = await _capacityForCategory(category);

    // Enforce unique room number within institution
    final existing = await _roomsRef(normInst).where(RoomSchema.roomNumber, isEqualTo: roomNumber).limit(1).get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Room $roomNumber already exists');
    }

    final now = DateTime.now();
    final docRef = _roomsRef(normInst).doc();
    await docRef.set({
      RoomSchema.id: docRef.id,
      RoomSchema.roomNumber: roomNumber,
      RoomSchema.category: category,
      RoomSchema.capacity: capacity,
      RoomSchema.createdAt: Timestamp.fromDate(now),
      RoomSchema.updatedAt: Timestamp.fromDate(now),
    });

    // Create beds 1..capacity
    final bedsColl = _bedsRef(normInst, docRef.id);
    final batch = _firestore.batch();
    for (int i = 1; i <= capacity; i++) {
      final bedDoc = bedsColl.doc();
      batch.set(bedDoc, {
        BedSchema.id: bedDoc.id,
        BedSchema.bedNumber: i,
        BedSchema.occupied: false,
        BedSchema.studentId: null,
        BedSchema.assignedAt: null,
      });
    }
    await batch.commit();
    return docRef.id;
  }

  // Create a room with explicit bed count and optional floor number
  Future<String> createRoomCustom({required String instId, required String roomNumber, required int beds, int? floorNumber}) async {
    final normInst = _normalizeInstId(instId);
    if (beds <= 0) {
      throw Exception('Beds must be greater than zero');
    }
    // Enforce unique room number within institution
    final existing = await _roomsRef(normInst).where(RoomSchema.roomNumber, isEqualTo: roomNumber).limit(1).get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Room $roomNumber already exists');
    }
    final now = DateTime.now();
    final docRef = _roomsRef(normInst).doc();
    final Map<String, dynamic> data = {
      RoomSchema.id: docRef.id,
      RoomSchema.roomNumber: roomNumber,
      RoomSchema.capacity: beds,
      RoomSchema.createdAt: Timestamp.fromDate(now),
      RoomSchema.updatedAt: Timestamp.fromDate(now),
    };
    if (floorNumber != null) {
      data[RoomSchema.floorNumber] = floorNumber;
    }
    await docRef.set(data);

    // Create beds 1..beds
    final bedsColl = _bedsRef(normInst, docRef.id);
    final batch = _firestore.batch();
    for (int i = 1; i <= beds; i++) {
      final bedDoc = bedsColl.doc();
      batch.set(bedDoc, {
        BedSchema.id: bedDoc.id,
        BedSchema.bedNumber: i,
        BedSchema.occupied: false,
        BedSchema.studentId: null,
        BedSchema.assignedAt: null,
      });
    }
    await batch.commit();
    return docRef.id;
  }

  Future<List<Map<String, dynamic>>> listRooms({required String instId}) async {
    final snap = await _roomsRef(instId).orderBy(RoomSchema.roomNumber).get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<(int total, int occupied)> roomStats({required String instId, required String roomId}) async {
    final beds = await _bedsRef(instId, roomId).get();
    final total = beds.docs.length;
    int occ = 0;
    for (final b in beds.docs) {
      if ((b.data()[BedSchema.occupied] as bool?) == true) occ += 1;
    }
    return (total, occ);
  }

  Future<List<Map<String, dynamic>>> listBeds({required String instId, required String roomId}) async {
    final snap = await _bedsRef(instId, roomId).orderBy(BedSchema.bedNumber).get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // Pricing: fetch both with-food and without-food maps
  Future<Map<String, Map<String, num>>> getFoodPricing({required String instId}) async {
    final doc = await _pricingDoc(instId).get();
    final data = doc.data() ?? {};
    final Map<String, num> withFood = {};
    final Map<String, num> withoutFood = {};
    final wfRaw = data[AccommodationPricingSchema.withFood] as Map<String, dynamic>?;
    final woRaw = data[AccommodationPricingSchema.withoutFood] as Map<String, dynamic>?;
    if (wfRaw != null) {
      wfRaw.forEach((k, v) { final num? n = v is num ? v : num.tryParse('$v'); if (n != null) withFood[k] = n; });
    }
    if (woRaw != null) {
      woRaw.forEach((k, v) { final num? n = v is num ? v : num.tryParse('$v'); if (n != null) withoutFood[k] = n; });
    }
    return {'with': withFood, 'without': withoutFood};
  }

  Future<void> updateFoodPricing({required String instId, Map<String, num>? withFood, Map<String, num>? withoutFood}) async {
    final ref = _pricingDoc(instId);
    final Map<String, dynamic> patch = {AccommodationPricingSchema.updatedAt: Timestamp.fromDate(DateTime.now())};
    if (withFood != null) patch[AccommodationPricingSchema.withFood] = withFood;
    if (withoutFood != null) patch[AccommodationPricingSchema.withoutFood] = withoutFood;
    await ref.set(patch, SetOptions(merge: true));
  }

  // Assign next available bed in a room to a student
  Future<(String roomId, int bedNumber)> assignBedToStudent({required String instId, required String roomId, required String studentId}) async {
    final bedsSnap = await _bedsRef(instId, roomId).orderBy(BedSchema.bedNumber).get();
    DocumentSnapshot<Map<String, dynamic>>? free;
    for (final b in bedsSnap.docs) {
      final occupied = (b.data()[BedSchema.occupied] as bool?) ?? false;
      if (!occupied) { free = b; break; }
    }
    if (free == null) throw Exception('No free bed available in this room');

    // Ensure student is not already occupying a bed; if yes, release it
    await releaseBedByStudent(instId: instId, studentId: studentId);

    final now = DateTime.now();
    await free.reference.update({
      BedSchema.occupied: true,
      BedSchema.studentId: studentId,
      BedSchema.assignedAt: Timestamp.fromDate(now),
    });

    final bedNumber = (free.data()?[BedSchema.bedNumber] as int?) ?? 0;
    return (roomId, bedNumber);
  }

  // Assign by room number instead of roomId (convenience)
  Future<(String roomId, int bedNumber)> assignBedByRoomNumber({required String instId, required String roomNumber, required String studentId}) async {
    final q = await _roomsRef(instId).where(RoomSchema.roomNumber, isEqualTo: roomNumber).limit(1).get();
    if (q.docs.isEmpty) throw Exception('Room $roomNumber not found');
    final roomId = q.docs.first.id;
    return assignBedToStudent(instId: instId, roomId: roomId, studentId: studentId);
  }

  // Assign a specific bed number in a room to a student
  Future<(String roomId, int bedNumber)> assignSpecificBed({required String instId, required String roomId, required int bedNumber, required String studentId}) async {
    final q = await _bedsRef(instId, roomId).where(BedSchema.bedNumber, isEqualTo: bedNumber).limit(1).get();
    if (q.docs.isEmpty) {
      throw Exception('Bed $bedNumber not found in this room');
    }
    final bedDoc = q.docs.first;
    final occupied = (bedDoc.data()[BedSchema.occupied] as bool?) ?? false;
    if (occupied) {
      throw Exception('Bed $bedNumber is already occupied');
    }
    // Release any previously assigned bed for this student in the institution
    await releaseBedByStudent(instId: instId, studentId: studentId);
    final now = DateTime.now();
    await bedDoc.reference.update({
      BedSchema.occupied: true,
      BedSchema.studentId: studentId,
      BedSchema.assignedAt: Timestamp.fromDate(now),
    });
    return (roomId, bedNumber);
  }

  // Assign a specific bed using room number (convenience)
  Future<(String roomId, int bedNumber)> assignSpecificBedByRoomNumber({required String instId, required String roomNumber, required int bedNumber, required String studentId}) async {
    final q = await _roomsRef(instId).where(RoomSchema.roomNumber, isEqualTo: roomNumber).limit(1).get();
    if (q.docs.isEmpty) throw Exception('Room $roomNumber not found');
    final roomId = q.docs.first.id;
    return assignSpecificBed(instId: instId, roomId: roomId, bedNumber: bedNumber, studentId: studentId);
  }

  // Release the bed currently assigned to the student (if any) in this institution
  Future<void> releaseBedByStudent({required String instId, required String studentId}) async {
    final rooms = await _roomsRef(instId).get();
    for (final room in rooms.docs) {
      final beds = await _bedsRef(instId, room.id).where(BedSchema.studentId, isEqualTo: studentId).limit(1).get();
      if (beds.docs.isNotEmpty) {
        final bedDoc = beds.docs.first.reference;
        await bedDoc.update({
          BedSchema.occupied: false,
          BedSchema.studentId: null,
          BedSchema.assignedAt: null,
        });
      }
    }
  }

  // Helper to find room by room number
  Future<(String roomId, Map<String, dynamic> data)?> findRoomByNumber({required String instId, required String roomNumber}) async {
    final q = await _roomsRef(instId).where(RoomSchema.roomNumber, isEqualTo: roomNumber).limit(1).get();
    if (q.docs.isEmpty) return null;
    return (q.docs.first.id, q.docs.first.data());
  }

  // Update room number and/or sharing category. Adjust beds if capacity changes.
  Future<void> updateRoom({required String instId, required String roomId, required String newRoomNumber, String? newCategory}) async {
    final normInst = _normalizeInstId(instId);
    final roomRef = _roomDoc(normInst, roomId);
    final roomSnap = await roomRef.get();
    if (!roomSnap.exists) throw Exception('Room not found');
    final data = roomSnap.data() ?? {};
    final oldNumber = (data[RoomSchema.roomNumber] as String?) ?? '';
    final oldCategory = (data[RoomSchema.category] as String?) ?? 'two_sharing';
    final oldCapacity = (data[RoomSchema.capacity] as int?) ?? 2;
    final targetCategory = newCategory ?? oldCategory;
    final newCapacity = await _capacityForCategory(targetCategory);

    // If number changed, ensure uniqueness
    if (newRoomNumber != oldNumber) {
      final q = await _roomsRef(normInst).where(RoomSchema.roomNumber, isEqualTo: newRoomNumber).limit(1).get();
      if (q.docs.isNotEmpty && q.docs.first.id != roomId) {
        throw Exception('Room $newRoomNumber already exists');
      }
    }

    // Adjust beds for capacity change
    final bedsColl = _bedsRef(normInst, roomId);
    final bedsSnap = await bedsColl.orderBy(BedSchema.bedNumber).get();
    final currentBeds = bedsSnap.docs;
    if (newCapacity > oldCapacity) {
      // Add new empty beds with incremental numbers
      final batch = _firestore.batch();
      for (int i = oldCapacity + 1; i <= newCapacity; i++) {
        final bedDoc = bedsColl.doc();
        batch.set(bedDoc, {
          BedSchema.id: bedDoc.id,
          BedSchema.bedNumber: i,
          BedSchema.occupied: false,
          BedSchema.studentId: null,
          BedSchema.assignedAt: null,
        });
      }
      await batch.commit();
    } else if (newCapacity < oldCapacity) {
      // Ensure removable beds (highest numbers) are not occupied
      final toRemove = currentBeds.where((d) => ((d.data()[BedSchema.bedNumber] as int?) ?? 0) > newCapacity).toList()
        ..sort((a, b) => ((b.data()[BedSchema.bedNumber] as int?) ?? 0).compareTo((a.data()[BedSchema.bedNumber] as int?) ?? 0));
      for (final d in toRemove) {
        final occ = (d.data()[BedSchema.occupied] as bool?) ?? false;
        if (occ) {
          throw Exception('Cannot reduce capacity. Bed ${d.data()[BedSchema.bedNumber]} is occupied. Release it first.');
        }
      }
      final batch = _firestore.batch();
      for (final d in toRemove) { batch.delete(d.reference); }
      await batch.commit();
    }

    // Update room doc
    await roomRef.update({
      RoomSchema.roomNumber: newRoomNumber,
      RoomSchema.category: targetCategory,
      RoomSchema.capacity: newCapacity,
      RoomSchema.updatedAt: Timestamp.fromDate(DateTime.now()),
    });

    // If number changed, update denormalized room numbers on students assigned to this room
    if (newRoomNumber != oldNumber) {
      final studentsRef = _instRef().doc(normInst).collection(InstitutionRegistrationSchema.studentsSubcollection);
      final qs = await studentsRef.where(StudentSchema.roomNumber, isEqualTo: oldNumber).get();
      final batch = _firestore.batch();
      for (final s in qs.docs) {
        batch.update(s.reference, {StudentSchema.roomNumber: newRoomNumber, StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now())});
      }
      await batch.commit();
    }
  }

  // Return list of assigned students (basic info) for a room
  Future<List<Map<String, dynamic>>> listAssignedStudents({required String instId, required String roomId}) async {
    final normInst = _normalizeInstId(instId);
    final bedsSnap = await _bedsRef(normInst, roomId).where(BedSchema.studentId, isNotEqualTo: null).get();
    final List<String> studentIds = [];
    for (final b in bedsSnap.docs) {
      final sid = b.data()[BedSchema.studentId] as String?;
      if (sid != null && sid.isNotEmpty) studentIds.add(sid);
    }
    if (studentIds.isEmpty) return [];
    final studentsRef = _instRef().doc(normInst).collection(InstitutionRegistrationSchema.studentsSubcollection);
    final List<Map<String, dynamic>> out = [];
    // Firestore 'in' query supports up to 10; chunk if needed
    const int chunk = 10;
    for (int i = 0; i < studentIds.length; i += chunk) {
      final ids = studentIds.sublist(i, (i + chunk).clamp(0, studentIds.length));
      final qs = await studentsRef.where(StudentSchema.id, whereIn: ids).get();
      out.addAll(qs.docs.map((d) => d.data()));
    }
    return out;
  }

  // Delete room and cleanup student allocations
  Future<void> deleteRoomAndCleanup({required String instId, required String roomId}) async {
    final normInst = _normalizeInstId(instId);
    final roomRef = _roomDoc(normInst, roomId);
    final roomSnap = await roomRef.get();
    if (!roomSnap.exists) return;
    final roomNumber = (roomSnap.data()?[RoomSchema.roomNumber] as String?) ?? '';

    // Clear students assigned to this room
    final studentsRef = _instRef().doc(normInst).collection(InstitutionRegistrationSchema.studentsSubcollection);
    final qs = await studentsRef.where(StudentSchema.roomNumber, isEqualTo: roomNumber).get();
    final batch1 = _firestore.batch();
    for (final s in qs.docs) {
      batch1.update(s.reference, {StudentSchema.roomNumber: null, StudentSchema.bedNumber: null, StudentSchema.updatedAt: Timestamp.fromDate(DateTime.now())});
    }
    await batch1.commit();

    // Delete beds
    final bedsSnap = await _bedsRef(normInst, roomId).get();
    final batch2 = _firestore.batch();
    for (final b in bedsSnap.docs) { batch2.delete(b.reference); }
    await batch2.commit();

    // Delete room
    await roomRef.delete();
  }
}
