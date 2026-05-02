// lib/models/session_model.dart
// Data structure for a single attendance session opened by a teacher

import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String sessionId;
  final String classId;
  final String className;
  final String teacherId;
  final DateTime openedAt;
  final DateTime? closedAt;
  final int durationMinutes;      // how long session stays open
  final int lateWindowMinutes;    // extra minutes for "late" status
  final String status;            // 'open' | 'closed'
  final String bluetoothId;       // teacher's BT beacon UUID
  final int presentCount;         // auto-updated
  final int lateCount;
  final int absentCount;

  SessionModel({
    required this.sessionId,
    required this.classId,
    required this.className,
    required this.teacherId,
    required this.openedAt,
    this.closedAt          = null,
    this.durationMinutes   = 5,
    this.lateWindowMinutes = 2,
    this.status            = 'open',
    this.bluetoothId       = '',
    this.presentCount      = 0,
    this.lateCount         = 0,
    this.absentCount       = 0,
  });

  // ── Firestore → SessionModel ───────────────────────────────
  factory SessionModel.fromMap(String id, Map<String, dynamic> map) {
    return SessionModel(
      sessionId:         id,
      classId:           map['classId']           ?? '',
      className:         map['className']          ?? '',
      teacherId:         map['teacherId']          ?? '',
      openedAt:          (map['openedAt'] as Timestamp).toDate(),
      closedAt:          map['closedAt'] != null
                           ? (map['closedAt'] as Timestamp).toDate()
                           : null,
      durationMinutes:   map['durationMinutes']    ?? 5,
      lateWindowMinutes: map['lateWindowMinutes']  ?? 2,
      status:            map['status']             ?? 'closed',
      bluetoothId:       map['bluetoothId']        ?? '',
      presentCount:      map['presentCount']       ?? 0,
      lateCount:         map['lateCount']          ?? 0,
      absentCount:       map['absentCount']        ?? 0,
    );
  }

  // ── SessionModel → Firestore ───────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'classId':          classId,
      'className':        className,
      'teacherId':        teacherId,
      'openedAt':         Timestamp.fromDate(openedAt),
      'closedAt':         closedAt != null
                            ? Timestamp.fromDate(closedAt!)
                            : null,
      'durationMinutes':  durationMinutes,
      'lateWindowMinutes':lateWindowMinutes,
      'status':           status,
      'bluetoothId':      bluetoothId,
      'presentCount':     presentCount,
      'lateCount':        lateCount,
      'absentCount':      absentCount,
    };
  }

  // ── Helpers ────────────────────────────────────────────────
  bool get isOpen => status == 'open';

  // When does the session close?
  DateTime get closesAt =>
      openedAt.add(Duration(minutes: durationMinutes));

  // Minutes remaining
  int get minutesRemaining {
    final remaining = closesAt.difference(DateTime.now()).inMinutes;
    return remaining < 0 ? 0 : remaining;
  }

  // Is the current time within the late window?
  bool get isLateWindow {
    final now = DateTime.now();
    final lateDeadline =
        closesAt.add(Duration(minutes: lateWindowMinutes));
    return now.isAfter(closesAt) && now.isBefore(lateDeadline);
  }
}
