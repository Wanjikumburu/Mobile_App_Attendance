// lib/models/class_model.dart
// Data structure for a university class/course

class ClassModel {
  final String classId;
  final String name;
  final String code;              // e.g. "CS-401"
  final String teacherId;
  final String teacherName;
  final String department;
  final String schedule;          // e.g. "Mon/Wed 10:00 AM"
  final double locationLat;
  final double locationLng;
  final double radiusMeters;      // geofence radius
  final List<String> enrolledStudents;
  final int totalSessions;        // auto-incremented on session close

  ClassModel({
    required this.classId,
    required this.name,
    required this.code,
    required this.teacherId,
    this.teacherName       = '',
    this.department        = '',
    this.schedule          = '',
    this.locationLat       = 0.0,
    this.locationLng       = 0.0,
    this.radiusMeters      = 50.0,
    this.enrolledStudents  = const [],
    this.totalSessions     = 0,
  });

  // ── Firestore → ClassModel ─────────────────────────────────
  factory ClassModel.fromMap(String id, Map<String, dynamic> map) {
    return ClassModel(
      classId:          id,
      name:             map['name']            ?? '',
      code:             map['code']            ?? '',
      teacherId:        map['teacherId']       ?? '',
      teacherName:      map['teacherName']     ?? '',
      department:       map['department']      ?? '',
      schedule:         map['schedule']        ?? '',
      locationLat:      (map['location']?['lat'] ?? 0.0).toDouble(),
      locationLng:      (map['location']?['lng'] ?? 0.0).toDouble(),
      radiusMeters:     (map['radiusMeters']   ?? 50.0).toDouble(),
      enrolledStudents: List<String>.from(map['enrolledStudents'] ?? []),
      totalSessions:    map['totalSessions']   ?? 0,
    );
  }

  // ── ClassModel → Firestore ─────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'name':             name,
      'code':             code,
      'teacherId':        teacherId,
      'teacherName':      teacherName,
      'department':       department,
      'schedule':         schedule,
      'location': {
        'lat': locationLat,
        'lng': locationLng,
      },
      'radiusMeters':     radiusMeters,
      'enrolledStudents': enrolledStudents,
      'totalSessions':    totalSessions,
    };
  }
}
