import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class ImuAnalysisPage extends StatefulWidget {
  @override
  _ImuAnalysisPageState createState() => _ImuAnalysisPageState();
}

class _ImuAnalysisPageState extends State<ImuAnalysisPage>
    with TickerProviderStateMixin {

  // Animation controllers
  late AnimationController _uploadAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _uploadAnimation;
  late Animation<double> _pulseAnimation;

  // Upload state variables
  bool _isUploading = false;
  bool _isAnalyzing = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  PlatformFile? _selectedFile;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cloud storage instances
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.readonly',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  // Notification plugin
  FlutterLocalNotificationsPlugin? _notificationsPlugin;

  // Supported file types
  final List<String> _supportedExtensions = ['csv', 'xlsx'];

  // Cloud access status
  bool _isGoogleDriveConnected = false;
  bool _isICloudAvailable = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeNotifications();
    _requestPermissions();
    _checkCloudAvailability();
  }

  void _initializeAnimations() {
    _uploadAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _uploadAnimation = CurvedAnimation(
      parent: _uploadAnimationController,
      curve: Curves.easeInOutCubic,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimationController.repeat(reverse: true);
  }

  Future<void> _initializeNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin?.initialize(initializationSettings);
  }

  Future<void> _requestPermissions() async {
    if (!kIsWeb) {
      await Permission.storage.request();
      await Permission.notification.request();
    }
  }

  Future<void> _checkCloudAvailability() async {
    // Check if Google Drive is available
    try {
      await _googleSignIn.signInSilently();
      setState(() {
        _isGoogleDriveConnected = _googleSignIn.currentUser != null;
      });
    } catch (e) {
      print('Google Drive check failed: $e');
    }

    // Check if iCloud is available (iOS only)
    if (Platform.isIOS) {
      setState(() {
        _isICloudAvailable = true; // iCloud is available through document picker on iOS
      });
    }
  }

  @override
  void dispose() {
    _uploadAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  // File picking functionality
  Future<void> _showUploadOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Choose Upload Source',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              _buildUploadOption(
                icon: Icons.phone_android,
                title: 'Local Storage',
                subtitle: 'Pick from device storage',
                onTap: () {
                  Navigator.pop(context);
                  _pickLocalFile();
                },
              ),
              if (_isGoogleDriveConnected || !kIsWeb) ...[
                SizedBox(height: 12),
                _buildUploadOption(
                  icon: Icons.cloud,
                  title: 'Google Drive',
                  subtitle: _isGoogleDriveConnected
                      ? 'Access your Google Drive files'
                      : 'Sign in to access Google Drive',
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromGoogleDrive();
                  },
                ),
              ],
              if (Platform.isIOS) ...[
                SizedBox(height: 12),
                _buildUploadOption(
                  icon: Icons.cloud_outlined,
                  title: 'iCloud Drive',
                  subtitle: 'Access your iCloud files',
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromICloud();
                  },
                ),
              ],
              SizedBox(height: 12),
              _buildUploadOption(
                icon: Icons.folder_open,
                title: 'Other Cloud Services',
                subtitle: 'Dropbox, OneDrive, etc.',
                onTap: () {
                  Navigator.pop(context);
                  _pickFromOtherClouds();
                },
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.green, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.green, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLocalFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _supportedExtensions,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        await _handleSelectedFile(result.files.first);
      }
    } catch (e) {
      _showErrorDialog('Error selecting local file: $e');
    }
  }

  Future<void> _pickFromGoogleDrive() async {
    try {
      // Sign in to Google if not already signed in
      GoogleSignInAccount? account = _googleSignIn.currentUser;
      if (account == null) {
        account = await _googleSignIn.signIn();
        if (account == null) {
          _showErrorDialog('Google Sign-In was cancelled');
          return;
        }
      }

      // Get authentication headers
      final GoogleSignInAuthentication googleAuth = await account.authentication;
      final AuthClient authClient = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken('Bearer', googleAuth.accessToken!, DateTime.now().add(Duration(hours: 1))),
          googleAuth.idToken,
          [
            'https://www.googleapis.com/auth/drive.readonly',
            'https://www.googleapis.com/auth/drive.file',
          ],
        ),
      );

      final drive.DriveApi driveApi = drive.DriveApi(authClient);

      // List CSV files from Google Drive
      final drive.FileList fileList = await driveApi.files.list(
        q: "mimeType='text/csv' or name contains '.csv'",
        pageSize: 50,
      );

      if (fileList.files?.isEmpty ?? true) {
        _showErrorDialog('No CSV files found in your Google Drive');
        return;
      }

      // Show file selection dialog
      drive.File? selectedFile = await _showGoogleDriveFileDialog(fileList.files!);
      if (selectedFile != null) {
        await _downloadFromGoogleDrive(driveApi, selectedFile);
      }

    } catch (e) {
      _showErrorDialog('Error accessing Google Drive: $e');
    }
  }

  Future<drive.File?> _showGoogleDriveFileDialog(List<drive.File> files) async {
    return await showDialog<drive.File>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.green, width: 2),
          ),
          title: Text(
            'Select Google Drive File',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                return ListTile(
                  leading: Icon(Icons.insert_drive_file, color: Colors.green),
                  title: Text(
                    file.name ?? 'Unknown file',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Size: ${_formatFileSize(file.size)}',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  onTap: () => Navigator.of(context).pop(file),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadFromGoogleDrive(drive.DriveApi driveApi, drive.File file) async {
    try {
      setState(() {
        _uploadStatus = 'Downloading from Google Drive...';
        _isUploading = true;
      });

      final drive.Media media = await driveApi.files.get(
        file.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> bytes = <int>[];
      await for (List<int> chunk in media.stream) {
        bytes.addAll(chunk);
      }

      final PlatformFile platformFile = PlatformFile(
        name: file.name ?? 'google_drive_file.csv',
        size: bytes.length,
        bytes: Uint8List.fromList(bytes),
      );

      await _handleSelectedFile(platformFile);

    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadStatus = '';
      });
      _showErrorDialog('Error downloading from Google Drive: $e');
    }
  }

  Future<void> _pickFromICloud() async {
    try {
      // On iOS, FilePicker with allowCloudPicking enables iCloud access
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _supportedExtensions,
        allowMultiple: false,
        withData: true,
        allowCompression: false,
      );

      if (result != null && result.files.isNotEmpty) {
        await _handleSelectedFile(result.files.first);
      }
    } catch (e) {
      _showErrorDialog('Error accessing iCloud: $e');
    }
  }

  Future<void> _pickFromOtherClouds() async {
    try {
      // Use FilePicker which can access files from various cloud services
      // when they're available through the system file picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _supportedExtensions,
        allowMultiple: false,
        withData: true,
        allowCompression: false,
      );

      if (result != null && result.files.isNotEmpty) {
        await _handleSelectedFile(result.files.first);
      }
    } catch (e) {
      _showErrorDialog('Error accessing cloud storage: $e');
    }
  }

  String _formatFileSize(String? sizeStr) {
    if (sizeStr == null) return 'Unknown';
    try {
      int size = int.parse(sizeStr);
      if (size < 1024) return '$size B';
      if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _handleSelectedFile(PlatformFile file) async {
    setState(() {
      _selectedFile = file;
      _uploadStatus = 'File selected: ${file.name}';
    });

    // Validate CSV format
    if (await _validateCSVFile(file)) {
      _showUploadConfirmation();
    } else {
      _showErrorDialog('Invalid CSV format. Please select a properly formatted CSV file.');
    }
  }

  Future<bool> _validateCSVFile(PlatformFile file) async {
    try {
      if (file.bytes != null) {
        String csvContent = String.fromCharCodes(file.bytes!);
        List<List<dynamic>> csvData = const CsvToListConverter().convert(csvContent);
        return csvData.isNotEmpty && csvData.first.isNotEmpty;
      }
      return false;
    } catch (e) {
      print('CSV validation error: $e');
      return false;
    }
  }

  // Upload confirmation dialog
  void _showUploadConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.green, width: 2),
          ),
          title: Text(
            'Upload File',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File: ${_selectedFile!.name}',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Size: ${(_selectedFile!.size / 1024).toStringAsFixed(2)} KB',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                'This file will be uploaded for analysis. The process may take a few minutes.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _selectedFile = null;
                  _uploadStatus = '';
                });
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _uploadFile();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Upload',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Upload file to Firebase
  Future<void> _uploadFile() async {
    if (_selectedFile == null) return;

    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showErrorDialog('Please log in to upload files.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Preparing upload...';
    });

    _uploadAnimationController.forward();

    try {
      // Create unique filename
      String fileName = '${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}_${_selectedFile!.name}';

      // Upload to Firebase Storage
      Reference storageRef = _storage.ref().child('csv_uploads').child(fileName);
      UploadTask uploadTask = storageRef.putData(_selectedFile!.bytes!);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        setState(() {
          _uploadProgress = progress;
          _uploadStatus = 'Uploading... ${(progress * 100).toStringAsFixed(1)}%';
        });
      });

      // Wait for upload completion
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Save metadata to Firestore
      await _saveUploadMetadata(fileName, downloadUrl, currentUser.uid);

      setState(() {
        _isUploading = false;
        _isAnalyzing = true;
        _uploadStatus = 'Upload complete! Starting analysis...';
      });

      // Start analysis process
      await _startAnalysis(fileName, currentUser.uid);

    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadStatus = 'Upload failed';
      });
      _uploadAnimationController.reverse();
      _showErrorDialog('Upload failed: $e');
    }
  }

  Future<void> _saveUploadMetadata(String fileName, String downloadUrl, String userId) async {
    await _firestore.collection('csv_uploads').add({
      'fileName': fileName,
      'originalName': _selectedFile!.name,
      'downloadUrl': downloadUrl,
      'userId': userId,
      'uploadTime': FieldValue.serverTimestamp(),
      'status': 'uploaded',
      'fileSize': _selectedFile!.size,
    });
  }

  Future<void> _startAnalysis(String fileName, String userId) async {
    try {
      // Simulate analysis process (replace with actual analysis trigger)
      await Future.delayed(Duration(seconds: 3));

      // Update status in Firestore
      QuerySnapshot uploadDocs = await _firestore
          .collection('csv_uploads')
          .where('fileName', isEqualTo: fileName)
          .where('userId', isEqualTo: userId)
          .get();

      if (uploadDocs.docs.isNotEmpty) {
        await uploadDocs.docs.first.reference.update({
          'status': 'analyzing',
          'analysisStartTime': FieldValue.serverTimestamp(),
        });
      }

      // Listen for analysis completion
      _listenForAnalysisCompletion(fileName, userId);

      setState(() {
        _uploadStatus = 'Your session is being analyzed. You will be notified when complete.';
      });

      _showSuccessDialog();

    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _uploadStatus = 'Analysis failed to start';
      });
      _showErrorDialog('Failed to start analysis: $e');
    }
  }

  void _listenForAnalysisCompletion(String fileName, String userId) {
    _firestore
        .collection('csv_uploads')
        .where('fileName', isEqualTo: fileName)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      if (snapshot.docs.isNotEmpty) {
        DocumentSnapshot doc = snapshot.docs.first;
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        if (data['status'] == 'completed') {
          _handleAnalysisCompletion(data);
        }
      }
    });
  }

  Future<void> _handleAnalysisCompletion(Map<String, dynamic> analysisData) async {
    // Show notification
    await _showNotification(
      'Analysis Complete',
      'Your CSV analysis has been completed and saved locally.',
    );

    // Download and save result locally
    if (analysisData['resultUrl'] != null) {
      await _downloadAndSaveResult(analysisData['resultUrl']);
    }

    setState(() {
      _isAnalyzing = false;
      _uploadStatus = 'Analysis complete! Results saved to device.';
    });
  }

  Future<void> _downloadAndSaveResult(String resultUrl) async {
    try {
      // Get hidden app directory
      Directory appDir = await getApplicationSupportDirectory();
      Directory hiddenDir = Directory('${appDir.path}/.analysis_results');

      if (!await hiddenDir.exists()) {
        await hiddenDir.create(recursive: true);
      }

      // Download file (this is a placeholder - implement actual download)
      String fileName = 'analysis_${DateTime.now().millisecondsSinceEpoch}.csv';
      File resultFile = File('${hiddenDir.path}/$fileName');

      // Placeholder: In real implementation, download from resultUrl
      await resultFile.writeAsString('Analysis results would be saved here');

      print('Analysis result saved to: ${resultFile.path}');

    } catch (e) {
      print('Error saving analysis result: $e');
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'analysis_channel',
      'Analysis Notifications',
      channelDescription: 'Notifications for analysis completion',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
    DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin?.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.green, width: 2),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text(
                'Success!',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Text(
            'Your CSV file has been uploaded successfully. The analysis is now in progress. You will receive a notification when it\'s complete.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetUploadState();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.red, width: 2),
          ),
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text(
                'Error',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _resetUploadState() {
    setState(() {
      _selectedFile = null;
      _isUploading = false;
      _isAnalyzing = false;
      _uploadProgress = 0.0;
      _uploadStatus = '';
    });
    _uploadAnimationController.reset();
  }

  Widget _buildUploadArea() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isUploading || _isAnalyzing ? 1.0 : _pulseAnimation.value,
          child: Container(
            height: 250,
            width: double.infinity,
            margin: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isUploading || _isAnalyzing
                    ? Colors.green
                    : Colors.green.withOpacity(0.5),
                width: 2,
                style: BorderStyle.solid,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: InkWell(
              onTap: _isUploading || _isAnalyzing ? null : _showUploadOptions,
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isUploading || _isAnalyzing) ...[
                    _buildProgressIndicator(),
                  ] else ...[
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 64,
                      color: Colors.green,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Upload Files',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Drag or drop files here',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '— OR —',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        if (_isUploading) ...[
          CircularProgressIndicator(
            value: _uploadProgress,
            strokeWidth: 6,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            backgroundColor: Colors.grey[700],
          ),
          SizedBox(height: 16),
        ] else if (_isAnalyzing) ...[
          CircularProgressIndicator(
            strokeWidth: 6,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            backgroundColor: Colors.grey[700],
          ),
          SizedBox(height: 16),
        ],
        Text(
          _uploadStatus,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.green,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFileTypeInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'Supported File Types',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _supportedExtensions.map((ext) {
              return Chip(
                label: Text(
                  ext.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: Colors.green.withOpacity(0.2),
                side: BorderSide(color: Colors.green, width: 1),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Upload Files',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.grey[900],
        iconTheme: IconThemeData(color: Colors.green),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 40),
              _buildUploadArea(),
              SizedBox(height: 30),
              _buildFileTypeInfo(),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}