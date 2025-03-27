// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class CameraPage extends StatefulWidget {
  final String username;
  const CameraPage({Key? key, required this.username}) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isRecording = false;
  bool _isCameraMode = false;
  bool _isFlashOn = false;
  bool _isRearCamera = true;
  List<CameraDescription>? _cameras;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      final camera = _isRearCamera ? _cameras!.first : _cameras!.last;
      _controller = CameraController(
        camera,
        ResolutionPreset.max, // Improved video resolution
        enableAudio: true,
      );
      _initializeControllerFuture = _controller!.initialize();
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error initializing camera: $e");
      _showSnackBar("Failed to initialize camera. Please restart the app.");
    }
  }

  Future<void> _onRecordButtonPressed() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      if (_isRecording) {
        final XFile videoFile = await _controller!.stopVideoRecording();
        setState(() => _isRecording = _isCameraMode = false);
        await _showProcessDialog(videoFile.path);
      } else {
        await _controller!.startVideoRecording();
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint("Error recording video: $e");
      _showSnackBar("An error occurred while recording.");
    }
  }

  void _toggleFlash() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    setState(() => _isRearCamera = !_isRearCamera);
    await _initializeCamera();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showProcessDialog(String videoPath) async {
    bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text("Analyze Video?", style: TextStyle(color: Colors.white)),
        content: const Text(
            "Do you want to continue processing and upload the video?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child:
                  const Text("No", style: TextStyle(color: Colors.redAccent))),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Yes", style: TextStyle(color: Colors.green))),
        ],
      ),
    );
    if (proceed == true) await _uploadVideo(File(videoPath));
  }

  Future<void> _uploadVideo(File videoFile) async {
    try {
      String fileName = await _generateFileName();
      var request = http.MultipartRequest('POST',
          Uri.parse('https://ZiadAshraf123.pythonanywhere.com/upload_video'));
      request.files
          .add(await http.MultipartFile.fromPath('file', videoFile.path));
      var response = await request.send();
      if (response.statusCode == 200) {
        _showSnackBar("Video uploaded successfully!");
      } else {
        throw "Upload failed with status code: ${response.statusCode}";
      }
    } catch (e) {
      _showSnackBar("Video upload failed: $e");
    }
  }

  Future<String> _generateFileName() async {
    String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String baseName = "${date}_${widget.username}";
    return "${baseName}_1.mp4";
  }

  Future<void> _importVideo() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.video);
    if (result?.files.single.path != null) {
      await _showProcessDialog(result!.files.single.path!);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCameraMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                _controller != null) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  ),
                  Positioned(
                    top: 30,
                    right: 30,
                    child: Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isFlashOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: _toggleFlash,
                        ),
                        IconButton(
                          icon: const Icon(Icons.cameraswitch,
                              color: Colors.white, size: 30),
                          onPressed: _switchCamera,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FloatingActionButton(
                        backgroundColor:
                            _isRecording ? Colors.red : Colors.green,
                        onPressed: _onRecordButtonPressed,
                        child: Icon(_isRecording ? Icons.stop : Icons.videocam,
                            size: 30),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        centerTitle: true,
        elevation: 0,
        title: const Text("Add Video",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 25),
              _buildOption("Import Video", "Select a video from your device",
                  Icons.file_upload_outlined, _importVideo),
              const SizedBox(height: 20),
              _buildOption(
                  "Record Video",
                  "Capture a new video using the camera",
                  Icons.videocam_outlined, () async {
                await _initializeCamera();
                setState(() => _isCameraMode = true);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
      String title, String description, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(description,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16)),
                ]))
          ],
        ),
      ),
    );
  }
}
