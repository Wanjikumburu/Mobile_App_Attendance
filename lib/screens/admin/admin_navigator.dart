// lib/screens/admin/admin_navigator.dart

import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'admin_dashboard.dart';
import 'user_management.dart';
import 'at_risk_overview.dart';

class AdminNavigator extends StatefulWidget {
  const AdminNavigator({super.key});
  @override
  State<AdminNavigator> createState() => _AdminNavigatorState();
}

class _AdminNavigatorState extends State<AdminNavigator> {
  int _index = 0;
  final List<Widget> _screens = const [
    AdminDashboard(),
    UserManagement(),
    AtRiskOverview(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: AppColors.adminColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Overview'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_outlined),
              activeIcon: Icon(Icons.people),
              label: 'Users'),
          BottomNavigationBarItem(
              icon: Icon(Icons.warning_amber_outlined),
              activeIcon: Icon(Icons.warning_amber),
              label: 'At Risk'),
        ],
      ),
    );
  }
}
