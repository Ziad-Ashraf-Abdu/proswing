// ignore_for_file: deprecated_member_use

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothScanner {
  Future<List<BluetoothDevice>> scanForDevices() async {
    List<BluetoothDevice> devices = [];

    // Start scanning for devices
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    // Listen to scan results
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        // Add the discovered device to the list
        devices.add(result.device);
        print('Device found: ${result.device.localName}');
      }
    });

    // Wait for the scan to complete
    await FlutterBluePlus.stopScan();

    // Return the list of discovered devices
    return devices;
  }
}
