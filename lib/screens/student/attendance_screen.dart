// lib/screens/student/attendance_screen.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/app_colors.dart';
import '../../models/class_model.dart';
import '../../models/session_model.dart';
import '../../services/location_service.dart';
import '../../services/bluetooth_service.dart';
import '../../services/session_service.dart';
import '../../services/attendance_service.dart';

class AttendanceScreen extends StatefulWidget {
  final ClassModel classData;
  const AttendanceScreen({super.key, required this.classData});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  final LocationService   _locationService   = LocationService();
  final BluetoothService  _bluetoothService  = BluetoothService();
  final SessionService    _sessionService    = SessionService();
  final AttendanceService _attendanceService = AttendanceService();

  // ── State ──────────────────────────────────────────────────
  SessionModel?  _activeSession;
  GeofenceResult _geofenceResult    = GeofenceResult.outside;
  BeaconResult   _beaconResult      = BeaconResult.notDetected;
  Position?      _position;
  bool   _isCheckingLocation  = true;
  bool   _isCheckingBluetooth = false;
  bool   _isMarking           = false;
  bool   _attendanceMarked    = false;
  String _distanceText        = 'Calculating...';

  late AnimationController _pulseController;
  late Animation<double>   _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _checkAll();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(
            parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bluetoothService.dispose();
    super.dispose();
  }

  // ── Run all checks ─────────────────────────────────────────
  Future<void> _checkAll() async {
    setState(() {
      _isCheckingLocation = true;
      _distanceText       = 'Calculating...';
    });

    // 1. Check active session
    _activeSession =
        await _sessionService.getActiveSession(widget.classData.classId);
    print('🔵 Active session: ${_activeSession?.sessionId ?? 'none'}');

    // 2. GPS check
    GeofenceResult geo = await _locationService.checkGeofence(
      classroomLat: widget.classData.locationLat,
      classroomLng: widget.classData.locationLng,
      radiusMeters: widget.classData.radiusMeters,
    );

    Position? pos = await _locationService.getCurrentPosition();
    if (pos != null) {
      double dist = _locationService.calculateDistance(
        pos.latitude, pos.longitude,
        widget.classData.locationLat,
        widget.classData.locationLng,
      );
      _distanceText = '${dist.toStringAsFixed(0)}m from classroom';
      _position     = pos;
    }

    setState(() {
      _geofenceResult    = geo;
      _isCheckingLocation = false;
    });

    // 3. Bluetooth — optional secondary check
    // Runs in background, does NOT block attendance marking
    if (_activeSession != null) {
      setState(() => _isCheckingBluetooth = true);
      BeaconResult bt = await _bluetoothService
          .scanForBeacon(_activeSession!.sessionId)
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () => BeaconResult.notDetected,
          );
      setState(() {
        _beaconResult      = bt;
        _isCheckingBluetooth = false;
      });
    }
  }

  // ── Mark attendance ────────────────────────────────────────
  Future<void> _markAttendance() async {
    if (_position == null || _activeSession == null) return;
    setState(() => _isMarking = true);

    AttendanceResult result = await _attendanceService.markAttendance(
      session:           _activeSession!,
      studentPosition:   _position!,
      bluetoothDetected: _beaconResult == BeaconResult.detected,
    );

    setState(() => _isMarking = false);

    switch (result) {
      case AttendanceResult.success:
        setState(() => _attendanceMarked = true);
        _snack('Attendance marked! ✅', error: false);
        break;
      case AttendanceResult.successLate:
        setState(() => _attendanceMarked = true);
        _snack('Marked as late ⏰', error: false);
        break;
      case AttendanceResult.alreadyMarked:
        _snack('Already marked for this session.');
        break;
      case AttendanceResult.deviceMismatch:
        _snack('⚠️ Device mismatch. Proxy attempt blocked.');
        break;
      case AttendanceResult.sessionClosed:
        _snack('Session has closed.');
        break;
      default:
        _snack('Failed. Please try again.');
    }
  }

  void _snack(String msg, {bool error = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.absent : AppColors.present,
        behavior: SnackBarBehavior.floating,
      ));

  // ── GPS is the only REQUIRED check ────────────────────────
  // Bluetooth is shown as a bonus indicator but does NOT block marking
  bool get _canMark =>
      _activeSession != null &&
      _geofenceResult == GeofenceResult.inside &&
      !_attendanceMarked &&
      !_isMarking &&
      !_isCheckingLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.classData.name),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          // ── Class Info ───────────────────────────────────
          _classInfoCard(),
          const SizedBox(height: 24),

          // ── Session Status ────────────────────────────────
          _sessionCard(),
          const SizedBox(height: 24),

          // ── GPS Check (required) ──────────────────────────
          _checkRow(
            'GPS Location',
            _geofenceResult == GeofenceResult.inside,
            _isCheckingLocation,
            _distanceText,
            required: true,
          ),
          const SizedBox(height: 8),

          // ── Bluetooth Check (optional) ────────────────────
          _checkRow(
            'Bluetooth Beacon (optional)',
            _beaconResult == BeaconResult.detected,
            _isCheckingBluetooth,
            _beaconResult == BeaconResult.detected
                ? '✅ Beacon detected nearby'
                : _beaconResult == BeaconResult.bluetoothOff
                    ? 'Bluetooth is off'
                    : _beaconResult == BeaconResult.notSupported
                        ? 'Not supported on this device'
                        : 'No beacon detected — GPS is sufficient',
            required: false,
          ),
          const SizedBox(height: 32),

          // ── Attendance Button ─────────────────────────────
          _attendanceMarked
              ? _successWidget()
              : ScaleTransition(
                  scale: _canMark
                      ? _pulseAnimation
                      : const AlwaysStoppedAnimation(1.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _canMark ? _markAttendance : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canMark
                            ? AppColors.present
                            : Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: _canMark ? 4 : 0,
                      ),
                      child: _isMarking
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              _activeSession == null
                                  ? 'NO ACTIVE SESSION'
                                  : _isCheckingLocation
                                      ? 'CHECKING LOCATION...'
                                      : _geofenceResult !=
                                              GeofenceResult.inside
                                          ? 'NOT IN CLASSROOM'
                                          : 'MARK ATTENDANCE',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                    ),
                  ),
                ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _isCheckingLocation ? null : _checkAll,
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            label: const Text('Refresh',
                style: TextStyle(color: AppColors.primary)),
          ),
        ]),
      ),
    );
  }

  Widget _classInfoCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.classData.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                  '${widget.classData.teacherName} · ${widget.classData.code}',
                  style: const TextStyle(color: Colors.grey)),
              Text(widget.classData.schedule,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12)),
            ]),
      );

  Widget _sessionCard() {
    if (_activeSession == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Row(children: [
          Icon(Icons.lock_clock, color: AppColors.absent),
          SizedBox(width: 12),
          Expanded(
            child: Text('No active session right now.\nWait for your lecturer to open one.',
                style: TextStyle(
                    color: AppColors.absent,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(children: [
        const Icon(Icons.lock_open, color: AppColors.present),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Session Open ✅',
              style: TextStyle(
                  color: AppColors.present,
                  fontWeight: FontWeight.bold)),
          Text('${_activeSession!.minutesRemaining} min remaining',
              style:
                  const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ]),
    );
  }

  Widget _checkRow(
    String label,
    bool passed,
    bool loading,
    String sub, {
    required bool required,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: passed
                  ? Colors.green.shade200
                  : required
                      ? Colors.red.shade200
                      : Colors.grey.shade200),
        ),
        child: Row(children: [
          loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2))
              : Icon(
                  passed ? Icons.check_circle : Icons.cancel,
                  color: passed
                      ? AppColors.present
                      : required
                          ? AppColors.absent
                          : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    if (!required) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('optional',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      ),
                    ],
                  ]),
                  Text(sub,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ]),
          ),
        ]),
      );

  Widget _successWidget() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: const Column(children: [
          Icon(Icons.check_circle, color: AppColors.present, size: 48),
          SizedBox(height: 10),
          Text('Attendance Marked!',
              style: TextStyle(
                  fontSize: 18,
                  color: AppColors.present,
                  fontWeight: FontWeight.bold)),
          Text('Your attendance has been recorded.',
              style: TextStyle(color: Colors.grey)),
        ]),
      );
}