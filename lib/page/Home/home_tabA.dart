import 'dart:math';

import 'package:flutter/material.dart';

class CoachHomeScreen extends StatefulWidget {
  const CoachHomeScreen({super.key});

  @override
  _CoachHomeScreenState createState() => _CoachHomeScreenState();
}

class _CoachHomeScreenState extends State<CoachHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Dummy data for teams
  final List<Map<String, String>> teams = [
    {'title': 'Team A', 'description': 'Focused on elite players.'},
    {'title': 'Team B', 'description': 'Beginner coaching group.'},
    {'title': 'Team C', 'description': 'Intermediate development.'},
    {'title': 'Team D', 'description': 'Strength and conditioning.'},
  ];

  // Mock user information
  final String userName = "John Doe";
  final String userEmail = "johndoe@example.com";
  final String userPhone = "+123 456 7890";

  // Generate random image index for each team card
  late List<int> randomImageIndices;

  @override
  void initState() {
    super.initState();
    randomImageIndices = List.generate(
        teams.length, (_) => Random().nextInt(5) + 1); // Assuming 5 images
  }

  void openAddTeamTab() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          "Add New Team",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        content: const Text(
          "This feature will allow adding new teams.",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void openTeamInfoTab(String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        content: Text(
          description,
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void showTeamOptions(BuildContext context, String teamTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (context) {
        return ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: const Text(
            'Delete Team',
            style: TextStyle(color: Colors.white),
          ),
          onTap: () {
            setState(() {
              teams.removeWhere((team) => team['title'] == teamTitle);
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.greenAccent.shade400,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black87,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          splashColor: Colors.green,
          focusColor: Colors.black87,
        ),
      ),
      home: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Coaching Zone'),
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          actions: [
            IconButton(
              icon: CircleAvatar(
                backgroundColor: Colors.greenAccent.shade100,
                child: const Icon(Icons.person, color: Colors.black),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const AlertDialog(
                    title: Text("Switch Acount"),
                    content: Text("Google Sign-In feature coming soon."),
                  ),
                );
              },
            ),
          ],
        ),
        body: ListView.builder(
          itemCount: teams.length,
          itemBuilder: (context, index) {
            final team = teams[index];
            //final imageIndex = randomImageIndices[index];
            return GestureDetector(
              onTap: () =>
                  openTeamInfoTab(team['title']!, team['description']!),
              onLongPress: () => showTeamOptions(context, team['title']!),
              child: Card(
                color: Colors.green.shade800,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Stack(
                  children: [
                    // Background image (uncomment and ensure image paths are correct)
                    // ClipRRect(
                    //   borderRadius: BorderRadius.circular(15),
                    //   child: Image.asset(
                    //     'assets/pics/pic$imageIndex.jpg',
                    //     fit: BoxFit.cover,
                    //     height: 150,
                    //     width: double.infinity,
                    //     color: Colors.black.withOpacity(0.6),
                    //     colorBlendMode: BlendMode.darken,
                    //   ),
                    // ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team['title']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            team['description']!,
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 14,
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
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: openAddTeamTab,
          child: const Icon(Icons.add),
        ),
        drawer: Drawer(
          backgroundColor: Colors.black87,
          child: ListView(
            children: [
              DrawerHeader(
                margin: EdgeInsets.only(bottom: 8.0),
                padding: EdgeInsets.only(bottom: 5, left: 20, top: 5),
                decoration: BoxDecoration(color: Colors.green.shade700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        color: Colors.black,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      userEmail,
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      userPhone,
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.group_sharp, color: Colors.white),
                title:
                    const Text('Teams', style: TextStyle(color: Colors.white)),
                onTap: () {
                  // Navigate to Teams
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications, color: Colors.white),
                title: const Text('Notifications',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  // Navigate to Notifications
                },
              ),
              const Divider(color: Colors.grey),
              ListTile(
                leading: const Icon(Icons.system_update_tv_sharp,
                    color: Colors.white),
                title: const Text('Saved Documents',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  // Navigate to Saved Documents
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white),
                title: const Text('Settings',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  // Handle Settings
                },
              ),
              ListTile(
                leading: const Icon(Icons.help, color: Colors.white),
                title:
                    const Text('Help', style: TextStyle(color: Colors.white)),
                onTap: () {
                  // Handle Help
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
