// lib/services/bluetooth_service.dart
// Teacher: broadcast BT beacon | Student: detect beacon
// NOTE: Bluetooth is a SECONDARY check — GPS is the primary verification.
// If Bluetooth is unavailable or fails, attendance can still be marked via GPS.

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class BluetoothService {
  // Valid UUID format required by flutter_blue_plus
  static const String _beaconServiceUUID =
      '550e8400-e29b-41d4-a716-446655440000';

  StreamSubscription? _scanSubscription;

  // ────────────────────────────────────────────────────────────
  // CHECK BLUETOOTH AVAILABILITY
  // ────────────────────────────────────────────────────────────
  Future<BluetoothStatus> checkStatus() async {
    try {
      if (!await FlutterBluePlus.isSupported) {
        return BluetoothStatus.notSupported;
      }
      BluetoothAdapterState state =
          await FlutterBluePlus.adapterState.first;
      if (state == BluetoothAdapterState.on) return BluetoothStatus.on;
      return BluetoothStatus.off;
    } catch (e) {
      return BluetoothStatus.notSupported;
    }
  }

  // ────────────────────────────────────────────────────────────
  // TEACHER — START BEACON
  // Note: FlutterBluePlus does not support BLE advertising on Android.
  // This is a no-op that returns false gracefully — the session
  // still opens and students can mark via GPS alone.
  // ────────────────────────────────────────────────────────────
  Future<bool> startBeacon(String sessionId) async {
    print('📡 Bluetooth beacon not supported on this platform — GPS only mode');
    return false;
  }

  // Stop broadcasting
  Future<void> stopBeacon() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Ignore errors on stop
    }
  }

  // ────────────────────────────────────────────────────────────
  // STUDENT — SCAN FOR TEACHER'S BEACON
  // Returns detected if any BT device is nearby (proximity check)
  // This is optional — GPS alone is sufficient to mark attendance
  // ────────────────────────────────────────────────────────────
  Future<BeaconResult> scanForBeacon(String sessionId) async {
    try {
      BluetoothStatus status = await checkStatus();
      if (status == BluetoothStatus.notSupported) {
        return BeaconResult.notSupported;
      }
      if (status == BluetoothStatus.off) {
        return BeaconResult.bluetoothOff;
      }

      Completer<BeaconResult> completer = Completer();

      _scanSubscription =
          FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.rssi > -80) {
            // -80 dBm = reasonable proximity (~10m)
            print('📶 Nearby device detected! RSSI: ${r.rssi}');
            if (!completer.isCompleted) {
              completer.complete(BeaconResult.detected);
            }
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
      );

      await Future.delayed(const Duration(seconds: 5));
      await _scanSubscription?.cancel();
      await FlutterBluePlus.stopScan();

      if (!completer.isCompleted) {
        completer.complete(BeaconResult.notDetected);
      }

      return completer.future;
    } catch (e) {
      print('Beacon scan error: $e');
      return BeaconResult.error;
    }
  }

  void dispose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
  }
}

enum BluetoothStatus { on, off, notSupported }

enum BeaconResult {
  detected,      // ✅ device found nearby
  notDetected,   // no device found in range
  bluetoothOff,  // BT is off
  notSupported,  // device has no BT
  error,         // something went wrong
}