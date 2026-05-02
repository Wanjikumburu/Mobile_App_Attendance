// lib/screens/student/alerts_screen.dart

import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/alert_model.dart';
import '../../services/alert_service.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AlertService alertService = AlertService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alerts'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: alertService.markAllAsRead,
            child: const Text('Mark all read',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<List<AlertModel>>(
        stream: alertService.getAlertsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          List<AlertModel> alerts = snapshot.data ?? [];
          if (alerts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No alerts yet',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, i) {
              AlertModel alert = alerts[i];
              return _alertTile(context, alert, alertService);
            },
          );
        },
      ),
    );
  }

  Widget _alertTile(BuildContext context, AlertModel alert,
      AlertService service) {
    Color color = alert.type == 'at_risk' ? AppColors.atRisk
        : alert.type == 'session_open' ? AppColors.present
        : AppColors.absent;
    IconData icon = alert.type == 'at_risk' ? Icons.warning_amber
        : alert.type == 'session_open' ? Icons.lock_open
        : Icons.cancel;

    return GestureDetector(
      onTap: () => service.markAsRead(alert.alertId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: alert.read ? Colors.white : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: alert.read ? Colors.grey.shade200 : color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alert.title, style: TextStyle(
                  fontWeight: alert.read ? FontWeight.normal : FontWeight.bold)),
              const SizedBox(height: 4),
              Text(alert.message,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(alert.className,
                  style: TextStyle(fontSize: 11, color: color,
                      fontWeight: FontWeight.w500)),
            ],
          )),
          if (!alert.read)
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }
}
