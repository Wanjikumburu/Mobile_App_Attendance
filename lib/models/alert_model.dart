// lib/models/alert_model.dart
// Data structure for at-risk and session alerts

import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String alertId;
  final String userId;
  final String classId;
  final String className;
  final String type;        // 'at_risk' | 'session_open' | 'absent'
  final String title;
  final String message;
  final bool read;
  final DateTime createdAt;

  AlertModel({
    required this.alertId,
    required this.userId,
    required this.classId,
    required this.className,
    required this.type,
    required this.title,
    required this.message,
    this.read      = false,
    required this.createdAt,
  });

  // ── Firestore → AlertModel ─────────────────────────────────
  factory AlertModel.fromMap(String id, Map<String, dynamic> map) {
    return AlertModel(
      alertId:   id,
      userId:    map['userId']    ?? '',
      classId:   map['classId']   ?? '',
      className: map['className'] ?? '',
      type:      map['type']      ?? '',
      title:     map['title']     ?? '',
      message:   map['message']   ?? '',
      read:      map['read']      ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  // ── AlertModel → Firestore ─────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'userId':    userId,
      'classId':   classId,
      'className': className,
      'type':      type,
      'title':     title,
      'message':   message,
      'read':      read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
