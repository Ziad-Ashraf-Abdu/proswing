import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// Import CalendarView
import 'package:proswing/page/splash_Page.dart';
import 'firebase_options.dart'; // Import your generated firebase_options.dart file
import 'package:proswing/core/style.dart';
import 'mock_bluetooth_device.dart'; // Import mock device
import 'bluetooth_communication.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with your options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());

  // Create Bluetooth communication instance
  BluetoothCommunication btComm = BluetoothCommunication();

  // Create a mock device
  MockBluetoothDevice mockDevice = MockBluetoothDevice(
    name: "IMU Dummy Device",
    id: "00:11:22:33:44:55",
      );

  // Start communication with the mock device
  btComm.startCommunication(mockDevice);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus &&
            currentFocus.focusedChild != null) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: MaterialApp(
        title: 'Flutter Demo',
        debugShowCheckedModeBanner: false,
        theme:
            Styles.themeData(), // Ensure Styles is correctly imported and used
        home:
            const SplashPage(), // Corrected to const HomePage if HomePage is a const constructor
      ),
      
    );
  }
}
