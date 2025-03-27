import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:permission_handler/permission_handler.dart';
import 'package:proswing/bluetooth_communication.dart';
import 'package:proswing/bluetooth_connect.dart';
import 'package:proswing/bluetooth_scan.dart';
import 'package:proswing/mock_bluetooth_device.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:open_file/open_file.dart';

class ImuAnalysisPage extends StatefulWidget {
  @override
  _ImuAnalysisPageState createState() => _ImuAnalysisPageState();
}

class _ImuAnalysisPageState extends State<ImuAnalysisPage>
    with TickerProviderStateMixin {
  // --- Original Variables ---
  final List<bool> _dotsClicked = List.generate(7, (_) => false);
  late Animation<double> _zoomAnimation;
  int _currentDot = 0;
  bool _isAnimating = false;
  bool startIsClicked = false;
  bool _showChart = true;

  late AnimationController _controller;

  // Bluetooth-related variables
  final BluetoothScanner _bluetoothScanner = BluetoothScanner();
  final BluetoothConnector _bluetoothConnector = BluetoothConnector();
  final BluetoothCommunication _bluetoothCommunicator = BluetoothCommunication();
  List<BluetoothDevice> _availableDevices = [];
  BluetoothDevice? _connectedDevice;

  // For meaningful CSV data:
  // _matrix stores each data row as List<double> (first column is the time stamp)
  // _parameterNames stores the header names from the second header row of the CSV.
  List<List<double>> _matrix = [];
  List<String> _parameterNames = [];
  bool _isScanning = false;
  bool _useMockData = false; // Toggle for mock data
  MockBluetoothDevice mockDevice = MockBluetoothDevice(
    name: "IMU Dummy Device",
    id: "00:11:22:33:44:55",
  );

  // --- Session Variables ---
  bool _sessionStarted = false;
  int _sessionSeconds = 0;
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    print("Initializing IMU Analysis Page");
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _zoomAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    // Start continuous zoom animation.
    _controller.repeat(reverse: true);

    _checkBluetoothPermission(); // Request permissions and initialize Bluetooth.
    _fetchData(); // Pre-fetch data (if any) for chart display.
  }

  // --- Data Fetching ---
  Future<void> _fetchData() async {
    try {
      if (_connectedDevice != null) {
        print("Fetching data from the connected IMU device...");
        // For a real device, we assume the CSV-like format is returned.
        List<String> receivedData =
        await _bluetoothCommunicator.startCommunication(_connectedDevice!);
        // Parse each line into a list of doubles.
        List<List<double>> data = receivedData.map((line) {
          return line
              .split(',')
              .map((e) => double.tryParse(e) ?? 0.0)
              .toList();
        }).toList();
        // Optionally, if the real device sends header info, you could extract it here.
        setState(() {
          _matrix = data;
          _showChart = true;
        });
      } else if (_useMockData) {
        print("Fetching data from mock IMU device...");
        // Use the updated method to read CSV data (including headers).
        await mockDevice.connect();
        List<MockBluetoothService> services =
        await mockDevice.discoverServices();
        // Assume only one service/characteristic for simplicity.
        Map<String, dynamic> csvResult = {};
        for (var service in services) {
          for (var characteristic in service.characteristics) {
            csvResult = await characteristic.readCsvData();
            // Break after first result
            break;
          }
        }
        setState(() {
          _parameterNames = csvResult['headers']; // Second header row
          _matrix = csvResult['data']; // Data rows as List<List<double>>
          _showChart = true;
        });
      } else {
        print("No device connected, and mock data is disabled.");
        _showPopup("No IMU connected and mock data is disabled.");
        return;
      }
      _printMatrix(_matrix);
    } catch (e) {
      print("Error fetching data: $e");
      _showPopup("Error fetching data: $e");
    }
  }

  void _printMatrix(List<List<double>> matrix) {
    for (var row in matrix) {
      print(row);
    }
  }

  @override
  void dispose() {
    print("Disposing IMU Analysis Page");
    _controller.dispose();
    _sessionTimer?.cancel();
    super.dispose();
  }

  // --- Permission & Bluetooth Initialization ---
  Future<void> _checkBluetoothPermission() async {
    if (kIsWeb) {
      print("Running on Web; skipping permission check.");
      _initializeBluetooth();
      return;
    }
    bool granted = await _hasBluetoothPermission();
    if (!granted) {
      bool userConsent = await _showPermissionDialog();
      if (userConsent) {
        var btStatus = await Permission.bluetooth.request();
        var btScanStatus = await Permission.bluetoothScan.request();
        var btConnectStatus = await Permission.bluetoothConnect.request();
        var locStatus = await Permission.locationWhenInUse.request();

        print("Bluetooth: $btStatus");
        print("Bluetooth Scan: $btScanStatus");
        print("Bluetooth Connect: $btConnectStatus");
        print("Location: $locStatus");

        if (btStatus.isGranted &&
            btScanStatus.isGranted &&
            btConnectStatus.isGranted &&
            locStatus.isGranted) {
          _initializeBluetooth();
        } else {
          _showPopup("All required permissions must be granted to continue.");
        }
      } else {
        _showPopup("You must grant the permissions to continue.");
      }
    } else {
      _initializeBluetooth();
    }
  }

  Future<bool> _hasBluetoothPermission() async {
    if (kIsWeb) return true;
    var btStatus = await Permission.bluetooth.status;
    var btScanStatus = await Permission.bluetoothScan.status;
    var btConnectStatus = await Permission.bluetoothConnect.status;
    var locStatus = await Permission.locationWhenInUse.status;
    print("Current statuses: Bluetooth=$btStatus, Scan=$btScanStatus, Connect=$btConnectStatus, Location=$locStatus");
    return btStatus.isGranted &&
        btScanStatus.isGranted &&
        btConnectStatus.isGranted &&
        locStatus.isGranted;
  }

  Future<bool> _showPermissionDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Permissions Required"),
          content: const Text(
              "This action requires Bluetooth and location permissions. Please allow them to proceed."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text("Allow",
                  style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    ) ??
        false;
  }

  Future<void> _initializeBluetooth() async {
    try {
      print("Starting Bluetooth scan...");
      setState(() {
        _isScanning = true;
      });
      _availableDevices = await _bluetoothScanner.scanForDevices();
      print("Found ${_availableDevices.length} devices.");
    } catch (e) {
      print("Error during Bluetooth scan: $e");
      _showPopup("Error scanning for devices: $e");
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  // Updated _toggleMockData: when activated, fetch mock data automatically.
  // void _toggleMockData(bool value) {
  //   setState(() {
  //     _useMockData = value;
  //   });
  //   if (_useMockData) {
  //     _fetchData();
  //   }
  // }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      print("Connecting to device: ${device.remoteId}");
      await _bluetoothConnector.connectToDevice(device);
      setState(() {
        _connectedDevice = device;
      });
      print("Connected to ${device.remoteId}");
      _showPopup("Connected to ${device.remoteId}");
    } catch (e) {
      print("Failed to connect to device: $e");
      _showPopup("Failed to connect to device: $e");
      throw Exception("Connection failed");
    }
  }

  // --- Session Flow ---
  void _promptStartSession() {
    _showPopup("All IMU rods connected. Do you want to start the session?", () {
      _startSession();
    });
  }

  void _startSession() {
    _startIMUCommunication();
    setState(() {
      _sessionStarted = true;
      _sessionSeconds = 0;
    });
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _sessionSeconds++;
      });
    });
  }

  void _stopSession() {
    _sessionTimer?.cancel();
    setState(() {
      _sessionStarted = false;
    });
    _showPopup("Session Ended. Do you want to save the data?", () async {
      await saveCSV(_matrix);
    });
  }

  Future<void> _startIMUCommunication() async {
    if (_connectedDevice == null && !_useMockData) {
      print("No IMU connected.");
      _showPopup("No IMU connected. Please connect a Bluetooth device first.");
      return;
    }
    try {
      print("Starting IMU communication...");
      List<List<double>> rawDataMatrix = [];
      if (_connectedDevice != null) {
        List<String> receivedData =
        await _bluetoothCommunicator.startCommunication(_connectedDevice!);
        rawDataMatrix = receivedData.map((line) {
          return line
              .split(',')
              .map((e) => double.tryParse(e) ?? 0.0)
              .toList();
        }).toList();
      } else if (_useMockData) {
        print("Using mock IMU data...");
        await mockDevice.connect();
        List<MockBluetoothService> services =
        await mockDevice.discoverServices();
        // Use readCsvData() to get headers and data together.
        Map<String, dynamic> csvResult = {};
        for (var service in services) {
          for (var characteristic in service.characteristics) {
            csvResult = await characteristic.readCsvData();
            // Break after first valid result.
            break;
          }
        }
        setState(() {
          _parameterNames = csvResult['headers'];
          rawDataMatrix = csvResult['data'];
        });
      }
      print("Received IMU Data: $rawDataMatrix");
      if (mounted) {
        setState(() {
          _matrix = rawDataMatrix;
          _showChart = true;
        });
      }
      _showPopup("IMU data received and plotted successfully.");
    } catch (e) {
      print("Failed to start communication: $e");
      _showPopup("Failed to start communication: $e");
    }
  }

  Future<void> saveCSV(List<List<double>> data) async {
    String csvData = const ListToCsvConverter().convert(data);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/imu_data.csv');
    await file.writeAsString(csvData);
    print("CSV file saved at: ${file.path}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("CSV saved! Click to open."),
        action: SnackBarAction(
          label: "Open",
          onPressed: () => OpenFile.open(file.path),
        ),
      ),
    );
  }

  /// Updated: Function to import CSV data.
  /// This version expects two header rows (discarding the first and using the second as parameter names)
  /// and then data rows.
  Future<void> importCSV() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/imu_data.csv');
    if (await file.exists()) {
      String csvData = await file.readAsString();
      List<List<dynamic>> csvList =
      const CsvToListConverter().convert(csvData);
      if (csvList.length < 2) {
        _showPopup("CSV does not contain enough header rows.");
        return;
      }
      setState(() {
        _parameterNames = csvList[1].map((e) => e.toString()).toList();
        _matrix = csvList.sublist(2).map((row) {
          return row.map((e) => double.tryParse(e.toString()) ?? 0.0).toList();
        }).toList();
        _showChart = true;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("CSV imported successfully!")));
    } else {
      _showPopup("No CSV file found at ${file.path}");
    }
  }

  /// Updated chart generator:
  /// Uses the first column as the x-axis (time stamp) and creates one line series for each parameter (columns 1...n).
  /// Each series is assigned a different color from Colors.primaries and labeled using _parameterNames.
  List<LineSeries<ChartData, double>> _generateLineSeries() {
    if (_matrix.isEmpty || _parameterNames.isEmpty) return [];
    int numColumns = _matrix[0].length; // Total columns (time + parameters)
    List<LineSeries<ChartData, double>> seriesList = [];
    // Create one series per parameter (starting from index 1, as index 0 is the time stamp)
    for (int col = 1; col < numColumns; col++) {
      List<ChartData> chartData = _matrix.map((row) {
        double x = row[0]; // Time stamp
        double y = row[col];
        return ChartData(x, y);
      }).toList();
      Color seriesColor = Colors.primaries[(col - 1) % Colors.primaries.length];
      seriesList.add(LineSeries<ChartData, double>(
        dataSource: chartData,
        xValueMapper: (ChartData data, _) => data.x,
        yValueMapper: (ChartData data, _) => data.y,
        color: seriesColor,
        name: _parameterNames.length > col ? _parameterNames[col] : 'Param $col',
      ));
    }
    return seriesList;
  }

  // --- Dots, Session, and Popups ---
  void _onDotClick(int index) async {
    print("Dot $index clicked.");
    bool permissionGranted = await _hasBluetoothPermission();
    if (!permissionGranted) {
      await Permission.bluetooth.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
      await Permission.locationWhenInUse.request();
      permissionGranted = await _hasBluetoothPermission();
      if (!permissionGranted) {
        _showPopup("Bluetooth and location permissions are required to use this feature.");
        return;
      }
    }
    await _initializeBluetooth();
    _showDeviceSelectionBottomSheet(index);
  }

  Future<void> _showDeviceSelectionBottomSheet(int index) async {
    await _initializeBluetooth();
    BluetoothDevice? device = await showModalBottomSheet<BluetoothDevice>(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                "Available Devices",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: _availableDevices.isNotEmpty
                  ? ListView.builder(
                itemCount: _availableDevices.length,
                itemBuilder: (context, i) {
                  final device = _availableDevices[i];
                  return ListTile(
                    title: Text(
                      device.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      device.id.toString(),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.of(context).pop(device);
                    },
                  );
                },
              )
                  : const Center(
                child: Text(
                  "No devices found.",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (device != null) {
      try {
        await _connectToDevice(device);
        setState(() {
          _dotsClicked[index] = true;
        });
        if (_dotsClicked.every((clicked) => clicked)) {
          _promptStartSession();
        }
      } catch (e) {
        _showPopup("Connection failed for dot ${index + 1}.");
      }
    }
  }

  // Widget _buildIMUDataDisplay() {
  //   if (!_showChart || _matrix.isEmpty) {
  //     return const Center(
  //       child: Text("No Data Available", style: TextStyle(color: Colors.white)),
  //     );
  //   }
  //   print("Plotting data with ${_generateLineSeries().length} series.");
  //   return SizedBox(
  //     height: 300,
  //     width: double.infinity,
  //     child: Padding(
  //       padding: const EdgeInsets.all(8.0),
  //       child: SfCartesianChart(
  //         legend: Legend(isVisible: true),
  //         primaryXAxis: NumericAxis(title: AxisTitle(text: "Time Stamp")),
  //         primaryYAxis: NumericAxis(title: AxisTitle(text: "Parameter Value")),
  //         series: _generateLineSeries(),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildBottomDrawer() {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Time: $_sessionSeconds s",
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          ElevatedButton(
            onPressed: _stopSession,
            child: const Text("Stop Session"),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingContent() {
    final List<Alignment> dotAlignments = [
      Alignment(0, 0), // Center
      Alignment(0.55, -0.35),
      Alignment(0.78, 0.25),
      Alignment(0.5, 0.8),
      Alignment(-0.5, 0.9),
      Alignment(-0.8, 0.5),
      Alignment(-0.6, -0.5),
    ];

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            "assets/image/Picsart_24-09-21_04-26-50-144.png",
            fit: BoxFit.cover,
          ),
        ),
        ...List.generate(7, (index) {
          return Align(
            alignment: dotAlignments[index],
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onDotClick(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: _dotsClicked[index] ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          );
        }),
        // // Display the chart over the training content.
        // if (_showChart)
        //   Align(
        //     alignment: Alignment.bottomCenter,
        //     child: Container(
        //       color: Colors.black54,
        //       child: _buildIMUDataDisplay(),
        //     ),
        //   ),
      ],
    );
  }

  void _startZoom() {
    print("Starting zoom effect.");
    setState(() {
      startIsClicked = true;
      _isAnimating = true;
      _zoomToDot(_currentDot);
    });
  }

  void _zoomToDot(int index) {
    print("Zooming to dot $index...");
    _controller.forward();
  }

  void _resetSessionAfterPopup() {
    _resetSession();
  }

  void _resetSession() {
    print("Resetting session...");
    setState(() {
      _isAnimating = false;
      _currentDot = 0;
      _dotsClicked.fillRange(0, _dotsClicked.length, false);
    });
  }

  Widget _buildDeviceList() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        itemCount: _availableDevices.length,
        itemBuilder: (context, index) {
          final device = _availableDevices[index];
          return ListTile(
            title: Text(
              device.name,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              device.id.toString(),
              style: const TextStyle(color: Colors.grey),
            ),
            onTap: () => _connectToDevice(device),
          );
        },
      ),
    );
  }

  void _showPopup(String message, [VoidCallback? onDismiss]) {
    print("Showing popup: $message");
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          content: Text(
            message,
            style: TextStyle(
                color: Colors.green.shade600, fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              child: const Text(
                "Done",
                style: TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    ).then((_) {
      if (onDismiss != null) {
        onDismiss();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("IMU Analysis Page"),
        actions: [
          // Toggle between real and mock data.
          Switch(
            value: _useMockData,
            onChanged: (value) => Null //_toggleMockData(value),
          ),
          // Button to import CSV data.
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () async {
              await importCSV();
            },
            tooltip: "Import CSV",
          ),
        ],
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _buildTrainingContent(),
            if (_sessionStarted)
              Align(
                alignment: Alignment.bottomCenter,
                child: _buildBottomDrawer(),
              ),
          ],
        ),
      ),
    );
  }
}

class ChartData {
  final double x;
  final double y;
  ChartData(this.x, this.y);
}
