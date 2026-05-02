// lib/config/app_colors.dart
// Central color palette for AttendX v2

import 'package:flutter/material.dart';

class AppColors {
  // ── Primary ────────────────────────────────────────────────
  static const Color primary       = Color(0xFF2E7D32); // deep green
  static const Color primaryLight  = Color(0xFF4CAF50);
  static const Color primaryDark   = Color(0xFF1B5E20);

  // ── Accent ─────────────────────────────────────────────────
  static const Color accent        = Color(0xFF00BCD4); // cyan

  // ── Attendance Status ──────────────────────────────────────
  static const Color present       = Color(0xFF4CAF50); // green
  static const Color late          = Color(0xFFFF9800); // orange
  static const Color absent        = Color(0xFFF44336); // red
  static const Color excused       = Color(0xFF2196F3); // blue

  // ── Risk Levels ────────────────────────────────────────────
  static const Color safe          = Color(0xFF4CAF50); // >= 80%
  static const Color atRisk        = Color(0xFFFF9800); // 60–79%
  static const Color critical      = Color(0xFFF44336); // < 60%

  // ── Roles ──────────────────────────────────────────────────
  static const Color studentColor  = Color(0xFF1976D2); // blue
  static const Color teacherColor  = Color(0xFF7B1FA2); // purple
  static const Color adminColor    = Color(0xFFE64A19);  // deep orange

  // ── Neutral ────────────────────────────────────────────────
  static const Color background    = Color(0xFFF5F5F5);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color textPrimary   = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider       = Color(0xFFE0E0E0);
}
