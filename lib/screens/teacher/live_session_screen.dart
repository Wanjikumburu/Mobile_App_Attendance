// lib/screens/teacher/live_session_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/class_model.dart';
import '../../models/session_model.dart';
import '../../models/attendance_model.dart';
import '../../services/session_service.dart';
import '../../services/attendance_service.dart';
import '../../services/bluetooth_service.dart';

class LiveSessionScreen extends StatefulWidget {
  final ClassModel classData;
  const LiveSessionScreen({super.key, required this.classData});
  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  final SessionService    _sessionService    = SessionService();
  final AttendanceService _attendanceService = AttendanceService();
  final BluetoothService  _bluetoothService  = BluetoothService();

  SessionModel? _session;
  Timer?        _timer;
  int           _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    _session = await _sessionService
        .getActiveSession(widget.classData.classId);

    if (_session != null) {
      // ── KEY CHANGE: calculate remaining time from Firestore ──
      // closesAt is computed from openedAt + durationMinutes
      // both of which come from Firestore — not the device timer.
      // This means the countdown is accurate even if the teacher
      // logged out and back in, or switched devices.
      _secondsRemaining =
          _session!.closesAt.difference(DateTime.now()).inSeconds;
      if (_secondsRemaining < 0) _secondsRemaining = 0;
      _startTimer();
    }
    if (mounted) setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        _autoCloseSession();
      }
    });
  }

  Future<void> _autoCloseSession() async {
    if (_session == null) return;
    await _sessionService.closeSession(_session!.sessionId);
    _bluetoothService.stopBeacon();
    if (mounted) {
      _snack('Session closed automatically.', error: false);
      // Stay on screen so teacher can see final attendance
      setState(() {});
    }
  }

  Future<void> _manualClose() async {
    if (_session == null) return;
    bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Close Session?'),
            content: const Text(
                'This will end the session immediately. Students will no longer be able to mark attendance.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Close',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;
    _timer?.cancel();
    await _sessionService.closeSession(_session!.sessionId);
    _bluetoothService.stopBeacon();
    if (mounted) {
      _snack('Session closed.', error: false);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    // ── KEY CHANGE: cancelling the timer does NOT close the
    // session in Firestore. The session stays open and will be
    // expired by expireOldSessions() when anyone next checks.
    // This means teacher can log out freely without killing
    // the session for students.
    _timer?.cancel();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.absent : AppColors.present,
        behavior: SnackBarBehavior.floating,
      ));

  String get _timerDisplay {
    int m = _secondsRemaining ~/ 60;
    int s = _secondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.classData.name),
        backgroundColor: AppColors.teacherColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _manualClose,
            child: const Text('Close Session',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _session == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // ── Timer Banner ─────────────────────────────────
              Container(
                width: double.infinity,
                color: _secondsRemaining > 60
                    ? AppColors.teacherColor
                    : Colors.red, // turns red in last minute
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(children: [
                  Text(_timerDisplay,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace')),
                  Text(
                    _secondsRemaining > 0
                        ? 'Session closes in'
                        : 'Session closed',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ]),
              ),
              // ── Counts Row ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: StreamBuilder<SessionModel?>(
                  stream:
                      _sessionService.sessionStream(_session!.sessionId),
                  builder: (context, snap) {
                    SessionModel? live = snap.data ?? _session;
                    return Row(children: [
                      _countCard('${live?.presentCount ?? 0}',
                          'Present', AppColors.present),
                      const SizedBox(width: 8),
                      _countCard('${live?.lateCount ?? 0}',
                          'Late', AppColors.late),
                      const SizedBox(width: 8),
                      _countCard(
                          '${widget.classData.enrolledStudents.length - (live?.presentCount ?? 0) - (live?.lateCount ?? 0)}',
                          'Absent', AppColors.absent),
                    ]);
                  },
                ),
              ),
              // ── Live Attendance List ─────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Live Attendance',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<AttendanceModel>>(
                  stream: _attendanceService.sessionAttendanceStream(
                      _session!.sessionId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    List<AttendanceModel> records = snapshot.data!;
                    if (records.isEmpty) {
                      return const Center(
                        child: Text('Waiting for students...',
                            style: TextStyle(color: Colors.grey)),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: records.length,
                      itemBuilder: (context, i) {
                        AttendanceModel r = records[i];
                        Color c = r.isPresent
                            ? AppColors.present
                            : r.isLate
                                ? AppColors.late
                                : AppColors.absent;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: c.withOpacity(0.15),
                            child: Text(
                                r.studentName.isNotEmpty
                                    ? r.studentName[0]
                                    : '?',
                                style: TextStyle(
                                    color: c,
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text(r.studentName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(r.studentId),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: c.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(r.status.toUpperCase(),
                                style: TextStyle(
                                    color: c,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ]),
    );
  }

  Widget _countCard(String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ]),
        ),
      );
}