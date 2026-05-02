// lib/services/location_service.dart
// Handles: GPS permission, current position, geofence check

import 'package:geolocator/geolocator.dart';
import 'dart:math';

class LocationService {

  // ────────────────────────────────────────────────────────────
  // REQUEST PERMISSION
  // ────────────────────────────────────────────────────────────
  Future<LocationPermissionStatus> requestPermission() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return LocationPermissionStatus.serviceDisabled;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied)
        return LocationPermissionStatus.denied;
    }
    if (perm == LocationPermission.deniedForever)
      return LocationPermissionStatus.permanentlyDenied;

    return LocationPermissionStatus.granted;
  }

  // ────────────────────────────────────────────────────────────
  // GET CURRENT POSITION
  // ────────────────────────────────────────────────────────────
  Future<Position?> getCurrentPosition() async {
    LocationPermissionStatus status = await requestPermission();
    if (status != LocationPermissionStatus.granted) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────
  // GEOFENCE CHECK
  // ────────────────────────────────────────────────────────────
  Future<GeofenceResult> checkGeofence({
    required double classroomLat,
    required double classroomLng,
    required double radiusMeters,
  }) async {
    LocationPermissionStatus status = await requestPermission();

    if (status == LocationPermissionStatus.serviceDisabled)
      return GeofenceResult.gpsDisabled;
    if (status == LocationPermissionStatus.permanentlyDenied)
      return GeofenceResult.permissionPermanentlyDenied;
    if (status == LocationPermissionStatus.denied)
      return GeofenceResult.permissionDenied;

    Position? position = await getCurrentPosition();
    if (position == null) return GeofenceResult.locationUnavailable;

    double distance = calculateDistance(
      position.latitude, position.longitude,
      classroomLat, classroomLng,
    );

    return distance <= radiusMeters
        ? GeofenceResult.inside
        : GeofenceResult.outside;
  }

  // ────────────────────────────────────────────────────────────
  // DISTANCE — Haversine Formula (meters)
  // ────────────────────────────────────────────────────────────
  double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000;
    double dLat = _rad(lat2 - lat1);
    double dLon = _rad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double deg) => deg * pi / 180;

  // ── Continuous stream ──────────────────────────────────────
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }
}

enum LocationPermissionStatus {
  granted, denied, permanentlyDenied, serviceDisabled,
}

enum GeofenceResult {
  inside, outside, gpsDisabled,
  permissionDenied, permissionPermanentlyDenied, locationUnavailable,
}
