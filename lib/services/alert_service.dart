// lib/services/alert_service.dart
// Handles: Create alerts, fetch alerts, mark as read

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/alert_model.dart';

class AlertService {
  final FirebaseFirestore _db   = FirebaseFirestore.instance;
  final FirebaseAuth      _auth = FirebaseAuth.instance;

  // ────────────────────────────────────────────────────────────
  // CREATE AT-RISK ALERT
  // Called by Cloud Function or manually when % drops below 75
  // ────────────────────────────────────────────────────────────
  Future<void> createAtRiskAlert({
    required String userId,
    required String classId,
    required String className,
    required int percentage,
  }) async {
    try {
      // Avoid duplicate alerts — check if one already exists unread
      QuerySnapshot existing = await _db
          .collection('alerts')
          .where('userId',  isEqualTo: userId)
          .where('classId', isEqualTo: classId)
          .where('type',    isEqualTo: 'at_risk')
          .where('read',    isEqualTo: false)
          .get();

      if (existing.docs.isNotEmpty) return; // already notified

      await _db.collection('alerts').add({
        'userId':    userId,
        'classId':   classId,
        'className': className,
        'type':      'at_risk',
        'title':     'Attendance At Risk ⚠️',
        'message':   'Your attendance in $className is $percentage%. '
                     'Minimum required is 75%.',
        'read':      false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Create alert error: $e');
    }
  }

  // ────────────────────────────────────────────────────────────
  // CREATE SESSION OPEN ALERT (notify enrolled students)
  // ────────────────────────────────────────────────────────────
  Future<void> createSessionAlert({
    required List<String> studentIds,
    required String classId,
    required String className,
    required int durationMinutes,
  }) async {
    try {
      WriteBatch batch = _db.batch();

      for (String userId in studentIds) {
        DocumentReference ref = _db.collection('alerts').doc();
        batch.set(ref, {
          'userId':    userId,
          'classId':   classId,
          'className': className,
          'type':      'session_open',
          'title':     'Session Open 📢',
          'message':   '$className attendance is open for $durationMinutes minutes!',
          'read':      false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Session alert error: $e');
    }
  }

  // ────────────────────────────────────────────────────────────
  // GET ALERTS FOR CURRENT USER (stream)
  // ────────────────────────────────────────────────────────────
  Stream<List<AlertModel>> getAlertsStream() {
    User? user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('alerts')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AlertModel.fromMap(
                doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  // ────────────────────────────────────────────────────────────
  // COUNT UNREAD ALERTS (for badge)
  // ────────────────────────────────────────────────────────────
  Stream<int> unreadCountStream() {
    User? user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _db
        .collection('alerts')
        .where('userId', isEqualTo: user.uid)
        .where('read',   isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ────────────────────────────────────────────────────────────
  // MARK ALERT AS READ
  // ────────────────────────────────────────────────────────────
  Future<void> markAsRead(String alertId) async {
    try {
      await _db.collection('alerts').doc(alertId).update({'read': true});
    } catch (e) {
      print('Mark read error: $e');
    }
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      QuerySnapshot snap = await _db
          .collection('alerts')
          .where('userId', isEqualTo: user.uid)
          .where('read',   isEqualTo: false)
          .get();

      WriteBatch batch = _db.batch();
      for (var doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      print('Mark all read error: $e');
    }
  }

  // ────────────────────────────────────────────────────────────
  // CHECK AND TRIGGER AT-RISK ALERTS
  // Call this after each session closes
  // ────────────────────────────────────────────────────────────
  Future<void> checkAndTriggerAtRiskAlerts({
    required String classId,
    required String className,
    required List<Map<String, dynamic>> studentReports,
  }) async {
    for (var report in studentReports) {
      int percentage = report['percentage'] as int;
      if (percentage < 75) {
        await createAtRiskAlert(
          userId:     report['userId'],
          classId:    classId,
          className:  className,
          percentage: percentage,
        );
      }
    }
  }
}
