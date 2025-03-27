// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'dart:math'; // generating random numbers
import 'package:flutter/material.dart';
import 'package:proswing/page/Home/CameraAnalysisPage.dart';
import 'package:proswing/page/Home/ImuAnalysisPage.dart';
import 'package:proswing/services/get_user_data.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:proswing/page/Home/Progress/Level.dart';
import 'package:proswing/page/Home/Progress/Efficiency.dart';
import 'package:proswing/page/Home/Progress/LastSessionAssisment.dart';
import 'package:proswing/page/Home/LastSessionAssessmentSection.dart';
//import 'package:proswing/page/Home/joinClassPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:proswing/page/login_page.dart';
import 'package:syncfusion_flutter_charts/charts.dart'; // Syncfusion charts import

class HomeScreenPage extends StatefulWidget {
  const HomeScreenPage({super.key});

  @override
  _HomeScreenPageState createState() => _HomeScreenPageState();
}

class _HomeScreenPageState extends State<HomeScreenPage>
    with SingleTickerProviderStateMixin {
  final values = [75, 60, 55];
  bool isInTeam = false;
  String teamName = "";
  String createdBy = "";
  bool startIsClicked = false;

  // ignore: unused_field
  late ScrollController _scrollController;

  late String greetingMessage = greetingPhrases[1];
  late bool showGreeting = false;
  int _currentIndex = 0;
  DateTime selectedDay = DateTime.now();
  List<String> quotes = [];
  int currentQuoteIndex = 0;
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;

  final List<String> greetingPhrases = [
    "How's your day?",
    "Penny for your thoughts!",
    "Hopefully, life has been treating you well."
  ];

  @override
  void initState() {
    super.initState();
    //_loadTeamNames();
    _scrollController = ScrollController();
    showGreeting = true; // Initially show the greeting
    _loadAndSetQuotes();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeInAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _startQuoteRotation();
    _startGreetingTimer();
  }

  Future<void> _loadAndSetQuotes() async {
    quotes = await loadQuotes();
    _selectRandomQuote(); // Pick a random quote on load
    setState(() {});
    _startQuoteRotation();
  }

  // Show greeting for 15 seconds, then switch to quote
  void _startGreetingTimer() {
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          showGreeting = false; // Switch to showing the quote
          _controller.reset();
          _controller.forward();
        });
      }
    });
  }

  // This method selects a random quote
  void _selectRandomQuote() {
    final random = Random();
    currentQuoteIndex = random.nextInt(quotes.length); // Random index
  }

  // Rotates to a random quote every 30 minutes
  void _startQuoteRotation() {
    Future.delayed(const Duration(minutes: 30), () {
      if (mounted) {
        setState(() {
          _selectRandomQuote(); // Pick a random quote each time
        });
        _controller.reset();
        _controller.forward();
        _startQuoteRotation();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return IndexedStack(
            index: _currentIndex,
            children: [
              _buildHomeContent(),
              _buildTrainingContent(),
              _buildMoreContent(),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuoteRow(),
          const SizedBox(height: 30),
          _buildSectionTitle("Your Progress"),
          const SizedBox(height: 20),
          _buildProgressCards(),
          const SizedBox(height: 30),
          LastSessionAssismentSection(75),
        ],
      ),
    );
  }

  Widget _buildQuoteRow() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: getUserData(), // Fetch user data from Firestore
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator()); // Loading state
        } else if (snapshot.hasError) {
          return const Text('Error fetching user data');
        } else if (!snapshot.hasData || snapshot.data == null) {
          return const Text('No user data found');
        } else {
          // Extract the user name from the Firestore data
          String userName = snapshot.data!['name'] ??
              'User'; // Use 'User' as a fallback if name is null

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: FadeTransition(
                  opacity: _fadeInAnimation,
                  child: Container(
                    padding:
                        const EdgeInsets.only(top: 25.0, right: 10, left: 6.5),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: SingleChildScrollView(
                      // Add scroll view for long quotes
                      child: Text(
                        showGreeting
                            ? "Hi, $userName.\n$greetingMessage"
                            : (quotes.isNotEmpty &&
                                    currentQuoteIndex < quotes.length)
                                ? quotes[currentQuoteIndex]
                                : 'Loading...',
                        style: TextStyle(
                          color: Colors.green.shade300,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              blurRadius: 2.2,
                              color: Colors.grey.withOpacity(0.7),
                              offset: const Offset(2.0, 2.0),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: CircleAvatar(
                  backgroundColor: Colors.greenAccent.shade100,
                  child: const Icon(Icons.person, color: Colors.black),
                ),
                onPressed: () {
                  showUserInfo(context);
                },
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return TextButton(
      onPressed: () {
        // Open full calendar in a new tab
        if (title == 'Calendar') {
          //Navigator.push(
          //context,
          //MaterialPageRoute(builder: (context) => MyApp()),
          //);
        }
      },
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Build the progress cards using Syncfusion charts for circular progress
  Widget _buildProgressCards() {
    return SizedBox(
      height: 400,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 1,
        itemBuilder: (context, index) {
          return Center(
            // This centers the ProgressCard in the ListView
            child: ProgressCard(),
          );
        },
      ),
    );
  }

//TRAINING TAB__________________________________________________________________________________________________________________________________________________//
  bool showOptions = false; // Persistent variable to retain state
  bool isBottomImageVisible =
      true; // Control the visibility of the bottom image

  Future<void> _onStartSession() async {
    if (!showOptions) {
      setState(() {
        showOptions =
            true; // Show options only when the second image is pressed
      });
    }
  }

  Widget _buildTrainingContent() {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background
      body: Column(
        children: [
          // Display Image at the Top (first image - non-pressable)
          const SizedBox(height: 50),
          AnimatedContainer(
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: 200,
            height: 250,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/image/1738577169848.png"),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  offset: Offset(4, 4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: showOptions
                  ? _buildChoiceButtons() // Show options only after the bottom image is pressed
                  : SizedBox.shrink(), // No buttons shown before image press
            ),
          ),
        ],
      ),
      bottomNavigationBar: Visibility(
        visible:
            isBottomImageVisible, // Image is visible when isBottomImageVisible is true
        child: GestureDetector(
          onTap: _onBottomImagePressed, // When tapped, hide the bottom image
          child: Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/image/1738577174871.png"),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Choose your option:",
          style: TextStyle(
            color: Colors.greenAccent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        _buildOptionButton("Use Camera", _openCameraPage),
        const SizedBox(height: 12),
        _buildOptionButton("Use IMUs", _openImusPage),
      ],
    );
  }

  Widget _buildOptionButton(String title, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          showOptions = false; // Reset options visibility after navigation
          isBottomImageVisible = true; // Make the bottom image visible again
        });
        onPressed();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade400,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 60),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _onBottomImagePressed() {
    setState(() {
      isBottomImageVisible = false; // Hide the bottom image when pressed
      showOptions = true; // Show options after the bottom image is pressed
    });
  }

  void _openCameraPage() {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder(
          future: getUserData(), // Fetch user data from Firestore
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator()); // Loading state
            } else if (snapshot.hasError) {
              return const AlertDialog(
                content: Text('Error fetching user data'),
              );
            } else if (!snapshot.hasData || snapshot.data == null) {
              return const AlertDialog(
                content: Text('No user data found'),
              );
            } else {
              // Extract the username from Firestore data
              String userName = snapshot.data!['name'] ?? 'User';

              // Navigate to CameraPage with the username
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CameraPage(username: userName),
                  ),
                ).then((_) {
                  setState(() {
                    showOptions = false; // Reset options when returning
                    isBottomImageVisible =
                        true; // Make bottom image visible again
                  });
                });
              });

              // Close the dialog
              Navigator.of(context).pop();
              return SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  void _openImusPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ImuAnalysisPage()),
    ).then((_) {
      setState(() {
        showOptions = false; // Reset options when returning
        isBottomImageVisible = true; // Make bottom image visible again
      });
    });
  }

//MORE TAB____________________________________________________________________________________________________________________________________________________//
  Widget _buildMoreContent() {
    return Container(
      padding: const EdgeInsets.only(top: 40.0),
      height: MediaQuery.of(context).size.height, // Full screen height
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Card Section
            _buildUserCardSection(),

            const SizedBox(height: 230),

            // Settings and Information Section
            _buildSettingsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCardSection() {
    String getPlayerLevel(double value) {
      if (value <= 4) {
        return 'Beginner';
      } else if (value <= 7) {
        return 'Intermediate';
      } else {
        return 'Professional';
      }
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: getUserData(), // Fetch user data from Firestore
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
                  CircularProgressIndicator()); // Show loading spinner while fetching data
        } else if (snapshot.hasError) {
          return const Text('Error fetching user data');
        } else if (!snapshot.hasData || snapshot.data == null) {
          return const Text('No user data found');
        } else {
          // Extract user data from Firestore
          String userName = snapshot.data!['name'] ?? 'User Name';
          String email = snapshot.data!['email'] ?? 'user@example.com';
          String phone = snapshot.data!['phone'] ?? '+123456789';
          int height =
              snapshot.data!['height'] ?? 000; // Assuming height is also stored
          int weight =
              snapshot.data!['weight'] ?? 000; // Assuming weight is also stored
          String gender = snapshot.data!['gender'] ??
              'Unknown'; // Assuming gender is also stored
          var value = values[0] /
              10; // User's current level value (assuming this comes from somewhere)
          String level = getPlayerLevel(
              value); // Assuming the level is calculated or stored elsewhere

          return Center(
            child: FractionallySizedBox(
              widthFactor: 0.9, // 90% of the screen width
              child: Card(
                color: Colors.grey[850],
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius:
                                38.5, // Adjusted size to make the avatar more prominent
                            backgroundColor: Colors.greenAccent.shade100,
                            child:
                                const Icon(Icons.person, color: Colors.black),
                          ),
                          const SizedBox(
                              width: 16), // Spacing between avatar and text
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName, // User's actual name
                                style: TextStyle(
                                  color: Colors.green.shade400,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                height: 2,
                                width: 200, // Height of the line
                                color: Colors.white, // Color of the line
                                margin: const EdgeInsets.symmetric(vertical: 4),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(
                          height: 10), // Spacing before other details
                      Text(
                        'Email: $email', // User's actual email
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Phone: $phone', // User's actual phone number
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Height: $height cm', // User's actual height
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Weight: $weight kg', // User's actual weight
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Gender: $gender', // User's actual gender
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Current Level: $level $value', // User's current level value
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      ListTile(
                        leading:
                            Icon(Icons.logout, color: Colors.green.shade400),
                        title: const Text('Sign Out',
                            style: TextStyle(color: Colors.white)),
                        onTap: () async {
                          // Handle profile modification logic here
                          await FirebaseAuth.instance.signOut();
                          Navigator.of(context).pop(); // Close the modal
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Signed out successfully')),
                          );
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (builder) => const LoginPage()));
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(Icons.edit, color: Colors.green.shade400),
          title: const Text('Modify Profile',
              style: TextStyle(color: Colors.white)),
          onTap: () {
            // Handle profile modification logic here
          },
        ),
        ListTile(
          leading: Icon(Icons.settings, color: Colors.green.shade400),
          title: const Text('Personalization',
              style: TextStyle(color: Colors.white)),
          onTap: () {
            // Handle personalization logic here
          },
        ),
        ListTile(
          leading: Icon(Icons.help, color: Colors.green.shade400),
          title: const Text('Help & Support',
              style: TextStyle(color: Colors.white)),
          onTap: () {
            // Open external link for help and support
            _launchURL('https://example.com/help_support');
          },
        ),
        ListTile(
          leading: Icon(Icons.description, color: Colors.green.shade400),
          title: const Text('Terms & Conditions',
              style: TextStyle(color: Colors.white)),
          onTap: () {
            // Show terms and conditions in a flying box
            _showTermsAndConditions();
          },
        ),
        ListTile(
          leading: Icon(Icons.info, color: Colors.green.shade400),
          title: const Text('About Us', style: TextStyle(color: Colors.white)),
          onTap: () {
            // Show about us in a flying card
            _showAboutUs();
          },
        ),
      ],
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Terms & Conditions',
              style: TextStyle(color: Colors.white)),
          content: const Text('Your terms and conditions go here.',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.grey[850],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          actions: [
            TextButton(
              child: const Text('Close', style: TextStyle(color: Colors.green)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showAboutUs() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About Us', style: TextStyle(color: Colors.white)),
          content: const Text('A brief summary about us goes here.',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.grey[850],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          actions: [
            TextButton(
              child: const Text('Close', style: TextStyle(color: Colors.green)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

//BOTTOM NAVIGATION BAR_____________________________________________________________________________________________________________________________________________________________________//
  Widget _buildBottomNavigationBar() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double bottomBarWidth = screenWidth * 0.95;

    return BottomAppBar(
      height: 110,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      color: Colors.transparent,
      child: Container(
        width: bottomBarWidth,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(100),
            bottom: Radius.circular(100),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 30,
          currentIndex: _currentIndex,
          items: [
            _buildNavItem(Icons.home, 'Home', 0),
            _buildNavItem(Icons.sports_tennis_sharp, 'Training', 1),
            _buildNavItem(Icons.more_horiz, 'More', 2),
          ],
          onTap: (index) async {
            setState(() {
              _currentIndex = index;
              _controller.reset();
              _controller.forward();
            });

            // if (index == 1) {
            //   await _onStartSession(); // Wait for _onStartSession to complete
            //   setState(() {
            //     _currentIndex = 0; // Redirect to Home tab
            //   });
            // }
          },
          selectedItemColor: Colors.green.shade200,
          unselectedItemColor: Colors.grey,
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
      IconData icon, String label, int index) {
    return BottomNavigationBarItem(
      icon: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final bool isSelected = _currentIndex == index;
          return Container(
            decoration: BoxDecoration(
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black38.withOpacity(0.5), // Shadow color
                        offset: Offset(0, 8), // Shadow offset
                        blurRadius: 45, // Shadow blur radius
                        spreadRadius: 5, // Shadow spread radius
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: isSelected
                      ? Tween<double>(begin: 1.0, end: 1.2)
                          .animate(_controller)
                          .value
                      : 1.0,
                  child: Icon(icon,
                      color: isSelected ? Colors.green.shade200 : Colors.grey),
                ),
                if (isSelected)
                  AnimatedOpacity(
                    opacity: isSelected ? 1.0 : 0.0,
                    duration: Duration(milliseconds: 300),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5.0),
                      child: Text(
                        label,
                        style: TextStyle(color: Colors.green.shade200),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      label: '',
    );
  }

  void showUserInfo(BuildContext context) async {
    // Get the current user
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // Fetch user info from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        // Extract user data
        String userName = userDoc['name'] ?? 'No name available';
        String userEmail = userDoc['email'] ?? 'No email available';
        String userPhone = userDoc['phone'] ?? 'No phone number available';

        showModalBottomSheet(
          context: context,
          builder: (context) {
            return Container(
              color: Colors.grey.shade900,
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'User Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade100,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading:
                        Icon(Icons.person, color: Colors.greenAccent.shade100),
                    title: Text('Name: $userName',
                        style: const TextStyle(color: Colors.white)),
                  ),
                  ListTile(
                    leading:
                        Icon(Icons.email, color: Colors.greenAccent.shade100),
                    title: Text('Email: $userEmail',
                        style: const TextStyle(color: Colors.white)),
                  ),
                  ListTile(
                    leading:
                        Icon(Icons.phone, color: Colors.greenAccent.shade100),
                    title: Text('Phone: $userPhone',
                        style: const TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      // Sign out the user
                      await FirebaseAuth.instance.signOut();
                      Navigator.of(context).pop(); // Close the modal
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Signed out successfully')),
                      );
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (builder) => const LoginPage()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.white, // Set the text color to white
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User data not found')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user signed in')),
      );
    }
  }
}

class FullCardContentScreen extends StatelessWidget {
  final String title;
  final int value;

  const FullCardContentScreen({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(title),
      ),
      body: Center(
        child: Text(
          '$title: $value%',
          style: const TextStyle(fontSize: 24, color: Colors.green),
        ),
      ),
    );
  }
}

Future<List<String>> loadQuotes() async {
  final rawData = await rootBundle.loadString('assets/quotes.csv');
  final List<List<dynamic>> csvTable =
      const CsvToListConverter().convert(rawData);
  return csvTable.map((row) => row[0] as String).toList();
}

class ProgressCard extends StatelessWidget {
  final List<String> titles = ["Level", "Efficiency"];
  final List<int?> values = [80, 60, 55]; // Example values
  final List<Color> colors = [
    Colors.green.shade400,
    Colors.purple.shade500
  ]; // Colors for each radial bar

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      height: 500,
      child: Card(
        color: Colors.grey[850],
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: SfCircularChart(
                  annotations: <CircularChartAnnotation>[
                    CircularChartAnnotation(
                      widget: Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                  series: <RadialBarSeries<int, String>>[
                    RadialBarSeries<int, String>(
                      dataSource: [values[0] ?? 0],
                      xValueMapper: (_, __) => titles[0],
                      yValueMapper: (int? data, _) => data ?? 0,
                      pointColorMapper: (_, __) => colors[0],
                      radius: '110%',
                      innerRadius: '75%',
                      maximumValue: 100,
                      cornerStyle: CornerStyle.bothCurve,
                    ),
                    RadialBarSeries<int, String>(
                      dataSource: [values[1] ?? 0],
                      xValueMapper: (_, __) => titles[1],
                      yValueMapper: (int? data, _) => data ?? 0,
                      pointColorMapper: (_, __) => colors[1],
                      radius: '72%',
                      innerRadius: '60%',
                      maximumValue: 100,
                      cornerStyle: CornerStyle.bothCurve,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Custom Legend Section with GridView for 2x2 layout
              SizedBox(
                height: 100, // Set a fixed height for the GridView
                child: GridView.builder(
                  shrinkWrap:
                      true, // Ensures it doesn't take up more space than needed
                  physics:
                      NeverScrollableScrollPhysics(), // Disable scrolling in this section
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // Two columns
                    childAspectRatio:
                        3, // Adjust this ratio to fit text beside the box
                    mainAxisSpacing: 0, // Reduced space between rows
                    crossAxisSpacing: 0, // Space between columns
                  ),
                  itemCount: titles.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        // Pass the corresponding value to the new page
                        if (titles[index] == "Level") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LevelPage(values[0] ?? 0),
                            ),
                          );
                        } else if (titles[index] == "Last Session") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  LastSessionAssismentPage(values[1] ?? 0),
                            ),
                          );
                        } else if (titles[index] == "Efficiency") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Efficiency(
                                  value: values[2] ?? 0,
                                  userLevel: values[0] ?? 0),
                            ),
                          );
                        }
                      },
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.start, // Align items to the left
                        children: [
                          Icon(
                            Icons.square_rounded,
                            color: colors[index],
                            size: 30,
                          ),
                          const SizedBox(
                              width: 8), // Space between icon and text
                          Text(
                            titles[index],
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20),
                            textAlign: TextAlign.center,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white
                                  .withOpacity(0.5), // Slight opacity
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
