// lib/screens/admin/user_management.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_colors.dart';
import '../../models/user_model.dart';

class UserManagement extends StatefulWidget {
  const UserManagement({super.key});
  @override
  State<UserManagement> createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<UserModel>> _usersStream(String role) =>
      _db.collection('users')
          .where('role', isEqualTo: role)
          .snapshots()
          .map((snap) => snap.docs.map((doc) =>
              UserModel.fromMap(doc.id, doc.data())).toList());

  Future<void> _toggleActive(UserModel user) async {
    await _db.collection('users').doc(user.uid).update({
      'isActive': !user.isActive,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.adminColor,
        foregroundColor: Colors.white,
        title: const Text('User Management'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Teachers'),
            Tab(text: 'Admins'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _userList('student'),
          _userList('teacher'),
          _userList('admin'),
        ],
      ),
    );
  }

  Widget _userList(String role) {
    return StreamBuilder<List<UserModel>>(
      stream: _usersStream(role),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        List<UserModel> users = snapshot.data!;
        if (users.isEmpty) {
          return Center(child: Text('No ${role}s found.',
              style: const TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, i) {
            UserModel user = users[i];
            Color roleColor = role == 'student'
                ? AppColors.studentColor
                : role == 'teacher'
                    ? AppColors.teacherColor
                    : AppColors.adminColor;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.04), blurRadius: 4)],
              ),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: roleColor.withOpacity(0.1),
                  child: Text(user.name.isNotEmpty ? user.name[0] : '?',
                      style: TextStyle(color: roleColor,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: const TextStyle(
                        fontWeight: FontWeight.bold)),
                    Text(user.email, style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
                    if (user.studentId.isNotEmpty)
                      Text('ID: ${user.studentId}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    Text(user.department,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ],
                )),
                Switch(
                  value: user.isActive,
                  activeColor: AppColors.present,
                  onChanged: (_) => _toggleActive(user),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}
