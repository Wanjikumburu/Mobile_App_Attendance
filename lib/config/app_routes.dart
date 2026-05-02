// lib/config/app_routes.dart
// Named route definitions for the entire app

class AppRoutes {
  // ── Auth ───────────────────────────────────────────────────
  static const String login           = '/login';
  static const String register        = '/register';

  // ── Student ────────────────────────────────────────────────
  static const String studentHome     = '/student/home';
  static const String attendance      = '/student/attendance';
  static const String studentReports  = '/student/reports';
  static const String alerts          = '/student/alerts';

  // ── Teacher ────────────────────────────────────────────────
  static const String teacherDashboard = '/teacher/dashboard';
  static const String openSession      = '/teacher/open-session';
  static const String liveSession      = '/teacher/live-session';
  static const String teacherReports   = '/teacher/reports';

  // ── Admin ──────────────────────────────────────────────────
  static const String adminDashboard  = '/admin/dashboard';
  static const String userManagement  = '/admin/users';
  static const String atRiskOverview  = '/admin/at-risk';
}
