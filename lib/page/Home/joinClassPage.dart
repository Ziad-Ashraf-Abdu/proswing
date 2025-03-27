import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

class JoinClassPage extends StatefulWidget {
  static const String routeName = '/join-class';

  @override
  _JoinClassPageState createState() => _JoinClassPageState();
}

class _JoinClassPageState extends State<JoinClassPage> {
  final TextEditingController _classCodeController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  bool _isJoinButtonEnabled = false; // Initially disabled

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;

    // Add listener to the text field controller to enable the Join button when input is detected
    _classCodeController.addListener(() {
      setState(() {
        _isJoinButtonEnabled = _classCodeController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _classCodeController
        .dispose(); // Dispose of the controller when the widget is removed
    super.dispose();
  }

  // Function to read userTeams.csv and check if the team code exists
  Future<bool> _teamExists(String classCode) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/userTeams.csv';
      final file = File(filePath);

      if (!await file.exists()) {
        return false; // If the file doesn't exist, the team doesn't exist
      }

      final csvData = await file.readAsString();
      final List<List<dynamic>> rowsAsListOfValues =
          const CsvToListConverter().convert(csvData);

      // Check if classCode already exists
      for (var row in rowsAsListOfValues) {
        if (row.contains(classCode)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print("Error reading userTeams.csv: $e");
      return false;
    }
  }

  // Function to handle switching account
  void _switchAccount() async {
    try {
      await _auth.signOut();
      Navigator.of(context).pushNamed('/sign-in'); // Navigate to sign-in screen
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  // Function to add a new team to userTeams.csv
  Future<void> _addTeamToCsv(String classCode) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/userTeams.csv';
      final file = File(filePath);

      List<List<dynamic>> csvData = [];

      // Check if file exists and load existing data
      if (await file.exists()) {
        final existingCsvData = await file.readAsString();
        csvData = const CsvToListConverter().convert(existingCsvData);
      }

      // Add the new team code
      csvData.add([classCode]);

      // Save the updated CSV data
      String csv = const ListToCsvConverter().convert(csvData);
      await file.writeAsString(csv);
    } catch (e) {
      print("Error writing to userTeams.csv: $e");
    }
  }

  // Function to show a bottom drawer with a message
  void _showBottomDrawer(String message) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          height: 100,
          color: Colors.black,
          child: Center(
            child: Text(
              message,
              style: TextStyle(color: Colors.greenAccent, fontSize: 18),
            ),
          ),
        );
      },
    );
  }

  // Function to handle joining a class
  Future<void> _joinClass() async {
    final classCode = _classCodeController.text.trim();

    if (classCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a team code')),
      );
      return;
    }

    // Check if team code already exists in userTeams.csv
    bool exists = await _teamExists(classCode);
    if (exists) {
      // Show bottom drawer message
      _showBottomDrawer('Team already joined');
      return;
    }

    try {
      // Add the class to the user's team collection in Firestore
      await _firestore.collection('teams').doc(_currentUser?.uid).set({
        'classCode': classCode,
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Merge with existing data

      // Add the team to userTeams.csv
      await _addTeamToCsv(classCode);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Team joined successfully')),
      );

      // You can now update the team list, navigate, or perform any post-join action
      Navigator.of(context).pop(); // Go back after successfully joining
    } catch (e) {
      print("Error joining class: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining class: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Join class',
          style: TextStyle(color: Colors.greenAccent),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.greenAccent),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: _isJoinButtonEnabled
                ? _joinClass
                : null, // Enable based on input
            child: Text(
              'Join',
              style: TextStyle(
                color: _isJoinButtonEnabled ? Colors.greenAccent : Colors.grey,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.greenAccent),
            onPressed: () {
              // Additional options
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10),
            Text(
              "You're currently signed in as",
              style: TextStyle(color: Colors.greenAccent),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.greenAccent,
                  child: Text(
                    _currentUser?.displayName != null
                        ? _currentUser!.displayName![0].toUpperCase()
                        : "U",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentUser?.displayName ?? 'User',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _currentUser?.email ?? 'No email available',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: _switchAccount,
              child: Text(
                'Switch account',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
            Divider(color: Colors.greenAccent),
            SizedBox(height: 20),
            Text(
              'Ask your Coach for the Team code, then enter it here.',
              style: TextStyle(color: Colors.greenAccent),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _classCodeController,
              decoration: InputDecoration(
                labelText: 'Team code',
                labelStyle: TextStyle(color: Colors.greenAccent),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.greenAccent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green),
                ),
              ),
              style: TextStyle(color: Colors.greenAccent),
            ),
            SizedBox(height: 20),
            Text(
              'To sign in with a Team code',
              style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '• Use an authorised account\n'
              '• Use a Team code with 6 - 8 letters or numbers and no spaces or symbols',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                // Open help center
              },
              child: Text(
                'If you have trouble joining the Team, go to the Help Centre article.',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.black,
    );
  }
}
