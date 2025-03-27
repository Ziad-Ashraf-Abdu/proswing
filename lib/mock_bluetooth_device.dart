import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

class MockBluetoothDevice {
  final String name;
  final String id;

  MockBluetoothDevice({required this.name, required this.id});

  // Simulate connection
  Future<void> connect() async {
    print('$name (Mock Device) connected!');
    await Future.delayed(Duration(seconds: 1)); // Simulate delay
  }

  // Simulate discovering services
  Future<List<MockBluetoothService>> discoverServices() async {
    print('Discovering services for $name...');
    // Use the CSV-based characteristic instead of dummy data.
    MockBluetoothCharacteristic mockCharacteristic = MockBluetoothCharacteristic();
    MockBluetoothService mockService = MockBluetoothService([mockCharacteristic]);
    await Future.delayed(Duration(seconds: 1)); // Simulate delay
    return [mockService];
  }
}

// Custom mock service class
class MockBluetoothService {
  final List<MockBluetoothCharacteristic> characteristics;
  MockBluetoothService(this.characteristics);
}

// Custom mock characteristic class that loads data from assets/Adv1.CSV
class MockBluetoothCharacteristic {
  /// Reads the CSV file and returns a Map containing:
  /// - 'headers': a List<String> from the second header row
  /// - 'data': a List<List<double>> of all remaining data rows
  Future<Map<String, dynamic>> readCsvData() async {
    try {
      // Simulate delay.
      await Future.delayed(Duration(milliseconds: 500));

      // Load the CSV file from assets.
      final String csvString = await rootBundle.loadString('assets/Adv1.CSV');
      if (csvString.trim().isEmpty) {
        print("CSV file is empty.");
        return {'headers': [], 'data': []};
      }

      // Parse CSV data into a list of rows.
      List<List<dynamic>> csvData = const CsvToListConverter().convert(csvString);

      // Verify that we have at least two header rows.
      if (csvData.length < 2) {
        print("CSV file does not contain enough header rows.");
        return {'headers': [], 'data': []};
      }

      // Use the second row (index 1) as parameter names.
      List<String> headers = csvData[1].map((e) => e.toString()).toList();

      // Convert the remaining rows into List<List<double>>
      List<List<double>> data = csvData.sublist(2).map((row) {
        return row.map((e) => double.tryParse(e.toString()) ?? 0.0).toList();
      }).toList();

      print("CSV data successfully loaded with ${data.length} rows.");
      return {'headers': headers, 'data': data};
    } catch (e) {
      print("Error reading CSV asset: $e");
      return {'headers': [], 'data': []};
    }
  }
}
