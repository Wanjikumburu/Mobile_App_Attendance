// lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth       = AuthService();
  final _formKey                = GlobalKey<FormState>();
  final _emailController        = TextEditingController();
  final _passwordController     = TextEditingController();
  bool _isLoading               = false;
  bool _passwordVisible         = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Clear fields whenever this screen becomes active again ─
  // This ensures switching accounts (teacher → student) always
  // starts with empty fields — no stale credentials
  void _clearFields() {
    _emailController.clear();
    _passwordController.clear();
    _formKey.currentState?.reset();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    AuthResult result = await _auth.login(
      email:    _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    switch (result) {
      case AuthResult.success:
        // main.dart StreamBuilder auto-navigates based on role
        break;
      case AuthResult.userNotFound:
        _snack('No account found with this email.');
        break;
      case AuthResult.wrongPassword:
        _snack('Incorrect password. Please try again.');
        break;
      default:
        _snack(AppStrings.errorGeneric);
    }
  }

  Future<void> _handleBiometric() async {
    setState(() => _isLoading = true);
    BiometricResult result = await _auth.loginWithBiometric();
    setState(() => _isLoading = false);

    switch (result) {
      case BiometricResult.success:
        // main.dart StreamBuilder auto-navigates
        break;
      case BiometricResult.notSupported:
        _snack('Biometric not supported on this device.');
        break;
      case BiometricResult.notEnrolled:
        _snack('No fingerprint enrolled. Go to phone Settings to add one.');
        break;
      case BiometricResult.noSavedCredentials:
        _snack('Login with your password first to enable biometric login.');
        break;
      case BiometricResult.credentialsExpired:
        _snack('Your password changed. Please login with password to re-enable biometric.');
        break;
      default:
        _snack('Biometric failed. Try again.');
    }
  }

  void _snack(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.absent : AppColors.present,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 30),
                // Logo
                CircleAvatar(
                  radius: 45,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: const Icon(Icons.school_rounded,
                      size: 50, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                const Text(AppStrings.appName,
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
                const Text(AppStrings.appTagline,
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 48),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _deco(AppStrings.email,
                      'student@university.edu', Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your email';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: _deco(AppStrings.password,
                          'Min. 6 characters', Icons.lock_outline)
                      .copyWith(
                          suffixIcon: IconButton(
                    icon: Icon(_passwordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                        () => _passwordVisible = !_passwordVisible),
                  )),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your password';
                    if (v.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      if (_emailController.text.isEmpty) {
                        _snack('Enter your email first.');
                        return;
                      }
                      bool sent = await _auth.sendPasswordReset(
                          _emailController.text.trim());
                      if (sent) _snack('Reset email sent!', error: false);
                    },
                    child: const Text(AppStrings.forgotPassword,
                        style: TextStyle(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 8),

                // Login button
                _primaryButton(AppStrings.login, _isLoading, _handleLogin),
                const SizedBox(height: 16),
                _divider(),
                const SizedBox(height: 16),

                // Biometric button
                _outlineButton(AppStrings.biometricLogin,
                    Icons.fingerprint, _handleBiometric),
                const SizedBox(height: 32),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(AppStrings.noAccount,
                        style: TextStyle(color: Colors.grey)),
                    GestureDetector(
                      onTap: () async {
                        // Navigate to register and wait for result
                        final String? registeredEmail =
                            await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        );
                        // Clear fields first
                        _clearFields();
                        // Auto-fill email if registration was successful
                        if (registeredEmail != null &&
                            registeredEmail.isNotEmpty) {
                          _emailController.text = registeredEmail;
                          _snack(
                              'Account created! Enter your password to login.',
                              error: false);
                        }
                      },
                      child: const Text(AppStrings.register,
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _deco(String label, String hint, IconData icon) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2),
        ),
      );

  Widget _primaryButton(
          String label, bool loading, VoidCallback onTap) =>
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );

  Widget _outlineButton(
          String label, IconData icon, VoidCallback onTap) =>
      SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, color: AppColors.primary),
          label: Text(label,
              style: const TextStyle(
                  color: AppColors.primary, fontSize: 16)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _divider() => Row(children: const [
        Expanded(child: Divider()),
        Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('OR', style: TextStyle(color: Colors.grey))),
        Expanded(child: Divider()),
      ]);
}