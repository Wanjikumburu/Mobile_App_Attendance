// lib/screens/teacher/teacher_navigator.dart

import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'teacher_dashboard.dart';
import 'teacher_reports.dart';

class TeacherNavigator extends StatefulWidget {
  const TeacherNavigator({super.key});
  @override
  State<TeacherNavigator> createState() => _TeacherNavigatorState();
}

class _TeacherNavigatorState extends State<TeacherNavigator> {
  int _index = 0;
  final List<Widget> _screens = const [
    TeacherDashboard(),
    TeacherReports(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: AppColors.teacherColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Reports'),
        ],
      ),
    );
  }
}
