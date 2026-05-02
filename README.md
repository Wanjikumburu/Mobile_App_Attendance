# AttendX v2 — GPS + Bluetooth Student Attendance System

A Flutter + Firebase mobile application that uses GPS geofencing and Bluetooth beacons to verify physical presence before allowing attendance marking. Designed for universities and educational institutions to automate and secure student attendance tracking.

---

## 📱 Overview

AttendX v2 is a multi-role attendance system with three user types:

| Role | Capabilities |
|------|-------------|
| **Student** | Mark attendance using GPS + Bluetooth, view attendance reports, receive at-risk alerts |
| **Teacher** | Open/close attendance sessions, view live attendance, override student records, generate class reports |
| **Admin** | View institution-wide statistics, manage users, access at-risk overview, manage classes |

### Key Features
- **GPS Geofencing** — Verifies student is physically inside the classroom
- **Bluetooth Beacon** — Proximity detection to prevent remote marking
- **Device Locking** — Anti-proxy by binding attendance to registered device
- **Biometric Auth** — Fingerprint authentication for secure login
- **Real-time Tracking** — Live attendance view for teachers
- **Auto-Expiry** — Sessions automatically close after set duration
- **At-Risk Alerts** — Automatic notifications when attendance drops below 75%
- **Push Notifications** — Firebase Cloud Messaging for instant alerts

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-------------|
| **Frontend** | Flutter (Dart) |
| **Backend** | Firebase (Auth, Firestore, Functions, Messaging) |
| **GPS** | geolocator |
| **Bluetooth** | flutter_blue_plus |
| **Security** | local_auth, device_info_plus |
| **Notifications** | flutter_local_notifications |

---

## 📁 Project Structure

```
Mobile_App_Attendance/
├── lib/
│   ├── main.dart                  # App entry + role-based routing
│   ├── firebase_options.dart       # Firebase configuration
│   ├── config/
│   │   ├── app_colors.dart        # Theme colors
│   │   ├── app_routes.dart        # Navigation routes
│   │   └── app_strings.dart      # UI text strings
│   ├── models/
│   │   ├── user_model.dart       # Student/Teacher/Admin
│   │   ├── class_model.dart      # Course/class
│   │   ├── session_model.dart    # Attendance session
│   │   ├── attendance_model.dart # Attendance record
│   │   └── alert_model.dart     # At-risk alert
│   ├── services/
│   │   ├── auth_service.dart     # Register, login, biometric
│   │   ├── location_service.dart# GPS, geofence check
│   │   ├── bluetooth_service.dart# Beacon broadcast/scan
│   │   ├── session_service.dart   # Open/close sessions
│   │   ├── attendance_service.dart # Mark attendance
│   │   └── alert_service.dart  # Alert management
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── student/
│   │   │   ├── student_home.dart
│   │   │   ├── attendance_screen.dart
│   │   │   ├── student_reports.dart
│   │   │   ├── alerts_screen.dart
│   │   │   └── student_navigator.dart
│   │   ├── teacher/
│   │   │   ├── teacher_dashboard.dart
│   │   │   ├── open_session_screen.dart
│   │   │   ├── live_session_screen.dart
│   │   │   ├── teacher_reports.dart
│   │   │   └── teacher_navigator.dart
│   │   └── admin/
│   │       ├── admin_dashboard.dart
│   │       ├── user_management.dart
│   │       ├── at_risk_overview.dart
│   │       └── admin_navigator.dart
│   └── widgets/                   # Reusable widgets
├── functions/                   # Firebase Cloud Functions
│   └── index.js                 # autoCloseSessions, checkAtRisk
├── android/                     # Android build config
├── ios/                         # iOS build config
├── assets/                      # Images and icons
├── pubspec.yaml                 # Dependencies
└── firebase/
    └── firestore.rules          # Firestore security rules
```

---

## 🚀 Setup Instructions

### Prerequisites
- Flutter SDK 3.0+
- Node.js 18+ (for Cloud Functions)
- Firebase project with Auth + Firestore enabled

### 1. Install Dependencies
```bash
flutter pub get
cd functions && npm install
```

### 2. Configure Firebase
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** → Email/Password provider
3. Create **Cloud Firestore** database in test mode
4. Download `google-services.json` → place in `android/app/`
5. Download `GoogleService-Info.plist` → place in `ios/Runner/`

### 3. Set Firestore Rules
Paste the rules from `firebase/firestore.rules` into your Firestore Rules tab:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User can read/write own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    // Teachers can read all users
    match /users/{userId} {
      allow read: if request.auth != null;
    }
    // Session read for all, write for teachers
    match /sessions/{sessionId} {
      allow read: if request.auth != null;
      allow create, update: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'teacher';
    }
    // Attendance read for class members/teachers, write for class members + teachers
    match /attendance/{recordId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
    }
    // Classes read/write for admins + teachers
    match /classes/{classId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid != null;
    }
    // Alerts read/write for all
    match /alerts/{alertId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 4. Create Firestore Indexes
Go to Firestore → Indexes → Add composite indexes:

| Collection | Fields |
|------------|--------|
| attendance | userId ASC, classId ASC, timestamp DESC |
| sessions | classId ASC, status ASC |
| alerts | userId ASC, type ASC, read ASC |

### 5. Deploy Cloud Functions
```bash
cd functions
npm install -g firebase-tools
firebase login
firebase deploy --only functions
```

### 6. Run the App
```bash
flutter run
```

---

## 🎯 How It Works

### Flow 1: Student Marks Attendance
1. Student opens app → sees open sessions for enrolled classes
2. Taps "Mark Attendance" → app checks:
   - ✅ GPS: Student is within geofence (classroom location)
   - ✅ Bluetooth: Teacher's beacon is detected nearby
   - ✅ Device ID: Matches registered device
3. If all checks pass → attendance recorded as "present" or "late"

### Flow 2: Teacher Opens Session
1. Teacher logs in → sees assigned classes
2. Selects class → taps "Open Session"
3. Sets duration (e.g., 5 min) and late window (e.g., 2 min)
4. Session starts → students within geofence + beacon can mark

### Flow 3: Auto-Close & At-Risk
1. After session duration expires → Cloud Function auto-closes it
2. After each attendance record → Cloud Function checks attendance %
3. If < 75% → creates alert + sends push notification

---

## 🔐 Security Features

1. **Device Binding**
   - Each user binds their device at registration
   - Attendance only allowed on registered device
   - Prevents proxy/remote marking

2. **Geofence Verification**
   - Classroom location stored in Firestore
   - GPS must confirm student is within configurable radius (default 50m)

3. **Beacon Detection**
   - Teacher's phone broadcasts via Bluetooth
   - Student must detect beacon to mark attendance
   - RSSI threshold: -80 dBm (~10m range)

4. **Biometric Authentication**
   - Optional fingerprint login
   - Adds layer of security beyond password

---

## 📊 Firestore Data Model

### users
```
{
  name: String,
  email: String,
  role: String,         // 'student' | 'teacher' | 'admin'
  studentId: String,   // e.g. "2021-CS-045" (students only)
  department: String,
  deviceId: String,     // locked device ID
  fcmToken: String,    // push notification token
  enrolledClasses: [String], // classIds
  isActive: Boolean
}
```

### classes
```
{
  name: String,
  code: String,        // e.g. "CS-401"
  teacherId: String,
  teacherName: String,
  department: String,
  schedule: String,   // e.g. "Mon/Wed 10:00 AM"
  location: { lat: Number, lng: Number },
  radiusMeters: Number,
  enrolledStudents: [String],
  totalSessions: Number
}
```

### sessions
```
{
  classId: String,
  className: String,
  teacherId: String,
  openedAt: Timestamp,
  closedAt: Timestamp?,
  durationMinutes: Number,
  lateWindowMinutes: Number,
  status: String,      // 'open' | 'closed'
  bluetoothId: String,
  presentCount: Number,
  lateCount: Number,
  absentCount: Number
}
```

### attendance
```
{
  sessionId: String,
  classId: String,
  userId: String,
  studentId: String,
  studentName: String,
  timestamp: Timestamp,
  status: String,     // 'present' | 'late' | 'absent' | 'excused'
  location: { lat: Number, lng: Number },
  bluetoothDetected: Boolean,
  deviceId: String,
  markedBy: String    // 'self' | 'teacher'
}
```

### alerts
```
{
  userId: String,
  classId: String,
  className: String,
  type: String,       // 'at_risk' | 'session'
  title: String,
  message: String,
  read: Boolean,
  createdAt: Timestamp
}
```

---

## 🧪 Testing GPS on Emulator

1. Open Android Studio → Extended Controls (`...`) → Location
2. Set coordinates to match classroom lat/lng in Firestore
3. Run app → Mark attendance → should work
4. Change coordinates outside geofence → button should disable

---

## 📱 App Screens

### Student
- **Home** — Dashboard with today's sessions, quick actions
- **Attendance** — Mark button (enabled when inside geofence + beacon detected)
- **Reports** — Attendance percentage per class, history
- **Alerts** — At-risk warnings, session notifications

### Teacher
- **Dashboard** — List of assigned classes
- **Open Session** — Start attendance for a class
- **Live View** — Real-time list of present students
- **Reports** — Class attendance statistics

### Admin
- **Overview** — Total students, teachers, classes, active sessions
- **User Management** — View/edit all users
- **At-Risk** — Students below 75% attendance

---

## 📄 License

MIT License — See LICENSE file for details.

---

## 🙏 Acknowledgments

- [Firebase](https://firebase.google.com) — Backend services
- [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) — Bluetooth
- [geolocator](https://pub.dev/packages/geolocator) — GPS
- [Flutter](https://flutter.dev) — UI framework
