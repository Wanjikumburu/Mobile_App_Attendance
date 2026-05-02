// lib/screens/auth/register_screen.dart

import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _auth           = AuthService();
  final _formKey                    = GlobalKey<FormState>();
  final _nameController             = TextEditingController();
  final _studentIdController        = TextEditingController();
  final _emailController            = TextEditingController();
  final _departmentController       = TextEditingController();
  final _passwordController         = TextEditingController();
  final _confirmPasswordController  = TextEditingController();

  String _selectedRole = 'student';
  bool _isLoading      = false;
  bool _passVisible    = false;
  bool _confirmVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    AuthResult result = await _auth.register(
      name:       _nameController.text.trim(),
      email:      _emailController.text.trim(),
      password:   _passwordController.text.trim(),
      role:       _selectedRole,
      studentId:  _studentIdController.text.trim(),
      department: _departmentController.text.trim(),
    );

    setState(() => _isLoading = false);

    switch (result) {
      case AuthResult.success:
        _snack('Account created! ✅', error: false);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
        break;
      case AuthResult.emailInUse:
        _snack('Email already registered.');
        break;
      case AuthResult.weakPassword:
        _snack('Password too weak.');
        break;
      default:
        _snack(AppStrings.errorGeneric);
    }
  }

  void _snack(String msg, {bool error = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.absent : AppColors.present,
        behavior: SnackBarBehavior.floating,
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create Account',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Register with your university details',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 28),

                // ── Role Selector ────────────────────────────
                const Text('I am a...',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _roleChip('student', AppStrings.student,
                        Icons.school, AppColors.studentColor),
                    const SizedBox(width: 8),
                    _roleChip('teacher', AppStrings.teacher,
                        Icons.person, AppColors.teacherColor),
                    const SizedBox(width: 8),
                    _roleChip('admin', AppStrings.admin,
                        Icons.admin_panel_settings, AppColors.adminColor),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Name ─────────────────────────────────────
                _field(_nameController, 'Full Name', 'Ali Hassan',
                    Icons.person_outline,
                    validator: (v) => v!.isEmpty ? 'Enter name' : null),
                const SizedBox(height: 16),

                // ── Student ID (students only) ────────────────
                if (_selectedRole == 'student') ...[
                  _field(_studentIdController, 'Student ID', '2021-CS-045',
                      Icons.badge_outlined,
                      validator: (v) => v!.isEmpty ? 'Enter student ID' : null),
                  const SizedBox(height: 16),
                ],

                // ── Department ───────────────────────────────
                _field(_departmentController, 'Department',
                    'Computer Science', Icons.business,
                    validator: (v) => v!.isEmpty ? 'Enter department' : null),
                const SizedBox(height: 16),

                // ── Email ────────────────────────────────────
                _field(_emailController, AppStrings.email,
                    'email@university.edu', Icons.email_outlined,
                    type: TextInputType.emailAddress,
                    validator: (v) {
                      if (v!.isEmpty) return 'Enter email';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    }),
                const SizedBox(height: 16),

                // ── Password ─────────────────────────────────
                _passField(_passwordController, 'Password',
                    _passVisible, () => setState(() => _passVisible = !_passVisible),
                    validator: (v) {
                      if (v!.isEmpty)  return 'Enter password';
                      if (v.length < 6) return 'Min 6 characters';
                      return null;
                    }),
                const SizedBox(height: 16),

                // ── Confirm Password ──────────────────────────
                _passField(_confirmPasswordController, 'Confirm Password',
                    _confirmVisible,
                    () => setState(() => _confirmVisible = !_confirmVisible),
                    validator: (v) {
                      if (v != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    }),
                const SizedBox(height: 32),

                // ── Register Button ───────────────────────────
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 22, width: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text('Create Account',
                            style: TextStyle(fontSize: 16,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(AppStrings.hasAccount,
                        style: TextStyle(color: Colors.grey)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(AppStrings.login,
                          style: TextStyle(color: AppColors.primary,
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

  Widget _roleChip(String value, String label, IconData icon, Color color) {
    bool selected = _selectedRole == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16,
              color: selected ? Colors.white : Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
              color: selected ? Colors.white : Colors.grey,
              fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint,
      IconData icon,
      {TextInputType type = TextInputType.text,
      String? Function(String?)? validator}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        validator: validator,
      );

  Widget _passField(TextEditingController ctrl, String label,
      bool visible, VoidCallback toggle,
      {String? Function(String?)? validator}) =>
      TextFormField(
        controller: ctrl,
        obscureText: !visible,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
            onPressed: toggle,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        validator: validator,
      );
}
