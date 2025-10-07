import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:institutation_payment_system/models/institution_models.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';

class LocalInstitutionRepository {
  static const String _pendingKey = 'pending_registrations_v1';
  static const String _institutionsKey = 'institutions_v1';

  LocalInstitutionRepository._internal();
  static final LocalInstitutionRepository _instance = LocalInstitutionRepository._internal();
  factory LocalInstitutionRepository() => _instance;

  Future<List<InstitutionRequestModel>> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingKey) ?? <String>[];
    return list.map((e) => InstitutionRequestModel.fromJson(e)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> addPending({
    required String institutionName,
    required String personName,
    required String phoneNumber,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_pendingKey) ?? <String>[];
    final now = DateTime.now();
    final request = InstitutionRequestModel(
      id: const Uuid().v4(),
      institutionName: institutionName,
      personName: personName,
      phoneNumber: phoneNumber,
      email: email,
      status: InstitutionRegistrationSchema.statusPending,
      createdAt: now,
      updatedAt: now,
      enabled: true,
    );
    existing.add(request.toJson());
    await prefs.setStringList(_pendingKey, existing);
  }

  Future<void> removePending(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_pendingKey) ?? <String>[];
    final filtered = existing.where((e) {
      final map = jsonDecode(e) as Map<String, dynamic>;
      return map['id'] != id;
    }).toList();
    await prefs.setStringList(_pendingKey, filtered);
  }

  Future<List<InstitutionModel>> getInstitutions() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_institutionsKey) ?? <String>[];
    return list.map((e) => InstitutionModel.fromJson(e)).toList()
      ..sort((a, b) => a.approvedAt.compareTo(b.approvedAt));
  }

  Future<({InstitutionModel institution, GeneratedCredentials credentials})> approvePending(String pendingId) async {
    final prefs = await SharedPreferences.getInstance();
    final pendings = prefs.getStringList(_pendingKey) ?? <String>[];
    InstitutionRequestModel? request;
    for (final e in pendings) {
      final map = jsonDecode(e) as Map<String, dynamic>;
      if (map['id'] == pendingId) {
        request = InstitutionRequestModel.fromMap(map);
        break;
      }
    }
    if (request == null) {
      throw StateError('Pending request not found');
    }

    // Generate unique institution id and credentials (INST####, random, unique within local storage)
    final existingJson = prefs.getStringList(_institutionsKey) ?? <String>[];
    final existingIds = existingJson.map((e) => InstitutionModel.fromJson(e).instId.toUpperCase()).toSet();
    final rnd = Random.secure();
    String _gen() {
      for (int i = 0; i < 100; i++) {
        final n = rnd.nextInt(10000);
        final cand = 'INST${n.toString().padLeft(4, '0')}'.toUpperCase();
        if (!existingIds.contains(cand)) return cand;
      }
      throw StateError('Unable to generate unique InstId');
    }
    final instId = _gen();
    final username = _usernameFromName(request.institutionName, request.personName);
    final password = _generateSecurePassword();

    final institution = InstitutionModel(
      instId: instId,
      institutionName: request.institutionName,
      personName: request.personName,
      phoneNumber: request.phoneNumber,
      email: request.email,
      approvedAt: DateTime.now(),
      username: username,
      hashedPassword: _hashPassword(password),
    );

    // Persist to institutions
    final institutions = prefs.getStringList(_institutionsKey) ?? <String>[];
    institutions.add(institution.toJson());
    await prefs.setStringList(_institutionsKey, institutions);

    // Remove from pending
    await removePending(pendingId);

    return (institution: institution, credentials: GeneratedCredentials(username: username, password: password));
  }

  Future<void> rejectPending(String pendingId) async => removePending(pendingId);

  String _usernameFromName(String institutionName, String personName) {
    final base = '${_slug(institutionName)}.${_slug(personName)}';
    return base.length > 22 ? base.substring(0, 22) : base;
  }

  String _slug(String input) => input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '.').replaceAll(RegExp(r'\.+'), '.').replaceAll(RegExp(r'^\.|\.$'), '');

  String _generateSecurePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#%&';
    final rnd = Random.secure();
    final length = 12;
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  String _hashPassword(String password) {
    // Simple placeholder hashing. Do NOT use in production.
    // Using base64 of reversed string to keep dependencies minimal.
    final reversed = password.split('').reversed.join();
    return base64Encode(utf8.encode(reversed));
  }
}
