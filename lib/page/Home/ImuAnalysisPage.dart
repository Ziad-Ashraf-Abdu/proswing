import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http_parser/http_parser.dart';
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
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _uploadAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Upload state variables
  bool _isUploading = false;
  bool _isAnalyzing = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  PlatformFile? _selectedFile;
  String? _localResultPath;

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

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _uploadAnimation = CurvedAnimation(
      parent: _uploadAnimationController,
      curve: Curves.easeInOutCubic,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimationController.repeat(reverse: true);
    _fadeController.forward();
    _slideController.forward();
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
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // File picking functionality
  Future<void> _showUploadOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            border: Border.all(
              color: Colors.blue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(top: 12, bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title with icon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue, Colors.purple],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.cloud_upload_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Choose Upload Source',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Upload options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildModernUploadOption(
                      icon: Icons.phone_android_rounded,
                      title: 'Local Storage',
                      subtitle: 'Pick from device storage',
                      gradient: [Colors.green, Colors.teal],
                      onTap: () {
                        Navigator.pop(context);
                        _pickLocalFile();
                      },
                    ),

                    if (_isGoogleDriveConnected || !kIsWeb) ...[
                      const SizedBox(height: 16),
                      _buildModernUploadOption(
                        icon: Icons.cloud_rounded,
                        title: 'Google Drive',
                        subtitle: _isGoogleDriveConnected
                            ? 'Access your Google Drive files'
                            : 'Sign in to access Google Drive',
                        gradient: [Colors.blue, Colors.indigo],
                        onTap: () {
                          Navigator.pop(context);
                          _pickFromGoogleDrive();
                        },
                      ),
                    ],

                    if (Platform.isIOS) ...[
                      const SizedBox(height: 16),
                      _buildModernUploadOption(
                        icon: Icons.cloud_outlined,
                        title: 'iCloud Drive',
                        subtitle: 'Access your iCloud files',
                        gradient: [Colors.cyan, Colors.blue],
                        onTap: () {
                          Navigator.pop(context);
                          _pickFromICloud();
                        },
                      ),
                    ],

                    const SizedBox(height: 16),
                    _buildModernUploadOption(
                      icon: Icons.folder_open_rounded,
                      title: 'Other Cloud Services',
                      subtitle: 'Dropbox, OneDrive, etc.',
                      gradient: [Colors.orange, Colors.deepOrange],
                      onTap: () {
                        Navigator.pop(context);
                        _pickFromOtherClouds();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient.map((c) => c.withOpacity(0.1)).toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gradient.first.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
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
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.grey[500],
              size: 16,
            ),
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
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1,
              ),
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
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.withOpacity(0.1), Colors.purple.withOpacity(0.1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.cloud_rounded,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Google Drive File',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // File list
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: Colors.grey[800]?.withOpacity(0.5),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.insert_drive_file_rounded,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            file.name ?? 'Unknown file',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Size: ${_formatFileSize(file.size)}',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          onTap: () => Navigator.of(context).pop(file),
                        ),
                      );
                    },
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1,
              ),
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
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.purple],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.upload_file_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                const Text(
                  'Upload File',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 16),

                // File info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[800]?.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File: ${_selectedFile!.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Size: ${(_selectedFile!.size / 1024).toStringAsFixed(2)} KB',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'This file will be uploaded for analysis. The process may take a few minutes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _selectedFile = null;
                            _uploadStatus = '';
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
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
                        onPressed: () {
                          Navigator.of(context).pop();
                          uploadFile();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Upload',
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
        );
      },
    );
  }

  /// Call this to let user pick the CSV first:
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null) return;
    setState(() => _selectedFile = result.files.single);
  }

  Future<String> _saveResultToFile(String resultData) async {
    final appSupportDir = await getApplicationSupportDirectory();
    final hiddenDir = Directory('${appSupportDir.path}/.analysis_results');
    if (!await hiddenDir.exists()) {
      await hiddenDir.create(recursive: true);
    }

    final fileName = 'analysis_${DateTime.now().millisecondsSinceEpoch}.txt';
    final file = File('${hiddenDir.path}/$fileName');
    await file.writeAsString(resultData);
    return file.path;
  }

  Future<void> uploadFile() async {
    if (_selectedFile == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Uploading file to backend...';
    });
    _uploadAnimationController.forward();

    try {
      Uint8List rawBytes;
      if (_selectedFile!.bytes != null) {
        rawBytes = _selectedFile!.bytes!;
      } else if (_selectedFile!.path != null) {
        rawBytes = await File(_selectedFile!.path!).readAsBytes();
      } else {
        throw Exception('No file data available');
      }

      final fileName = _selectedFile!.name;
      final uri = Uri.parse("http://192.168.1.2:7860/convert"); // Local FastAPI server

      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes(
          'uploaded_file',
          rawBytes,
          filename: fileName,
        ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw Exception('Upload failed: ${response.statusCode} $responseBody');
      }

      final jsonResponse = jsonDecode(responseBody);
      final txtContent = jsonResponse['content'];

      if (txtContent == null || txtContent is! String) {
        throw Exception('Invalid response from server. Missing "content".');
      }

      // Save TXT content to user's phone
      final localPath = await _saveResultToFile(txtContent);

      setState(() {
        _isUploading = false;
        _uploadStatus = '✅ File converted and saved to: $localPath';
        _localResultPath = localPath;
      });

      print('✅ Downloaded and saved to: $localPath');

      _uploadAnimationController.reverse();
      _showSuccessDialog();
    } catch (e) {
      _uploadAnimationController.reverse();
      setState(() {
        _isUploading = false;
        _uploadStatus = '❌ Error: $e';
      });
      _showErrorDialog('Upload failed: $e');
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
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.green.withOpacity(0.3),
                width: 1,
              ),
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
                // Success icon with animation
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green, Colors.teal],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                const Text(
                  'Success!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Your CSV file has been uploaded successfully. The analysis is now in progress. You will receive a notification when it\'s complete.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _resetUploadState();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue',
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
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
                width: 1,
              ),
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
                // Error icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Error',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Try Again',
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
          ),
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isUploading || _isAnalyzing ? 1.0 : _pulseAnimation.value,
              child: Container(
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.05),
                      Colors.purple.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isUploading || _isAnalyzing
                        ? Colors.blue
                        : Colors.blue.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isUploading || _isAnalyzing ? null : _showUploadOptions,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: 280,
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isUploading || _isAnalyzing) ...[
                            _buildModernProgressIndicator(),
                          ] else ...[
                            // Upload icon with gradient
                            TweenAnimationBuilder(
                              duration: const Duration(milliseconds: 1000),
                              tween: Tween<double>(begin: 0, end: 1),
                              builder: (context, double value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.blue, Colors.purple],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.3),
                                          blurRadius: 20,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.cloud_upload_rounded,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            const Text(
                              'Upload Files',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              'Drop your files here or click to browse',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                                height: 0.01,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[800]?.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'CSV • XLSX',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModernProgressIndicator() {
    return Column(
      children: [
        // Animated progress ring
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            children: [
              Center(
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: _isUploading ? _uploadProgress / 100 : null,
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    backgroundColor: Colors.grey[700],
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.purple],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isUploading ? Icons.upload_rounded : Icons.analytics_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Text(
          _uploadStatus,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),

        if (_isUploading && _uploadProgress > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${_uploadProgress.toInt()}%',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFileTypeInfo() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.withOpacity(0.05),
                Colors.teal.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.green.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green, Colors.teal],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Supported File Types',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: _supportedExtensions.map((ext) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.withOpacity(0.2), Colors.teal.withOpacity(0.2)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      ext.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
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
                    'Upload Files',
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

            // Main content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    _buildUploadArea(),
                    const SizedBox(height: 24),
                    _buildFileTypeInfo(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _spaceApi {
  final String _hfToken = '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';

  final String spaceApi =
      'https://huggingface.co/spaces/zeyadAAmuhamed/Zee1604/run/predict';
}