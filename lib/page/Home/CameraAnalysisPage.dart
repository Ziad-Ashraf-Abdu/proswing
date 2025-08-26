// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class CameraPage extends StatefulWidget {
  final String username;
  const CameraPage({Key? key, required this.username}) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with TickerProviderStateMixin {
  static const String FIRST_SERVER_BASE = 'http://192.168.1.2:7861';
  static const String CONVERT_SERVER_BASE = 'http://192.168.1.2:7860';

  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isRecording = false;
  bool _isCameraMode = false;
  bool _isFlashOn = false;
  bool _isRearCamera = true;
  List<CameraDescription>? _cameras;

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _setupAnimations();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _fadeController.forward();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      final cam = _isRearCamera ? _cameras!.first : _cameras!.last;
      _controller = CameraController(
        cam,
        ResolutionPreset.max,
        enableAudio: true,
      );
      _initializeControllerFuture = _controller!.initialize();
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (mounted) setState(() {});
    } catch (e) {
      _showSnackBar("Failed to init camera: $e");
    }
  }

  Future<void> _onRecordButtonPressed() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    HapticFeedback.mediumImpact();

    try {
      if (_isRecording) {
        _pulseController.stop();
        final XFile videoFile = await _controller!.stopVideoRecording();
        setState(() => _isRecording = _isCameraMode = false);

        final proceed = await _showModernDialog();
        if (proceed == true) {
          await _processVideoFile(File(videoFile.path));
        }
      } else {
        await _controller!.startVideoRecording();
        _pulseController.repeat(reverse: true);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      _showSnackBar("Recording error: $e");
    }
  }

  Future<bool?> _showModernDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_display_rounded,
                  color: Colors.blue,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Process Video?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Upload and analyze this video for processing?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Process",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processVideoFile(File videoFile) async {
    try {
      // 1. Upload video and get job_id
      final fileName = await _generateFileName();
      final uploadReq = http.MultipartRequest(
        'POST',
        Uri.parse('$FIRST_SERVER_BASE/api/process-video'),
      );
      uploadReq.files.add(await http.MultipartFile.fromPath('file', videoFile.path));
      final uploadRes = await uploadReq.send();
      if (uploadRes.statusCode != 200) {
        throw 'Upload failed (${uploadRes.statusCode})';
      }
      final uploadBody = await uploadRes.stream.bytesToString();
      final jobId = jsonDecode(uploadBody)['job_id'] as String;
      _showSnackBar("Video uploaded, job $jobId");

      // 2. Poll status until completed
      await _waitForCompletion(jobId);

      // 3. Download analysed CSV
      final csvUrl = Uri.parse('$FIRST_SERVER_BASE/api/download/$jobId');
      final csvResp = await http.get(csvUrl);
      if (csvResp.statusCode != 200) {
        throw 'CSV download failed (${csvResp.statusCode})';
      }
      _showSnackBar("CSV retrieved");

      // 4. Save CSV to temp
      final tmpDir = await getTemporaryDirectory();
      final tmpCsv = File('${tmpDir.path}/$jobId.csv');
      await tmpCsv.writeAsBytes(csvResp.bodyBytes);

      // 5. POST CSV to conversion server
      final convReq = http.MultipartRequest(
        'POST',
        Uri.parse('$CONVERT_SERVER_BASE/convert'),
      );
      convReq.files.add(await http.MultipartFile.fromPath('uploaded_file', tmpCsv.path));
      final convRes = await convReq.send();
      if (convRes.statusCode != 200) {
        throw 'Conversion failed (${convRes.statusCode})';
      }
      final convBytes = await convRes.stream.toBytes();
      _showSnackBar("Conversion complete");

      // 6. Save converted file to app docs
      final docsDir = await getApplicationDocumentsDirectory();
      final outFile = File('${docsDir.path}/converted_$jobId');
      await outFile.writeAsBytes(convBytes);
      _showSnackBar("Saved result to ${outFile.path}");
    } catch (e) {
      _showSnackBar("Processing error: $e");
    }
  }

  Future<void> _waitForCompletion(String jobId) async {
    final statusUrl = Uri.parse('$FIRST_SERVER_BASE/api/job-status/$jobId');
    while (true) {
      final resp = await http.get(statusUrl);
      if (resp.statusCode != 200) {
        throw 'Status check failed (${resp.statusCode})';
      }
      final json = jsonDecode(resp.body);
      if (json['status'] == 'completed') break;
      await Future.delayed(const Duration(seconds: 2));
    }
    _showSnackBar("Job $jobId completed");
  }

  Future<String> _generateFileName() async {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final baseName = "${date}_${widget.username}";
    return "${baseName}_1.mp4";
  }

  Future<void> _importVideo() async {
    HapticFeedback.lightImpact();
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result?.files.single.path != null) {
      await _processVideoFile(File(result!.files.single.path!));
    }
  }

  void _toggleFlash() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    HapticFeedback.lightImpact();
    setState(() => _isFlashOn = !_isFlashOn);
    _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    HapticFeedback.lightImpact();
    setState(() => _isRearCamera = !_isRearCamera);
    await _initializeCamera();
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.grey[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCameraMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.done && _controller != null) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Camera Preview with rounded corners for modern look
                  ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: CameraPreview(_controller!),
                  ),

                  // Modern gradient overlay for better button visibility
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 150,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Modern control buttons
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 20,
                    right: 20,
                    child: Column(
                      children: [
                        _buildControlButton(
                          icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          onPressed: _toggleFlash,
                          isActive: _isFlashOn,
                        ),
                        const SizedBox(height: 16),
                        _buildControlButton(
                          icon: Icons.cameraswitch_rounded,
                          onPressed: _switchCamera,
                        ),
                      ],
                    ),
                  ),

                  // Modern record button
                  Positioned(
                    bottom: 50,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isRecording ? _pulseAnimation.value : 1.0,
                            child: GestureDetector(
                              onTap: _onRecordButtonPressed,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isRecording ? Colors.red : Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isRecording ? Colors.red : Colors.white).withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isRecording ? Icons.stop_rounded : Icons.videocam_rounded,
                                  size: 35,
                                  color: _isRecording ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Close button
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 20,
                    left: 20,
                    child: _buildControlButton(
                      icon: Icons.close_rounded,
                      onPressed: () => setState(() => _isCameraMode = false),
                    ),
                  ),
                ],
              );
            }
            return Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            );
          },
        ),
      );
    }

    // Main page with modern design
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Modern header
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      "Add Video",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 44), // Balance the back button
                  ],
                ),
              ),

              // Hero section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated icon
                      TweenAnimationBuilder(
                        duration: const Duration(milliseconds: 1000),
                        tween: Tween<double>(begin: 0, end: 1),
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.withOpacity(0.2),
                                    Colors.purple.withOpacity(0.2),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.1),
                                    blurRadius: 30,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.videocam_rounded,
                                size: 80,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 40),

                      // Title and subtitle
                      const Text(
                        "Create or Import",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Record a new video or select one from your gallery\nto get started with analysis",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 60),

                      // Modern action cards
                      _buildModernOption(
                        title: "Import Video",
                        description: "Select from gallery",
                        icon: Icons.file_upload_rounded,
                        gradient: [Colors.green, Colors.teal],
                        onTap: _importVideo,
                      ),

                      const SizedBox(height: 20),

                      _buildModernOption(
                        title: "Record Video",
                        description: "Capture with camera",
                        icon: Icons.videocam_rounded,
                        gradient: [Colors.blue, Colors.purple],
                        onTap: () async {
                          await _initializeCamera();
                          setState(() => _isCameraMode = true);
                        },
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildModernOption({
    required String title,
    required String description,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient.map((c) => c.withOpacity(0.1)).toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: gradient.first.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.grey[500],
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}