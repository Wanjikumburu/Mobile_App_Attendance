// lib/services/session_service.dart
// Handles: Open session, close session, auto-expire, live updates

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/session_model.dart';

class SessionService {
  final FirebaseFirestore _db   = FirebaseFirestore.instance;
  final FirebaseAuth      _auth = FirebaseAuth.instance;

  // ────────────────────────────────────────────────────────────
  // OPEN SESSION (Teacher)
  // ────────────────────────────────────────────────────────────
  Future<SessionResult> openSession({
  required String classId,
  required String className,
  required int durationMinutes,
  int lateWindowMinutes = 2,
  String bluetoothId    = '',
}) async {
  print('🔵 openSession called for classId: $classId'); // ← ADD THIS
  try {
    User? teacher = _auth.currentUser;
    print('🔵 teacher uid: ${teacher?.uid}'); // ← ADD THIS
    if (teacher == null) return SessionResult.notAuthorized;

    await expireOldSessions();
    print('🔵 expireOldSessions done'); // ← ADD THIS

      // Check if session already open for this class
      QuerySnapshot existing = await _db
          .collection('sessions')
          .where('classId', isEqualTo: classId)
          .where('status', isEqualTo: 'open')
          .get();

      if (existing.docs.isNotEmpty) return SessionResult.alreadyOpen;

      // Create new session document
      DocumentReference ref = await _db.collection('sessions').add({
        'classId':           classId,
        'className':         className,
        'teacherId':         teacher.uid,
        'openedAt':          FieldValue.serverTimestamp(),
        'closedAt':          null,
        'durationMinutes':   durationMinutes,
        'lateWindowMinutes': lateWindowMinutes,
        'status':            'open',
        'bluetoothId':       bluetoothId,
        'presentCount':      0,
        'lateCount':         0,
        'absentCount':       0,
      });

      print('✅ Session opened: ${ref.id}');
      return SessionResult.success;
    } catch (e) {
      print('Open session error: $e');
      return SessionResult.error;
    }
  }

  // ────────────────────────────────────────────────────────────
  // CLOSE SESSION (Teacher)
  // ────────────────────────────────────────────────────────────
  Future<SessionResult> closeSession(String sessionId) async {
    try {
      await _db.collection('sessions').doc(sessionId).update({
        'status':   'closed',
        'closedAt': FieldValue.serverTimestamp(),
      });
      return SessionResult.success;
    } catch (e) {
      return SessionResult.error;
    }
  }

  // ────────────────────────────────────────────────────────────
  // AUTO-EXPIRE STALE OPEN SESSIONS
  // Called when student opens attendance screen or teacher
  // opens a new session — ensures sessions close on time
  // even if the teacher's device timer was cancelled (e.g. logout)
  // ────────────────────────────────────────────────────────────
  Future<void> expireOldSessions() async {
    try {
      QuerySnapshot snap = await _db
          .collection('sessions')
          .where('status', isEqualTo: 'open')
          .get();

      for (var doc in snap.docs) {
        final data      = doc.data() as Map<String, dynamic>;
        // openedAt may still be null if serverTimestamp hasn't resolved
        if (data['openedAt'] == null) continue;

        final openedAt  = (data['openedAt'] as Timestamp).toDate();
        final duration  = (data['durationMinutes'] ?? 5) as int;
        final late      = (data['lateWindowMinutes'] ?? 2) as int;
        final expiresAt = openedAt.add(
            Duration(minutes: duration + late)); // include late window

        if (DateTime.now().isAfter(expiresAt)) {
          await doc.reference.update({
            'status':   'closed',
            'closedAt': FieldValue.serverTimestamp(),
          });
          print('⏰ Session auto-expired: ${doc.id}');
        }
      }
    } catch (e) {
      print('expireOldSessions error: $e');
    }
  }

  // ────────────────────────────────────────────────────────────
  // GET ACTIVE SESSION FOR A CLASS
  // ────────────────────────────────────────────────────────────
  Future<SessionModel?> getActiveSession(String classId) async {
    try {
      // Always expire stale sessions before checking
      await expireOldSessions();

      QuerySnapshot snap = await _db
          .collection('sessions')
          .where('classId', isEqualTo: classId)
          .where('status',  isEqualTo: 'open')
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;

      DocumentSnapshot doc = snap.docs.first;
      return SessionModel.fromMap(
          doc.id, doc.data() as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────
  // STREAM — live updates for a session (teacher's live view)
  // ────────────────────────────────────────────────────────────
  Stream<SessionModel?> sessionStream(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      return SessionModel.fromMap(
          snap.id, snap.data() as Map<String, dynamic>);
    });
  }

  // ────────────────────────────────────────────────────────────
  // STREAM — active session for a class (student polling)
  // ────────────────────────────────────────────────────────────
  Stream<SessionModel?> activeSessionStream(String classId) {
    return _db
        .collection('sessions')
        .where('classId', isEqualTo: classId)
        .where('status',  isEqualTo: 'open')
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return SessionModel.fromMap(
          snap.docs.first.id,
          snap.docs.first.data() as Map<String, dynamic>);
    });
  }

  // ────────────────────────────────────────────────────────────
  // GET SESSION HISTORY FOR A CLASS
  // ────────────────────────────────────────────────────────────
  Future<List<SessionModel>> getSessionHistory(String classId) async {
    try {
      QuerySnapshot snap = await _db
          .collection('sessions')
          .where('classId', isEqualTo: classId)
          .orderBy('openedAt', descending: true)
          .get();

      return snap.docs.map((doc) =>
          SessionModel.fromMap(
              doc.id, doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }
}

enum SessionResult {
  success, alreadyOpen, notAuthorized, error,
}