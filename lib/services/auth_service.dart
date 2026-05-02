// lib/services/auth_service.dart
// Handles: Register, Login, Biometric, Logout, Role check, Device ID

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'dart:io';

class AuthService {
  final FirebaseAuth        _auth      = FirebaseAuth.instance;
  final FirebaseFirestore   _db        = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  // ── Shared prefs keys ──────────────────────────────────────
  static const String _keyEmail    = 'biometric_email';
  static const String _keyPassword = 'biometric_password';
  static const String _keyEnabled  = 'biometric_enabled';

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
  // On success, saves credentials for biometric use
  // ────────────────────────────────────────────────────────────
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email, password: password,
      );

      // ── Save credentials for biometric login ───────────────
      // Only saved after a successful login so biometric always
      // has valid credentials to use
      await _saveCredentialsForBiometric(email, password);

      return AuthResult.success;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found')     return AuthResult.userNotFound;
      if (e.code == 'wrong-password')     return AuthResult.wrongPassword;
      if (e.code == 'invalid-credential') return AuthResult.wrongPassword;
      return AuthResult.error;
    }
  }

  // ────────────────────────────────────────────────────────────
  // BIOMETRIC LOGIN
  // Step 1: Verify fingerprint
  // Step 2: Retrieve stored credentials
  // Step 3: Sign into Firebase
  // ────────────────────────────────────────────────────────────
  Future<BiometricResult> loginWithBiometric() async {
    try {
      // ── Check biometric hardware ───────────────────────────
      bool canCheck    = await _localAuth.canCheckBiometrics;
      bool isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) return BiometricResult.notSupported;

      List<BiometricType> available =
          await _localAuth.getAvailableBiometrics();
      if (available.isEmpty) return BiometricResult.notEnrolled;

      // ── Check saved credentials exist ──────────────────────
      bool hasCreds = await _hasSavedCredentials();
      if (!hasCreds) return BiometricResult.noSavedCredentials;

      // ── Verify fingerprint ─────────────────────────────────
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint to log in to AttendX',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!authenticated) return BiometricResult.failed;

      // ── Retrieve saved credentials ─────────────────────────
      Map<String, String?> creds = await _getSavedCredentials();
      String? email    = creds['email'];
      String? password = creds['password'];

      if (email == null || password == null) {
        return BiometricResult.noSavedCredentials;
      }

      // ── Sign into Firebase ─────────────────────────────────
      await _auth.signInWithEmailAndPassword(
        email: email, password: password,
      );

      return BiometricResult.success;

    } on FirebaseAuthException catch (e) {
      print('Biometric Firebase login error: ${e.code}');
      // Credentials may have changed — clear saved ones
      await _clearSavedCredentials();
      return BiometricResult.credentialsExpired;
    } catch (e) {
      print('Biometric error: $e');
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
      return UserModel.fromMap(
          user.uid, doc.data() as Map<String, dynamic>);
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
  // Clears Firebase session — does NOT clear biometric credentials
  // so user can still use biometric to log back in
  // ────────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await _auth.signOut();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('Logout error: $e');
    }
  }

  // ────────────────────────────────────────────────────────────
  // CHECK IF BIOMETRIC IS AVAILABLE AND SET UP
  // ────────────────────────────────────────────────────────────
  Future<bool> isBiometricAvailable() async {
    try {
      bool canCheck    = await _localAuth.canCheckBiometrics;
      bool isSupported = await _localAuth.isDeviceSupported();
      bool hasCreds    = await _hasSavedCredentials();
      return canCheck && isSupported && hasCreds;
    } catch (e) {
      return false;
    }
  }

  // ────────────────────────────────────────────────────────────
  // PRIVATE — Save/retrieve/clear credentials
  // ────────────────────────────────────────────────────────────
  Future<void> _saveCredentialsForBiometric(
      String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail,    email);
    await prefs.setString(_keyPassword, password);
    await prefs.setBool(_keyEnabled,    true);
  }

  Future<bool> _hasSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) == true &&
        prefs.getString(_keyEmail) != null &&
        prefs.getString(_keyPassword) != null;
  }

  Future<Map<String, String?>> _getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email':    prefs.getString(_keyEmail),
      'password': prefs.getString(_keyPassword),
    };
  }

  Future<void> _clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPassword);
    await prefs.remove(_keyEnabled);
  }

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
  success,
  failed,
  notSupported,
  notEnrolled,
  noSavedCredentials,  // user hasn't logged in with password yet
  credentialsExpired,  // password changed, need to login again
}