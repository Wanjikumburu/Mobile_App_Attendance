// lib/screens/teacher/teacher_reports.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_colors.dart';
import '../../models/class_model.dart';
import '../../services/auth_service.dart';
import '../../services/attendance_service.dart';

class TeacherReports extends StatefulWidget {
  const TeacherReports({super.key});
  @override
  State<TeacherReports> createState() => _TeacherReportsState();
}

class _TeacherReportsState extends State<TeacherReports> {
  final AuthService        _authService       = AuthService();
  final AttendanceService  _attendanceService = AttendanceService();
  final FirebaseFirestore  _db                = FirebaseFirestore.instance;

  List<ClassModel> _classes          = [];
  ClassModel?      _selectedClass;
  List<Map<String, dynamic>> _report = [];
  bool _isLoading                    = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final user = await _authService.getUserProfile();
    if (user == null) return;
    QuerySnapshot snap = await _db
        .collection('classes')
        .where('teacherId', isEqualTo: user.uid)
        .get();
    setState(() {
      _classes = snap.docs.map((doc) =>
          ClassModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> _loadReport(ClassModel cls) async {
    setState(() { _selectedClass = cls; _isLoading = true; });
    List<Map<String, dynamic>> report =
        await _attendanceService.getClassReport(cls.classId, cls.totalSessions);
    setState(() { _report = report; _isLoading = false; });
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
        title: const Text('Class Reports'),
        backgroundColor: AppColors.teacherColor,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        // Class selector
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<ClassModel>(
            value: _selectedClass,
            hint: const Text('Select a class'),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
            ),
            items: _classes.map((cls) => DropdownMenuItem(
              value: cls,
              child: Text(cls.name),
            )).toList(),
            onChanged: (cls) { if (cls != null) _loadReport(cls); },
          ),
        ),
        // Report
        Expanded(
          child: _selectedClass == null
              ? const Center(child: Text('Select a class to view report',
                  style: TextStyle(color: Colors.grey)))
              : _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _report.isEmpty
                      ? const Center(child: Text('No attendance data yet.',
                          style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _report.length,
                          itemBuilder: (context, i) {
                            Map<String, dynamic> r = _report[i];
                            int pct = r['percentage'] as int;
                            Color c = _color(pct);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4)],
                              ),
                              child: Row(children: [
                                CircleAvatar(
                                  backgroundColor: c.withOpacity(0.1),
                                  child: Text('$pct%',
                                      style: TextStyle(color: c,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r['studentName'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(r['studentId'] ?? '',
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: pct / 100,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation(c),
                                        minHeight: 5,
                                      ),
                                    ),
                                  ],
                                )),
                                const SizedBox(width: 8),
                                Column(children: [
                                  Text('${r['present']}/${r['total']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const Text('attended',
                                      style: TextStyle(fontSize: 10,
                                          color: Colors.grey)),
                                ]),
                              ]),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}
