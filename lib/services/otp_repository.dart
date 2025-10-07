import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class OtpRepository {
  static const String _collection = 'otp_requests';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref => _firestore.collection(_collection);

  String _generate6() {
    final r = Random();
    return List.generate(6, (_) => r.nextInt(10).toString()).join();
  }

  Future<(String otp, String requestId)> requestOtp({
    required String role, // 'institution_admin' | 'student'
    required String instId,
    required String phone,
    required String email,
  }) async {
    final otp = _generate6();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 10));
    final doc = _ref.doc();
    await doc.set({
      'id': doc.id,
      'role': role,
      'inst_id': instId,
      'phone': phone,
      'email': email,
      'otp': otp,
      'expires_at': Timestamp.fromDate(expiresAt),
      'created_at': Timestamp.fromDate(now),
      'used': false,
    });
    return (otp, doc.id);
  }

  Future<bool> verifyOtp({
    required String requestId,
    required String otp,
  }) async {
    final doc = await _ref.doc(requestId).get();
    if (!doc.exists) return false;
    final d = doc.data()!;
    if (d['used'] == true) return false;
    final exp = (d['expires_at'] as Timestamp).toDate();
    if (DateTime.now().isAfter(exp)) return false;
    final ok = d['otp'] == otp;
    if (ok) {
      await _ref.doc(requestId).update({'used': true});
    }
    return ok;
  }
}
