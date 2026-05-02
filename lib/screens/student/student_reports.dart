// lib/screens/student/student_reports.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_colors.dart';
import '../../models/class_model.dart';
import '../../services/auth_service.dart';
import '../../services/attendance_service.dart';

class StudentReports extends StatefulWidget {
  const StudentReports({super.key});
  @override
  State<StudentReports> createState() => _StudentReportsState();
}

class _StudentReportsState extends State<StudentReports> {
  final AuthService        _authService       = AuthService();
  final AttendanceService  _attendanceService = AttendanceService();
  final FirebaseFirestore  _db                = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _reports  = [];
  int  _overallPercentage              = 0;
  bool _isLoading                      = true;
  String _studentName                  = '';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final user = await _authService.getUserProfile();
    if (user == null) return;
    _studentName = user.name;

    List<Map<String, dynamic>> reports = [];

    for (String classId in user.enrolledClasses) {
      DocumentSnapshot classDoc =
          await _db.collection('classes').doc(classId).get();
      if (!classDoc.exists) continue;

      ClassModel cls = ClassModel.fromMap(
          classDoc.id, classDoc.data() as Map<String, dynamic>);

      Map<String, dynamic> report = await _attendanceService.getStudentReport(
        userId:        user.uid,
        classId:       classId,
        totalSessions: cls.totalSessions,
      );

      reports.add({
        'className': cls.name,
        'code':      cls.code,
        'teacher':   cls.teacherName,
        ...report,
      });
    }

    int totalAttended = reports.fold(0, (s, r) => s + ((r['present'] ?? 0) as int));
    int totalClasses  = reports.fold(0, (s, r) => s + ((r['total'] ?? 0) as int));

    setState(() {
      _reports           = reports;
      _overallPercentage = totalClasses > 0
          ? ((totalAttended / totalClasses) * 100).round() : 0;
      _isLoading         = false;
    });
  }

  Color _color(int pct) {
    if (pct >= 80) return AppColors.safe;
    if (pct >= 60) return AppColors.atRisk;
    return AppColors.critical;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Reports'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReports)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(children: [
                  // Overall header
                  Container(
                    width: double.infinity,
                    color: AppColors.primary,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: Column(children: [
                      Text("$_studentName's Report",
                          style: const TextStyle(color: Colors.white,
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Container(
                        width: 110, height: 110,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Colors.white),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$_overallPercentage%',
                                style: TextStyle(fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: _color(_overallPercentage))),
                            const Text('Overall',
                                style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Class Breakdown',
                            style: TextStyle(fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ..._reports.map((r) {
                          int pct = r['percentage'] ?? 0;
                          Color c = _color(pct);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r['className'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('${r['teacher']} · ${r['code']}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 12),
                                Row(children: [
                                  Expanded(child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct / 100,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation(c),
                                      minHeight: 8,
                                    ),
                                  )),
                                  const SizedBox(width: 8),
                                  Text('$pct%', style: TextStyle(
                                      color: c, fontWeight: FontWeight.bold)),
                                ]),
                                const SizedBox(height: 8),
                                Row(children: [
                                  _statChip('${r['present']}', 'Present', AppColors.present),
                                  const SizedBox(width: 8),
                                  _statChip('${r['late']}',    'Late',    AppColors.late),
                                  const SizedBox(width: 8),
                                  _statChip('${r['absent']}',  'Absent',  AppColors.absent),
                                ]),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
    );
  }

  Widget _statChip(String value, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text('$value $label',
        style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.bold)),
  );
}
