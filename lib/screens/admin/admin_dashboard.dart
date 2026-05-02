// lib/screens/admin/admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../screens/auth/login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AuthService       _authService = AuthService();
  final FirebaseFirestore _db          = FirebaseFirestore.instance;

  int  _totalStudents  = 0;
  int  _totalTeachers  = 0;
  int  _totalClasses   = 0;
  int  _activeSessions = 0;
  bool _isLoading      = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot students = await _db.collection('users')
          .where('role', isEqualTo: 'student').get();
      QuerySnapshot teachers = await _db.collection('users')
          .where('role', isEqualTo: 'teacher').get();
      QuerySnapshot classes  = await _db.collection('classes').get();
      QuerySnapshot sessions = await _db.collection('sessions')
          .where('status', isEqualTo: 'open').get();

      setState(() {
        _totalStudents  = students.docs.length;
        _totalTeachers  = teachers.docs.length;
        _totalClasses   = classes.docs.length;
        _activeSessions = sessions.docs.length;
        _isLoading      = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.adminColor,
        foregroundColor: Colors.white,
        title: const Text('Admin Overview',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.logout();
              if (mounted) Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Institution Overview',
                        style: TextStyle(fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _statCard('$_totalStudents', 'Students',
                            Icons.school, AppColors.studentColor),
                        _statCard('$_totalTeachers', 'Teachers',
                            Icons.person, AppColors.teacherColor),
                        _statCard('$_totalClasses', 'Classes',
                            Icons.class_outlined, Colors.teal),
                        _statCard('$_activeSessions', 'Active Sessions',
                            Icons.lock_open, AppColors.present),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 6)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 28,
                fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(
                color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
}
