// lib/models/user_model.dart
// Data structure for Student, Teacher, and Admin users

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role;           // 'student' | 'teacher' | 'admin'
  final String studentId;      // only for students e.g. "2021-CS-045"
  final String department;
  final String deviceId;       // locked device for anti-proxy
  final String fcmToken;       // for push notifications
  final List<String> enrolledClasses; // classIds student is enrolled in
  final bool isActive;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.studentId   = '',
    this.department  = '',
    this.deviceId    = '',
    this.fcmToken    = '',
    this.enrolledClasses = const [],
    this.isActive    = true,
  });

  // ── Convert Firestore document → UserModel ─────────────────
  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid:             uid,
      name:            map['name']        ?? '',
      email:           map['email']       ?? '',
      role:            map['role']        ?? 'student',
      studentId:       map['studentId']   ?? '',
      department:      map['department']  ?? '',
      deviceId:        map['deviceId']    ?? '',
      fcmToken:        map['fcmToken']    ?? '',
      enrolledClasses: List<String>.from(map['enrolledClasses'] ?? []),
      isActive:        map['isActive']    ?? true,
    );
  }

  // ── Convert UserModel → Firestore document ─────────────────
  Map<String, dynamic> toMap() {
    return {
      'name':             name,
      'email':            email,
      'role':             role,
      'studentId':        studentId,
      'department':       department,
      'deviceId':         deviceId,
      'fcmToken':         fcmToken,
      'enrolledClasses':  enrolledClasses,
      'isActive':         isActive,
    };
  }

  // ── Role helpers ───────────────────────────────────────────
  bool get isStudent => role == 'student';
  bool get isTeacher => role == 'teacher';
  bool get isAdmin   => role == 'admin';
}
