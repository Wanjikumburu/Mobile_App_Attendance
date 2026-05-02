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
    try {
      User? teacher = _auth.currentUser;
      if (teacher == null) return SessionResult.notAuthorized;

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
  // GET ACTIVE SESSION FOR A CLASS
  // ────────────────────────────────────────────────────────────
  Future<SessionModel?> getActiveSession(String classId) async {
    try {
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
