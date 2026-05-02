// lib/screens/teacher/open_session_screen.dart

import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/class_model.dart';
import '../../services/session_service.dart';
import '../../services/bluetooth_service.dart' as bt;
import 'live_session_screen.dart';

class OpenSessionScreen extends StatefulWidget {
  final ClassModel classData;
  const OpenSessionScreen({super.key, required this.classData});
  @override
  State<OpenSessionScreen> createState() => _OpenSessionScreenState();
}

class _OpenSessionScreenState extends State<OpenSessionScreen> {
  final SessionService     _sessionService   = SessionService();
  final bt.BluetoothService _bluetoothService = bt.BluetoothService();

  int  _durationMinutes   = 5;
  int  _lateWindowMinutes = 2;
  bool _isLoading         = false;
  bool _beaconStarted     = false;

  Future<void> _openSession() async {
    setState(() => _isLoading = true);

    // Start Bluetooth beacon
    bool btStarted = await _bluetoothService.startBeacon(
        widget.classData.classId);
    setState(() => _beaconStarted = btStarted);

    SessionResult result = await _sessionService.openSession(
      classId:           widget.classData.classId,
      className:         widget.classData.name,
      durationMinutes:   _durationMinutes,
      lateWindowMinutes: _lateWindowMinutes,
      bluetoothId:       widget.classData.classId,
    );

    setState(() => _isLoading = false);

    if (result == SessionResult.success) {
      // Go to live session screen
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => LiveSessionScreen(
                classData: widget.classData)));
      }
    } else if (result == SessionResult.alreadyOpen) {
      _snack('A session is already open for this class.');
    } else {
      _snack('Failed to open session.');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Open Session'),
        backgroundColor: AppColors.teacherColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.classData.name,
                      style: const TextStyle(fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text('${widget.classData.code} · ${widget.classData.schedule}',
                      style: const TextStyle(color: Colors.grey)),
                  Text('${widget.classData.enrolledStudents.length} students',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Duration Selector
            const Text('Session Duration',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(children: [5, 10, 15, 20].map((mins) {
              bool selected = _durationMinutes == mins;
              return GestureDetector(
                onTap: () => setState(() => _durationMinutes = mins),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.teacherColor : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected
                            ? AppColors.teacherColor : Colors.grey.shade300),
                  ),
                  child: Text('$mins min',
                      style: TextStyle(
                          color: selected ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold)),
                ),
              );
            }).toList()),
            const SizedBox(height: 24),

            // Late Window Selector
            const Text('Late Window',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Text('Extra minutes after session closes for late marks',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [0, 2, 5].map((mins) {
              bool selected = _lateWindowMinutes == mins;
              return GestureDetector(
                onTap: () => setState(() => _lateWindowMinutes = mins),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.late : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected
                            ? AppColors.late : Colors.grey.shade300),
                  ),
                  child: Text(mins == 0 ? 'None' : '+$mins min',
                      style: TextStyle(
                          color: selected ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold)),
                ),
              );
            }).toList()),
            const SizedBox(height: 24),

            // Bluetooth Status
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(Icons.bluetooth,
                    color: _beaconStarted ? Colors.blue : Colors.grey),
                const SizedBox(width: 10),
                Text(_beaconStarted
                    ? '📡 Bluetooth beacon will broadcast'
                    : '📡 Bluetooth beacon will start when session opens',
                    style: const TextStyle(fontSize: 13)),
              ]),
            ),
            const Spacer(),

            // Open Session Button
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _openSession,
                icon: _isLoading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.play_arrow),
                label: Text(_isLoading ? 'Opening...' : 'Open Session',
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teacherColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
