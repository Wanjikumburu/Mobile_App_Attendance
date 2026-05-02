// lib/screens/admin/at_risk_overview.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_colors.dart';
import '../../models/alert_model.dart';

class AtRiskOverview extends StatelessWidget {
  const AtRiskOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.adminColor,
        foregroundColor: Colors.white,
        title: const Text('At-Risk Students'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('alerts')
            .where('type', isEqualTo: 'at_risk')
            .where('read', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          List<AlertModel> alerts = snapshot.data!.docs.map((doc) =>
              AlertModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
              .toList();

          if (alerts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: AppColors.present),
                  SizedBox(height: 12),
                  Text('No at-risk students!',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  Text('All students are above 75% attendance.',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, i) {
              AlertModel alert = alerts[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.atRisk.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.atRisk.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber,
                        color: AppColors.atRisk),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.title, style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(alert.message,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      Text(alert.className,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.atRisk,
                              fontWeight: FontWeight.w500)),
                    ],
                  )),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
