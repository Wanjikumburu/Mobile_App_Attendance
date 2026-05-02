// lib/models/attendance_model.dart
// Data structure for a single attendance record

import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String recordId;
  final String sessionId;
  final String classId;
  final String userId;
  final String studentId;         // e.g. "2021-CS-045"
  final String studentName;
  final DateTime timestamp;
  final String status;            // 'present' | 'late' | 'absent' | 'excused'
  final double locationLat;
  final double locationLng;
  final bool bluetoothDetected;
  final String deviceId;
  final String markedBy;          // 'self' | 'teacher'

  AttendanceModel({
    required this.recordId,
    required this.sessionId,
    required this.classId,
    required this.userId,
    required this.studentId,
    required this.studentName,
    required this.timestamp,
    required this.status,
    this.locationLat      = 0.0,
    this.locationLng      = 0.0,
    this.bluetoothDetected = false,
    this.deviceId         = '',
    this.markedBy         = 'self',
  });

  // ── Firestore → AttendanceModel ────────────────────────────
  factory AttendanceModel.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceModel(
      recordId:          id,
      sessionId:         map['sessionId']         ?? '',
      classId:           map['classId']           ?? '',
      userId:            map['userId']            ?? '',
      studentId:         map['studentId']         ?? '',
      studentName:       map['studentName']       ?? '',
      timestamp:         (map['timestamp'] as Timestamp).toDate(),
      status:            map['status']            ?? 'absent',
      locationLat:       (map['location']?['lat'] ?? 0.0).toDouble(),
      locationLng:       (map['location']?['lng'] ?? 0.0).toDouble(),
      bluetoothDetected: map['bluetoothDetected'] ?? false,
      deviceId:          map['deviceId']          ?? '',
      markedBy:          map['markedBy']          ?? 'self',
    );
  }

  // ── AttendanceModel → Firestore ────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'sessionId':         sessionId,
      'classId':           classId,
      'userId':            userId,
      'studentId':         studentId,
      'studentName':       studentName,
      'timestamp':         Timestamp.fromDate(timestamp),
      'status':            status,
      'location': {
        'lat': locationLat,
        'lng': locationLng,
      },
      'bluetoothDetected': bluetoothDetected,
      'deviceId':          deviceId,
      'markedBy':          markedBy,
    };
  }

  // ── Status helpers ─────────────────────────────────────────
  bool get isPresent => status == 'present';
  bool get isLate    => status == 'late';
  bool get isAbsent  => status == 'absent';
  bool get isExcused => status == 'excused';
}
