// lib/screens/student/student_home.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/class_model.dart';
import '../../services/auth_service.dart';
import '../../screens/auth/login_screen.dart';
import 'attendance_screen.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});
  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  final AuthService       _authService = AuthService();
  final FirebaseFirestore _db          = FirebaseFirestore.instance;

  UserModel?       _user;
  List<ClassModel> _classes   = [];
  bool             _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _user = await _authService.getUserProfile();

      if (_user != null && _user!.enrolledClasses.isNotEmpty) {
        QuerySnapshot snap = await _db
            .collection('classes')
            .where(FieldPath.documentId, whereIn: _user!.enrolledClasses)
            .get();
        _classes = snap.docs
            .map((doc) => ClassModel.fromMap(
                doc.id, doc.data() as Map<String, dynamic>))
            .toList();
      } else {
        _classes = [];
      }
    } catch (e) {
      debugPrint('_loadData error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
  await _authService.logout();
  if (mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false, // removes ALL previous routes
    );
  }
}

  // ── Show Join Class bottom sheet ───────────────────────────
  void _showJoinClassSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JoinClassSheet(
        student: _user!,
        onJoined: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('AttendX',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      // ── Join Class FAB ─────────────────────────────────────
      floatingActionButton: _user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _showJoinClassSheet,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Join Class',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // ── Header ───────────────────────────────
                    Container(
                      width: double.infinity,
                      color: AppColors.primary,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hello, ${_user?.name ?? 'Student'} 👋',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          Text('ID: ${_user?.studentId ?? ''}',
                              style: TextStyle(
                                  color: Colors.green.shade100)),
                        ],
                      ),
                    ),
                    // ── Summary Cards ─────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        _summaryCard('${_classes.length}', 'Classes',
                            Icons.class_outlined, Colors.blue),
                        const SizedBox(width: 12),
                        _summaryCard(
                            '${_user?.department ?? ''}', 'Dept',
                            Icons.business, Colors.orange),
                      ]),
                    ),
                    // ── Class List ────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('My Classes',
                              style: TextStyle(fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _classes.isEmpty
                              ? _emptyState()
                              : Column(
                                  children: _classes
                                      .map((cls) => _classCard(cls))
                                      .toList()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _emptyState() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(children: [
          Icon(Icons.school_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('No classes yet',
              style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          const Text('Tap "Join Class" to enroll using a class code and password',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _user == null ? null : _showJoinClassSheet,
            icon: const Icon(Icons.add),
            label: const Text('Join Class'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
          ),
        ]),
      );

  Widget _summaryCard(String value, String label,
          IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(label, style: const TextStyle(
                      fontSize: 12, color: Colors.grey)),
                ]),
          ]),
        ),
      );

  Widget _classCard(ClassModel cls) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: const Icon(Icons.class_outlined,
                color: AppColors.primary),
          ),
          title: Text(cls.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${cls.teacherName} · ${cls.code}',
                  style: const TextStyle(fontSize: 12)),
              Text(cls.schedule,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey)),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => AttendanceScreen(classData: cls))),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// JOIN CLASS BOTTOM SHEET
// ══════════════════════════════════════════════════════════════
class JoinClassSheet extends StatefulWidget {
  final UserModel student;
  final VoidCallback onJoined;
  const JoinClassSheet(
      {super.key, required this.student, required this.onJoined});
  @override
  State<JoinClassSheet> createState() => _JoinClassSheetState();
}

class _JoinClassSheetState extends State<JoinClassSheet> {
  final FirebaseFirestore _db      = FirebaseFirestore.instance;
  final _formKey                   = GlobalKey<FormState>();
  final _codeController            = TextEditingController();
  final _passwordController        = TextEditingController();

  bool   _isLoading       = false;
  bool   _passwordVisible = false;
  String _errorMessage    = '';

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _joinClass() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      final String enteredCode     = _codeController.text.trim().toUpperCase();
      final String enteredPassword = _passwordController.text.trim();

      // 1. Find class by code
      QuerySnapshot snap = await _db
          .collection('classes')
          .where('code', isEqualTo: enteredCode)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No class found with that code. Check and try again.';
          _isLoading    = false;
        });
        return;
      }

      final doc       = snap.docs.first;
      final classData = ClassModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);

      // 2. Validate password
      if (classData.enrollmentPassword != enteredPassword) {
        setState(() {
          _errorMessage = 'Incorrect password. Please try again.';
          _isLoading    = false;
        });
        return;
      }

      // 3. Check if already enrolled
      if (classData.enrolledStudents.contains(widget.student.uid)) {
        setState(() {
          _errorMessage = 'You are already enrolled in this class.';
          _isLoading    = false;
        });
        return;
      }

      // 4. Update both documents atomically
      final batch = _db.batch();

      // Add student UID to class's enrolledStudents
      batch.update(_db.collection('classes').doc(classData.classId), {
        'enrolledStudents': FieldValue.arrayUnion([widget.student.uid]),
      });

      // Add classId to student's enrolledClasses
      batch.update(_db.collection('users').doc(widget.student.uid), {
        'enrolledClasses': FieldValue.arrayUnion([classData.classId]),
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        widget.onJoined();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Enrolled in "${classData.name}" successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isLoading    = false;
      });
      debugPrint('JoinClass error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.school_outlined,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Text('Join a Class',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ]),
              const Divider(height: 24),

              const Text(
                'Enter the class code and password provided by your lecturer.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Class Code
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Class Code',
                  hintText: 'e.g. SCM2301',
                  prefixIcon: const Icon(Icons.tag),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 2)),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter class code' : null,
              ),
              const SizedBox(height: 14),

              // Enrollment Password
              TextFormField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  labelText: 'Enrollment Password',
                  hintText: 'Password given by lecturer',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_passwordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                        () => _passwordVisible = !_passwordVisible),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 2)),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter password' : null,
              ),
              const SizedBox(height: 12),

              // Error message
              if (_errorMessage.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_errorMessage,
                            style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 13))),
                  ]),
                ),

              const SizedBox(height: 24),

              // Join button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _joinClass,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22, width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Join Class',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}