import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class InstitutionRequestModel {
  final String id; // Firestore document ID
  final String institutionName;
  final String personName;
  final String phoneNumber;
  final String email;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? adminNotes;
  final String? uniqueInstitutionId;
  final GeneratedCredentials? loginCredentials;
  final bool enabled;

  InstitutionRequestModel({
    required this.id,
    required this.institutionName,
    required this.personName,
    required this.phoneNumber,
    required this.email,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    this.rejectedAt,
    this.adminNotes,
    this.uniqueInstitutionId,
    this.loginCredentials,
    required this.enabled,
  });

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'institution_name': institutionName,
        'person_name': personName,
        'phone_number': phoneNumber,
        'email': email,
        'status': status,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
        'approved_at': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
        'rejected_at': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
        'admin_notes': adminNotes,
        'unique_institution_id': uniqueInstitutionId,
        'login_credentials': loginCredentials?.toMap(),
        'enabled': enabled,
      };

  factory InstitutionRequestModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return InstitutionRequestModel(
      id: doc.id,
      institutionName: data['institution_name'] as String,
      personName: data['person_name'] as String? ?? '',
      phoneNumber: data['phone_number'] as String,
      email: data['email'] as String,
      status: data['status'] as String,
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
      approvedAt: data['approved_at'] != null ? (data['approved_at'] as Timestamp).toDate() : null,
      rejectedAt: data['rejected_at'] != null ? (data['rejected_at'] as Timestamp).toDate() : null,
      adminNotes: data['admin_notes'] as String?,
      uniqueInstitutionId: data['unique_institution_id'] as String?,
      loginCredentials: data['login_credentials'] != null 
          ? GeneratedCredentials.fromMap(data['login_credentials'] as Map<String, dynamic>)
          : null,
      enabled: data['enabled'] as bool? ?? true,
    );
  }

  // Keep legacy methods for backward compatibility
  Map<String, dynamic> toMap() => {
        'id': id,
        'institutionName': institutionName,
        'personName': personName,
        'phoneNumber': phoneNumber,
        'email': email,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  factory InstitutionRequestModel.fromMap(Map<String, dynamic> map) => InstitutionRequestModel(
        id: map['id'] as String,
        institutionName: map['institutionName'] as String,
        personName: map['personName'] as String,
        phoneNumber: map['phoneNumber'] as String,
        email: map['email'] as String,
        status: map['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String? ?? map['createdAt'] as String),
        enabled: map['enabled'] as bool? ?? true,
      );

  String toJson() => jsonEncode(toMap());
  factory InstitutionRequestModel.fromJson(String source) => InstitutionRequestModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

class InstitutionModel {
  final String instId; // unique institution id generated on approval
  final String institutionName;
  final String personName;
  final String phoneNumber;
  final String email;
  final DateTime approvedAt;
  final String username;
  final String hashedPassword; // placeholder for demo

  InstitutionModel({
    required this.instId,
    required this.institutionName,
    required this.personName,
    required this.phoneNumber,
    required this.email,
    required this.approvedAt,
    required this.username,
    required this.hashedPassword,
  });

  Map<String, dynamic> toMap() => {
        'instId': instId,
        'institutionName': institutionName,
        'personName': personName,
        'phoneNumber': phoneNumber,
        'email': email,
        'approvedAt': approvedAt.toIso8601String(),
        'username': username,
        'hashedPassword': hashedPassword,
      };

  factory InstitutionModel.fromMap(Map<String, dynamic> map) => InstitutionModel(
        instId: map['instId'] as String,
        institutionName: map['institutionName'] as String,
        personName: map['personName'] as String,
        phoneNumber: map['phoneNumber'] as String,
        email: map['email'] as String,
        approvedAt: DateTime.parse(map['approvedAt'] as String),
        username: map['username'] as String,
        hashedPassword: map['hashedPassword'] as String,
      );

  String toJson() => jsonEncode(toMap());
  factory InstitutionModel.fromJson(String source) => InstitutionModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

class StudentModel {
  final String id;
  final String instId;
  final String name;
  final String phoneNumber;
  final String email;
  final DateTime createdAt;

  StudentModel({required this.id, required this.instId, required this.name, required this.phoneNumber, required this.email, required this.createdAt});

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'inst_id': instId,
        'name': name,
        'phone_number': phoneNumber,
        'email': email,
        'created_at': Timestamp.fromDate(createdAt),
      };

  factory StudentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return StudentModel(
      id: doc.id,
      instId: d['inst_id'] as String,
      name: d['name'] as String,
      phoneNumber: d['phone_number'] as String,
      email: d['email'] as String,
      createdAt: (d['created_at'] as Timestamp).toDate(),
    );
  }
}

class GeneratedCredentials {
  final String username;
  final String password;
  const GeneratedCredentials({required this.username, required this.password});

  Map<String, dynamic> toMap() => {
        'username': username,
        'password': password,
      };

  factory GeneratedCredentials.fromMap(Map<String, dynamic> map) => GeneratedCredentials(
        username: map['username'] as String,
        password: map['password'] as String,
      );
}
