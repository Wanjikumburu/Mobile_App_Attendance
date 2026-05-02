// lib/screens/teacher/teacher_dashboard.dart
// Teacher Dashboard with Add Class button + GPS capture

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/app_colors.dart';
import '../../models/class_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../screens/auth/login_screen.dart';
import 'open_session_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});
  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final AuthService       _authService     = AuthService();
  final FirebaseFirestore _db              = FirebaseFirestore.instance;
  final LocationService   _locationService = LocationService();

  UserModel?       _teacher;
  List<ClassModel> _classes   = [];
  bool             _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _teacher = await _authService.getUserProfile();
    if (_teacher == null) return;
    QuerySnapshot snap = await _db
        .collection('classes')
        .where('teacherId', isEqualTo: _teacher!.uid)
        .get();
    _classes = snap.docs
        .map((doc) => ClassModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  void _showAddClassSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddClassSheet(
        teacher: _teacher!,
        onClassAdded: _loadData,
      ),
    );
  }

  Future<void> _deleteClass(ClassModel cls) async {
    bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Class'),
            content: Text('Delete "${cls.name}"? This cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;
    if (confirm) {
      await _db.collection('classes').doc(cls.classId).delete();
      _loadData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class deleted.'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.teacherColor,
        foregroundColor: Colors.white,
        title: const Text('Teacher Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddClassSheet,
        backgroundColor: AppColors.teacherColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Class', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: AppColors.teacherColor,
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Hello, ${_teacher?.name ?? 'Teacher'} 👋',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_teacher?.department ?? '',
                            style: TextStyle(color: Colors.purple.shade100)),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('My Classes (${_classes.length})',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _showAddClassSheet,
                          icon: const Icon(Icons.add, color: AppColors.teacherColor, size: 18),
                          label: const Text('Add Class', style: TextStyle(color: AppColors.teacherColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _classes.isEmpty ? _emptyState() : Column(children: _classes.map(_classCard).toList()),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _emptyState() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(children: [
          Icon(Icons.class_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('No classes yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          const Text('Tap "Add Class" to create your first class',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showAddClassSheet,
            icon: const Icon(Icons.add),
            label: const Text('Add Class'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teacherColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ]),
      );

  Widget _classCard(ClassModel cls) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(cls.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              tooltip: 'Delete class',
              onPressed: () => _deleteClass(cls),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(height: 4),
          Text('${cls.code} · ${cls.schedule}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text('${cls.enrolledStudents.length} students enrolled',
              style: const TextStyle(fontSize: 12)),
          Text(
            '📍 ${cls.locationLat.toStringAsFixed(4)}, ${cls.locationLng.toStringAsFixed(4)} · ${cls.radiusMeters.toInt()}m radius',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => OpenSessionScreen(classData: cls))),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Open Attendance Session'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teacherColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
// ADD CLASS BOTTOM SHEET
// ══════════════════════════════════════════════════════════════
class AddClassSheet extends StatefulWidget {
  final UserModel teacher;
  final VoidCallback onClassAdded;
  const AddClassSheet({super.key, required this.teacher, required this.onClassAdded});
  @override
  State<AddClassSheet> createState() => _AddClassSheetState();
}

class _AddClassSheetState extends State<AddClassSheet> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  final _formKey = GlobalKey<FormState>();

  final _nameController     = TextEditingController();
  final _codeController     = TextEditingController();
  final _scheduleController = TextEditingController();
  final _latController      = TextEditingController();
  final _lngController      = TextEditingController();
  final _radiusController   = TextEditingController(text: '80');

  bool   _isLoading    = false;
  bool   _isGettingGPS = false;
  String _gpsStatus    = '';

  @override
  void dispose() {
    _nameController.dispose(); _codeController.dispose();
    _scheduleController.dispose(); _latController.dispose();
    _lngController.dispose(); _radiusController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() { _isGettingGPS = true; _gpsStatus = 'Getting your location...'; });
    Position? pos = await _locationService.getCurrentPosition();
    if (pos != null) {
      setState(() {
        _latController.text = pos.latitude.toStringAsFixed(6);
        _lngController.text = pos.longitude.toStringAsFixed(6);
        _gpsStatus    = '✅ Location captured! Accuracy: ±${pos.accuracy.toStringAsFixed(0)}m';
        _isGettingGPS = false;
      });
    } else {
      setState(() { _gpsStatus = '❌ Could not get location. Enter manually.'; _isGettingGPS = false; });
    }
  }

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _db.collection('classes').add({
        'name':             _nameController.text.trim(),
        'code':             _codeController.text.trim(),
        'teacherId':        widget.teacher.uid,
        'teacherName':      widget.teacher.name,
        'department':       widget.teacher.department,
        'schedule':         _scheduleController.text.trim(),
        'location': {
          'lat': double.tryParse(_latController.text.trim()) ?? 0.0,
          'lng': double.tryParse(_lngController.text.trim()) ?? 0.0,
        },
        'radiusMeters':     double.tryParse(_radiusController.text.trim()) ?? 80.0,
        'enrolledStudents': [],
        'totalSessions':    0,
      });
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.pop(context);
        widget.onClassAdded();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ "${_nameController.text}" added!'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to add class.'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.teacherColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.class_outlined, color: AppColors.teacherColor),
                ),
                const SizedBox(width: 12),
                const Text('Add New Class',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
              const Divider(height: 24),

              // Class Name
              _field(_nameController, 'Class Name', 'e.g. Mobile Computing',
                  Icons.book_outlined, validator: (v) => v!.isEmpty ? 'Enter class name' : null),
              const SizedBox(height: 14),

              // Code + Schedule
              Row(children: [
                Expanded(child: _field(_codeController, 'Class Code', 'e.g. SCM2301',
                    Icons.tag, validator: (v) => v!.isEmpty ? 'Required' : null)),
                const SizedBox(width: 12),
                Expanded(child: _field(_scheduleController, 'Schedule', 'Mon/Wed 10AM',
                    Icons.schedule, validator: (v) => v!.isEmpty ? 'Required' : null)),
              ]),
              const SizedBox(height: 20),

              // GPS Section
              Row(children: [
                const Icon(Icons.location_on, color: AppColors.teacherColor, size: 18),
                const SizedBox(width: 6),
                const Text('Classroom GPS Location',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
              const SizedBox(height: 6),
              const Text(
                'Stand inside the classroom and tap Capture Location to auto-fill, or enter coordinates from Google Maps.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),

              // Capture button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGettingGPS ? null : _captureLocation,
                  icon: _isGettingGPS
                      ? const SizedBox(height: 16, width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, color: AppColors.teacherColor),
                  label: Text(_isGettingGPS ? 'Getting location...' : 'Capture Current Location',
                      style: const TextStyle(color: AppColors.teacherColor)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.teacherColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),

              // GPS status
              if (_gpsStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _gpsStatus.startsWith('✅') ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _gpsStatus.startsWith('✅') ? Colors.green.shade200 : Colors.red.shade200),
                  ),
                  child: Text(_gpsStatus,
                      style: TextStyle(
                          fontSize: 12,
                          color: _gpsStatus.startsWith('✅') ? Colors.green.shade800 : Colors.red.shade800)),
                ),
              ],
              const SizedBox(height: 14),

              // Lat / Lng
              Row(children: [
                Expanded(child: _field(_latController, 'Latitude', '-1.089600',
                    Icons.explore,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) {
                      if (v!.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    })),
                const SizedBox(width: 12),
                Expanded(child: _field(_lngController, 'Longitude', '37.010800',
                    Icons.explore,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) {
                      if (v!.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    })),
              ]),
              const SizedBox(height: 14),

              // Radius
              _field(_radiusController, 'Geofence Radius (meters)', '80',
                  Icons.radio_button_checked,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v!.isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid';
                    return null;
                  }),
              const SizedBox(height: 6),
              const Text('80m recommended for indoor classrooms, 50m for open areas.',
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveClass,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teacherColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isLoading
                      ? const SizedBox(height: 22, width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Save Class',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint, IconData icon,
      {TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.teacherColor, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        validator: validator,
      );
}