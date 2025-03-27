import 'mock_bluetooth_device.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothCommunication {
  Future<List<String>> startCommunication(dynamic device) async {
    List<String> imuData = [];
    try {
      if (device is MockBluetoothDevice) {
        await device.connect();
        imuData = await _startMockIMUCommunication(device);
      } else if (device is BluetoothDevice) {
        await device.connect();
        imuData = await _startRealIMUCommunication(device);
      } else {
        imuData.add('Unknown device type');
      }
    } catch (e) {
      imuData.add('Error starting communication: $e');
    }
    return imuData;
  }

  Future<List<String>> _startMockIMUCommunication(MockBluetoothDevice device) async {
    List<String> data = [];
    try {
      List<MockBluetoothService> services = await device.discoverServices();
      for (MockBluetoothService service in services) {
        for (MockBluetoothCharacteristic characteristic in service.characteristics) {
          // Use the new method to obtain both headers and data.
          Map<String, dynamic> csvResult = await characteristic.readCsvData();
          List<String> headers = csvResult['headers'];
          List<List<double>> matrix = csvResult['data'];
          // Add a header line (optional) and then each data row as a CSV string.
          if (headers.isNotEmpty) {
            data.add(headers.join(','));
          }
          for (var row in matrix) {
            data.add(row.join(','));
          }
        }
      }
    } catch (e) {
      data.add('Error during mock communication: $e');
    }
    return data;
  }

  Future<List<String>> _startRealIMUCommunication(BluetoothDevice device) async {
    List<String> data = [];
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          var value = await characteristic.read();
          data.add('Real IMU Data: $value');
        }
      }
    } catch (e) {
      data.add('Error during real communication: $e');
    }
    return data;
  }
}
