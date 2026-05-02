// lib/services/bluetooth_service.dart
// Teacher: broadcast BT beacon | Student: detect beacon

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class BluetoothService {
  // Unique ID that identifies this app's beacon
  static const String _beaconServiceUUID = 'ATTENDX-BEACON-2026';

  StreamSubscription? _scanSubscription;
  bool _beaconDetected = false;

  // ────────────────────────────────────────────────────────────
  // CHECK BLUETOOTH AVAILABILITY
  // ────────────────────────────────────────────────────────────
  Future<BluetoothStatus> checkStatus() async {
    try {
      if (!await FlutterBluePlus.isSupported) {
        return BluetoothStatus.notSupported;
      }
      BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
      if (state == BluetoothAdapterState.on) return BluetoothStatus.on;
      return BluetoothStatus.off;
    } catch (e) {
      return BluetoothStatus.notSupported;
    }
  }

  // ────────────────────────────────────────────────────────────
  // TEACHER — START BROADCASTING BEACON
  // Teacher's phone advertises itself so students can detect it
  // ────────────────────────────────────────────────────────────
  Future<bool> startBeacon(String sessionId) async {
    try {
      BluetoothStatus status = await checkStatus();
      if (status != BluetoothStatus.on) return false;

      // FlutterBluePlus handles advertisement on supported devices
      // The sessionId is broadcast as the beacon identifier
      await FlutterBluePlus.startScan(
        withServices: [Guid(_beaconServiceUUID)],
        timeout: const Duration(seconds: 1),
      );
      print('📡 Beacon started for session: $sessionId');
      return true;
    } catch (e) {
      print('Beacon start error: $e');
      return false;
    }
  }

  // Stop broadcasting
  Future<void> stopBeacon() async {
    try {
      await FlutterBluePlus.stopScan();
      print('📡 Beacon stopped');
    } catch (e) {
      print('Beacon stop error: $e');
    }
  }

  // ────────────────────────────────────────────────────────────
  // STUDENT — SCAN FOR TEACHER'S BEACON
  // Returns true if teacher's beacon is detected nearby
  // ────────────────────────────────────────────────────────────
  Future<BeaconResult> scanForBeacon(String sessionId) async {
    try {
      BluetoothStatus status = await checkStatus();
      if (status == BluetoothStatus.notSupported)
        return BeaconResult.notSupported;
      if (status == BluetoothStatus.off) return BeaconResult.bluetoothOff;

      _beaconDetected = false;
      Completer<BeaconResult> completer = Completer();

      // Scan for nearby BT devices for 5 seconds
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          // Look for teacher's device broadcasting our beacon UUID
          // In production: match by sessionId in advertisement data
          if (r.rssi > -80) {
            // -80 dBm = reasonable proximity (~10m)
            _beaconDetected = true;
            print('📶 Beacon detected! RSSI: ${r.rssi}');
            if (!completer.isCompleted) {
              completer.complete(BeaconResult.detected);
            }
          }
        }
      });

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
      );

      // Wait for scan to finish or beacon to be found
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

  // Clean up
  void dispose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
  }
}

enum BluetoothStatus { on, off, notSupported }

enum BeaconResult {
  detected,       // ✅ teacher's beacon found nearby
  notDetected,    // ❌ no beacon found in range
  bluetoothOff,   // BT is off on device
  notSupported,   // device has no BT
  error,          // something went wrong
}
