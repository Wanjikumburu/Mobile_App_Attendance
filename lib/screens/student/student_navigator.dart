// lib/screens/student/student_navigator.dart

import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import '../../config/app_colors.dart';
import '../../services/alert_service.dart';
import 'student_home.dart';
import 'student_reports.dart';
import 'alerts_screen.dart';

class StudentNavigator extends StatefulWidget {
  const StudentNavigator({super.key});
  @override
  State<StudentNavigator> createState() => _StudentNavigatorState();
}

class _StudentNavigatorState extends State<StudentNavigator> {
  final AlertService _alertService = AlertService();
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    StudentHome(),
    StudentReports(),
    AlertsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: StreamBuilder<int>(
        stream: _alertService.unreadCountStream(),
        builder: (context, snapshot) {
          int unread = snapshot.data ?? 0;
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            selectedItemColor: AppColors.primary,
            unselectedItemColor: Colors.grey,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: 'Reports',
              ),
              BottomNavigationBarItem(
                icon: badges.Badge(
                  showBadge: unread > 0,
                  badgeContent: Text('$unread',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10)),
                  child: const Icon(Icons.notifications_outlined),
                ),
                activeIcon: const Icon(Icons.notifications),
                label: 'Alerts',
              ),
            ],
          );
        },
      ),
    );
  }
}
