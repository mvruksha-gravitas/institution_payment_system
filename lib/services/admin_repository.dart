import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRepository {
  static const String _collection = 'admin_users';
  static const String _superId = 'super';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore.collection(_collection).doc(_superId);

  Future<void> ensureDefaultAdmin() async {
    final snap = await _doc.get();
    if (!snap.exists) {
      await _doc.set({
        'username': 'mvruksha.gravitas',
        'password': 'mvruksha@90',
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<bool> validateLogin({required String username, required String password}) async {
    await ensureDefaultAdmin();
    final snap = await _doc.get();
    if (!snap.exists) return false;
    final data = snap.data()!;
    return data['username'] == username && data['password'] == password;
  }

  Future<void> changePassword({required String newPassword}) async {
    await _doc.update({'password': newPassword, 'updated_at': FieldValue.serverTimestamp()});
  }
}
