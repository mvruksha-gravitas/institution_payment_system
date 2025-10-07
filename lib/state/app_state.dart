import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class SessionUser {
  String get role; // 'institution_admin' or 'student' or 'admin'
}

class InstitutionAdminSessionUser implements SessionUser {
  final String instId;
  @override
  String get role => 'institution_admin';
  InstitutionAdminSessionUser({required this.instId});
  Map<String, dynamic> toMap() => {'role': role, 'instId': instId};
  factory InstitutionAdminSessionUser.fromMap(Map<String, dynamic> m) => InstitutionAdminSessionUser(instId: m['instId'] as String);
}

class StudentSessionUser implements SessionUser {
  final String instId;
  final String studentId;
  final String phone;
  @override
  String get role => 'student';
  StudentSessionUser({required this.instId, required this.studentId, required this.phone});
  Map<String, dynamic> toMap() => {'role': role, 'instId': instId, 'studentId': studentId, 'phone': phone};
  factory StudentSessionUser.fromMap(Map<String, dynamic> m) => StudentSessionUser(instId: m['instId'] as String, studentId: m['studentId'] as String, phone: m['phone'] as String);
}

class AdminSessionUser implements SessionUser {
  @override
  String get role => 'admin';
  const AdminSessionUser();
  Map<String, dynamic> toMap() => {'role': role};
  factory AdminSessionUser.fromMap(Map<String, dynamic> m) => const AdminSessionUser();
}

class AppState extends ChangeNotifier {
  static const _kSessionKey = 'session_user';
  SessionUser? _user;
  bool _initialized = true;
  SessionUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isInstitutionAdmin => _user?.role == 'institution_admin';
  bool get isStudent => _user?.role == 'student';
  bool get isAdmin => _user?.role == 'admin';
  bool get initialized => _initialized;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kSessionKey);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        if (map['role'] == 'institution_admin') {
          _user = InstitutionAdminSessionUser.fromMap(map);
        } else if (map['role'] == 'student') {
          _user = StudentSessionUser.fromMap(map);
        } else if (map['role'] == 'admin') {
          _user = AdminSessionUser.fromMap(map);
        }
      }
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> loginInstitutionAdmin({required String instId}) async {
    _user = InstitutionAdminSessionUser(instId: instId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionKey, jsonEncode((_user as InstitutionAdminSessionUser).toMap()));
    notifyListeners();
  }

  Future<void> loginStudent({required String instId, required String studentId, required String phone}) async {
    _user = StudentSessionUser(instId: instId, studentId: studentId, phone: phone);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionKey, jsonEncode((_user as StudentSessionUser).toMap()));
    notifyListeners();
  }

  Future<void> loginAdmin() async {
    _user = const AdminSessionUser();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionKey, '{"role":"admin"}');
    notifyListeners();
  }

  Future<void> signOut() async {
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);
    notifyListeners();
  }
}
