// lib/services/auth_service.dart
// Handles: Register, Login, Biometric, Logout, Role check, Device ID

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/user_model.dart';
import 'dart:io';

class AuthService {
  final FirebaseAuth      _auth      = FirebaseAuth.instance;
  final FirebaseFirestore _db        = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  // ── Current user ───────────────────────────────────────────
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ────────────────────────────────────────────────────────────
  // REGISTER
  // ────────────────────────────────────────────────────────────
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String studentId  = '',
    String department = '',
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password,
      );
      String deviceId = await _getDeviceId();

      UserModel user = UserModel(
        uid:        cred.user!.uid,
        name:       name,
        email:      email,
        role:       role,
        studentId:  studentId,
        department: department,
        deviceId:   deviceId,
      );

      await _db.collection('users')
               .doc(cred.user!.uid)
               .set(user.toMap());

      return AuthResult.success;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') return AuthResult.emailInUse;
      if (e.code == 'weak-password')        return AuthResult.weakPassword;
      return AuthResult.error;
    }
  }

  // ────────────────────────────────────────────────────────────
  // LOGIN
  // ────────────────────────────────────────────────────────────
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email, password: password,
      );
      return AuthResult.success;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found')    return AuthResult.userNotFound;
      if (e.code == 'wrong-password')    return AuthResult.wrongPassword;
      if (e.code == 'invalid-credential')return AuthResult.wrongPassword;
      return AuthResult.error;
    }
  }

  // ────────────────────────────────────────────────────────────
  // BIOMETRIC LOGIN
  // ────────────────────────────────────────────────────────────
  Future<BiometricResult> loginWithBiometric() async {
    try {
      bool canCheck   = await _localAuth.canCheckBiometrics;
      bool isSupported= await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) return BiometricResult.notSupported;

      List<BiometricType> available =
          await _localAuth.getAvailableBiometrics();
      if (available.isEmpty) return BiometricResult.notEnrolled;

      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint to mark attendance',
        options: const AuthenticationOptions(
          biometricOnly: true, stickyAuth: true,
        ),
      );
      return authenticated ? BiometricResult.success : BiometricResult.failed;
    } catch (e) {
      return BiometricResult.failed;
    }
  }

  // ────────────────────────────────────────────────────────────
  // GET USER PROFILE + ROLE
  // ────────────────────────────────────────────────────────────
  Future<UserModel?> getUserProfile() async {
    try {
      User? user = currentUser;
      if (user == null) return null;
      DocumentSnapshot doc =
          await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(user.uid, doc.data() as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // Get role string quickly
  Future<String?> getUserRole() async {
    UserModel? user = await getUserProfile();
    return user?.role;
  }

  // ────────────────────────────────────────────────────────────
  // UPDATE FCM TOKEN (for push notifications)
  // ────────────────────────────────────────────────────────────
  Future<void> updateFcmToken(String token) async {
    User? user = currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({
      'fcmToken': token,
    });
  }

  // ────────────────────────────────────────────────────────────
  // PASSWORD RESET
  // ────────────────────────────────────────────────────────────
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ────────────────────────────────────────────────────────────
  // LOGOUT
  // ────────────────────────────────────────────────────────────
  Future<void> logout() async => await _auth.signOut();

  // ────────────────────────────────────────────────────────────
  // PRIVATE — Device ID
  // ────────────────────────────────────────────────────────────
  Future<String> _getDeviceId() async {
    try {
      DeviceInfoPlugin info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        return (await info.androidInfo).id;
      } else if (Platform.isIOS) {
        return (await info.iosInfo).identifierForVendor ?? 'unknown-ios';
      }
      return 'unknown';
    } catch (e) {
      return 'device-error';
    }
  }
}

enum AuthResult {
  success, emailInUse, weakPassword,
  userNotFound, wrongPassword, error,
}

enum BiometricResult {
  success, failed, notSupported, notEnrolled,
}
