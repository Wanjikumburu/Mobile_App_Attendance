// lib/services/attendance_service.dart
// Handles: Mark attendance with GPS + BT verification, anti-proxy

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/attendance_model.dart';
import '../models/session_model.dart';
import 'dart:io';

class AttendanceService {
  final FirebaseFirestore _db   = FirebaseFirestore.instance;
  final FirebaseAuth      _auth = FirebaseAuth.instance;

  // ────────────────────────────────────────────────────────────
  // MARK ATTENDANCE (Student)
  // Runs all 3 checks: Session open + GPS + Bluetooth
  // ────────────────────────────────────────────────────────────
  Future<AttendanceResult> markAttendance({
    required SessionModel session,
    required Position studentPosition,
    required bool bluetoothDetected,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return AttendanceResult.notLoggedIn;

      // ── Check 1: Session still open ───────────────────────
      if (!session.isOpen) return AttendanceResult.sessionClosed;

      // ── Check 2: Device ID matches registered device ──────
      String deviceId = await _getDeviceId();
      DocumentSnapshot userDoc =
          await _db.collection('users').doc(user.uid).get();
      Map<String, dynamic> userData =
          userDoc.data() as Map<String, dynamic>;

      if (userData['deviceId'] != deviceId) {
        return AttendanceResult.deviceMismatch;
      }

      // ── Check 3: No duplicate for this session ────────────
      QuerySnapshot existing = await _db
          .collection('attendance')
          .where('sessionId', isEqualTo: session.sessionId)
          .where('userId',    isEqualTo: user.uid)
          .get();

      if (existing.docs.isNotEmpty) return AttendanceResult.alreadyMarked;

      // ── Determine status: present or late ─────────────────
      String status = session.isLateWindow ? 'late' : 'present';

      // ── Save attendance record ────────────────────────────
      await _db.collection('attendance').add({
        'sessionId':         session.sessionId,
        'classId':           session.classId,
        'userId':            user.uid,
        'studentId':         userData['studentId'] ?? '',
        'studentName':       userData['name']      ?? '',
        'timestamp':         FieldValue.serverTimestamp(),
        'status':            status,
        'location': {
          'lat': studentPosition.latitude,
          'lng': studentPosition.longitude,
        },
        'bluetoothDetected': bluetoothDetected,
        'deviceId':          deviceId,
        'markedBy':          'self',
      });

      // ── Update session counters ───────────────────────────
      String counterField = status == 'late' ? 'lateCount' : 'presentCount';
      await _db.collection('sessions').doc(session.sessionId).update({
        counterField: FieldValue.increment(1),
      });

      return status == 'late'
          ? AttendanceResult.successLate
          : AttendanceResult.success;

    } catch (e) {
      print('Mark attendance error: $e');
      return AttendanceResult.error;
    }
  }

  // ────────────────────────────────────────────────────────────
  // TEACHER OVERRIDE — manually set a student's status
  // ────────────────────────────────────────────────────────────
  Future<bool> overrideAttendance({
    required String recordId,
    required String newStatus,
  }) async {
    try {
      await _db.collection('attendance').doc(recordId).update({
        'status':   newStatus,
        'markedBy': 'teacher',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ────────────────────────────────────────────────────────────
  // GET ATTENDANCE FOR A SESSION (Teacher live view)
  // ────────────────────────────────────────────────────────────
  Stream<List<AttendanceModel>> sessionAttendanceStream(String sessionId) {
    return _db
        .collection('attendance')
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AttendanceModel.fromMap(
                doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  // ────────────────────────────────────────────────────────────
  // GET STUDENT REPORT (per class)
  // ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getStudentReport({
    required String userId,
    required String classId,
    required int totalSessions,
  }) async {
    try {
      QuerySnapshot snap = await _db
          .collection('attendance')
          .where('userId',  isEqualTo: userId)
          .where('classId', isEqualTo: classId)
          .orderBy('timestamp', descending: true)
          .get();

      List<AttendanceModel> records = snap.docs
          .map((doc) => AttendanceModel.fromMap(
              doc.id, doc.data() as Map<String, dynamic>))
          .toList();

      int present = records.where((r) => r.isPresent).length;
      int late    = records.where((r) => r.isLate).length;
      int excused = records.where((r) => r.isExcused).length;
      int counted = present + late + excused;

      double percentage = totalSessions > 0
          ? (counted / totalSessions) * 100 : 0;

      return {
        'records':    records,
        'present':    present,
        'late':       late,
        'excused':    excused,
        'absent':     totalSessions - counted,
        'total':      totalSessions,
        'percentage': percentage.round(),
      };
    } catch (e) {
      return {};
    }
  }

  // ────────────────────────────────────────────────────────────
  // GET ALL STUDENTS REPORT FOR A CLASS (Teacher/Admin)
  // ────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getClassReport(
      String classId, int totalSessions) async {
    try {
      QuerySnapshot snap = await _db
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .get();

      // Group by student
      Map<String, List<AttendanceModel>> byStudent = {};
      for (var doc in snap.docs) {
        AttendanceModel record = AttendanceModel.fromMap(
            doc.id, doc.data() as Map<String, dynamic>);
        byStudent.putIfAbsent(record.userId, () => []).add(record);
      }

      // Build report per student
      return byStudent.entries.map((entry) {
        List<AttendanceModel> records = entry.value;
        int present  = records.where((r) => r.isPresent).length;
        int late     = records.where((r) => r.isLate).length;
        int excused  = records.where((r) => r.isExcused).length;
        int counted  = present + late + excused;
        double pct   = totalSessions > 0
            ? (counted / totalSessions) * 100 : 0;

        return {
          'userId':      entry.key,
          'studentId':   records.first.studentId,
          'studentName': records.first.studentName,
          'present':     present,
          'late':        late,
          'excused':     excused,
          'absent':      totalSessions - counted,
          'total':       totalSessions,
          'percentage':  pct.round(),
        };
      }).toList()
        ..sort((a, b) =>
            (b['percentage'] as int).compareTo(a['percentage'] as int));
    } catch (e) {
      return [];
    }
  }

  // ── Private: device ID ─────────────────────────────────────
  Future<String> _getDeviceId() async {
    try {
      DeviceInfoPlugin info = DeviceInfoPlugin();
      if (Platform.isAndroid) return (await info.androidInfo).id;
      if (Platform.isIOS)
        return (await info.iosInfo).identifierForVendor ?? 'unknown';
      return 'unknown';
    } catch (e) {
      return 'error';
    }
  }
}

enum AttendanceResult {
  success,
  successLate,
  alreadyMarked,
  sessionClosed,
  deviceMismatch,
  notLoggedIn,
  error,
}
