import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'dart:typed_data';

class IMUUSBConnector {
  SerialPort? _port;
  SerialPortReader? _reader;
  Function(String)? onDataReceived;

  /// Lists all available USB ports.
  List<String> listAvailablePorts() {
    return SerialPort.availablePorts;
  }

  /// Connects to the given USB port.
  bool connect(String portName, {int baudRate = 115200}) {
    _port = SerialPort(portName);

    if (!_port!.openReadWrite()) {
      print("Failed to open port: $portName");
      return false;
    }

    final config = SerialPortConfig();
    config.baudRate = baudRate;
    _port!.config = config;

    // Set up a listener for incoming data
    _reader = SerialPortReader(_port!);
    _reader!.stream.listen((data) {
      String received = String.fromCharCodes(data);
      if (onDataReceived != null) {
        onDataReceived!(received);
      }
    });

    print("Connected to $portName");
    return true;
  }

  /// Sends data to the IMU device.
  void sendData(String data) {
    if (_port != null && _port!.isOpen) {
      _port!.write(Uint8List.fromList(data.codeUnits));
    }
  }

  /// Disconnects the USB connection.
  void disconnect() {
    _reader?.close();
    _port?.close();
    print("Disconnected from USB");
  }
}
