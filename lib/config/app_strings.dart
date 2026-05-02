// lib/config/app_strings.dart
// All app text strings in one place for easy editing

class AppStrings {
  // ── App ────────────────────────────────────────────────────
  static const String appName        = 'AttendX';
  static const String appTagline     = 'GPS-Based Attendance System';
  static const String appVersion     = 'v2.0';

  // ── Auth ───────────────────────────────────────────────────
  static const String login          = 'Login';
  static const String register       = 'Create Account';
  static const String logout         = 'Logout';
  static const String email          = 'University Email';
  static const String password       = 'Password';
  static const String confirmPass    = 'Confirm Password';
  static const String fullName       = 'Full Name';
  static const String studentId      = 'Student ID';
  static const String forgotPassword = 'Forgot Password?';
  static const String biometricLogin = 'Login with Biometric';
  static const String noAccount      = "Don't have an account? ";
  static const String hasAccount     = 'Already have an account? ';
  static const String selectRole     = 'I am a...';

  // ── Roles ──────────────────────────────────────────────────
  static const String student        = 'Student';
  static const String teacher        = 'Teacher';
  static const String admin          = 'Admin';

  // ── Attendance Status ──────────────────────────────────────
  static const String present        = 'Present';
  static const String late           = 'Late';
  static const String absent         = 'Absent';
  static const String excused        = 'Excused';

  // ── Session ────────────────────────────────────────────────
  static const String openSession    = 'Open Session';
  static const String closeSession   = 'Close Session';
  static const String sessionOpen    = 'Session is Open';
  static const String sessionClosed  = 'Session Closed';
  static const String markAttendance = 'MARK ATTENDANCE';
  static const String sessionExpired = 'Session has expired';

  // ── Location ───────────────────────────────────────────────
  static const String insideClass    = '✅ You are inside the classroom';
  static const String outsideClass   = '❌ You are outside the classroom';
  static const String gpsDisabled    = '📵 GPS is turned off';
  static const String btDetected     = '📶 Beacon detected';
  static const String btNotDetected  = '📵 Beacon not detected';

  // ── Alerts ─────────────────────────────────────────────────
  static const String atRiskTitle    = 'Attendance At Risk';
  static const String atRiskMsg      = 'Your attendance has dropped below 75%';
  static const String sessionOpenMsg = 'A session has been opened for your class';

  // ── Errors ─────────────────────────────────────────────────
  static const String errorGeneric   = 'Something went wrong. Please try again.';
  static const String errorNoInternet= 'No internet connection.';
  static const String errorLocation  = 'Could not get your location.';
  static const String errorBluetooth = 'Bluetooth is not available.';
}
