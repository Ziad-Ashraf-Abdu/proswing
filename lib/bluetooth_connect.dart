// ignore_for_file: deprecated_member_use

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothConnector {
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      // Connect to the Bluetooth device
      await device.connect();
      print('${device.localName} connected!');
    } catch (e) {
      print('Error connecting to ${device.localName}: $e');
    }
  }
}
