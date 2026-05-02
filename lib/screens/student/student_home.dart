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

  UserModel? _user;
  List<ClassModel> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _user = await _authService.getUserProfile();

    if (_user != null && 
        _user!.enrolledClasses != null &&       // ← null check
        _user!.enrolledClasses.isNotEmpty) {
          
      QuerySnapshot snap = await _db
          .collection('classes')
          .where(FieldPath.documentId,
              whereIn: _user!.enrolledClasses)
          .get();
      _classes = snap.docs.map((doc) =>
          ClassModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false);
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('My Classes',
                              style: TextStyle(fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _classes.isEmpty
                              ? const Center(
                                  child: Text('No classes enrolled yet.',
                                      style: TextStyle(color: Colors.grey)))
                              : Column(
                                  children: _classes.map((cls) =>
                                      _classCard(cls)).toList()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

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
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AttendanceScreen(classData: cls))),
        ),
      );
}
