import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduserveapp/core/constants/app_config.dart';

class StudentProfile {
  const StudentProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.dept,
    required this.year,
    required this.dob,
    this.age,
    this.role = 'user',
    this.avatar,
    this.phone,
    this.registerNumber,
    this.gender,
  });

  final String uid;
  final String name;
  final String email;
  final String dept;
  final int year;
  final DateTime dob;
  final int? age;
  final String role;
  final String? avatar;
  final String? phone;
  final String? registerNumber;
  final String? gender;
}

class FirestoreUserService {
  FirestoreUserService._();

  static final FirestoreUserService instance = FirestoreUserService._();

  final CollectionReference<Map<String, dynamic>> _users =
      FirebaseFirestore.instance.collection('users');

  Future<void> createOrUpdateUser({
    required String uid,
    required String name,
    required String email,
    required String dept,
    required int year,
    required DateTime dob,
    int? age,
    String? avatar,
    String? phone,
    String? registerNumber,
    String? gender,
    String role = 'user',
  }) async {
    final resolvedRole =
        email.toLowerCase() == AppConfig.adminEmail ? 'admin' : role;

    await _users.doc(uid).set(
      <String, dynamic>{
        'name': name,
        'email': email,
        'dept': dept,
        'year': year,
        'dob': dob.toIso8601String(),
        'age': age,
        'role': resolvedRole,
        if (avatar != null) 'avatar': avatar,
        if (phone != null) 'phone': phone,
        if (registerNumber != null) 'registerNumber': registerNumber,
        if (gender != null) 'gender': gender,
        'tabUsage': <String, dynamic>{
          'home': FieldValue.increment(0),
          'eduserve': FieldValue.increment(0),
          'results': FieldValue.increment(0),
          'ai': FieldValue.increment(0),
          'fees': FieldValue.increment(0),
          'externalEvents': FieldValue.increment(0),
          'website': FieldValue.increment(0),
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<StudentProfile?> getUserById(String uid) async {
    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    final rawDob = data['dob'];
    DateTime dob = DateTime(2000, 1, 1);
    if (rawDob is Timestamp) {
      dob = rawDob.toDate();
    } else if (rawDob is String) {
      dob = DateTime.tryParse(rawDob) ?? dob;
    }

    return StudentProfile(
      uid: uid,
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      dept: (data['dept'] as String?) ?? '',
      year: (data['year'] as num?)?.toInt() ?? 1,
      dob: dob,
      age: (data['age'] as num?)?.toInt(),
      role: (data['role'] as String?) ?? 'user',
      avatar: data['avatar'] as String?,
      phone: data['phone'] as String?,
      registerNumber: data['registerNumber'] as String?,
      gender: data['gender'] as String?,
    );
  }
}
