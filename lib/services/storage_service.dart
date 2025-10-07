import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadPaymentProof({required String instId, required String studentId, required String feeItemId, required Uint8List data, required String fileExtension}) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'institutions/$instId/students/$studentId/fees/$feeItemId/proof_$ts.$fileExtension';
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(contentType: _mimeFromExtension(fileExtension));
    await ref.putData(data, metadata);
    return await ref.getDownloadURL();
  }

  Future<String> uploadStudentProfilePhoto({required String instId, required String studentId, required Uint8List data, required String fileExtension}) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'institutions/$instId/students/$studentId/profile/photo_$ts.$fileExtension';
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(contentType: _mimeFromExtension(fileExtension));
    await ref.putData(data, metadata);
    return await ref.getDownloadURL();
  }

  Future<String> uploadInstitutionExportText({required String instId, required Uint8List data, required String fileName, String contentType = 'text/plain'}) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeName = fileName.isNotEmpty ? fileName : 'export_$ts.txt';
    final path = 'institutions/$instId/exports/$safeName';
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(contentType: contentType);
    await ref.putData(data, metadata);
    return await ref.getDownloadURL();
  }

  Future<String> uploadSupportAttachment({required String instId, required String ticketId, required Uint8List data, required String fileExtension}) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'institutions/$instId/support/$ticketId/att_$ts.$fileExtension';
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(contentType: _mimeFromExtension(fileExtension));
    await ref.putData(data, metadata);
    return await ref.getDownloadURL();
  }

  String _mimeFromExtension(String ext) {
    final e = ext.toLowerCase();
    if (e == 'png') return 'image/png';
    if (e == 'jpg' || e == 'jpeg') return 'image/jpeg';
    if (e == 'webp') return 'image/webp';
    return 'application/octet-stream';
  }
}
