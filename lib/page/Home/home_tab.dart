// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'dart:math';
import 'dart:math' as math;
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:proswing/page/login_page.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class HomeScreenPage extends StatefulWidget {
  const HomeScreenPage({super.key});

  @override
  _HomeScreenPageState createState() => _HomeScreenPageState();
}

class _HomeScreenPageState extends State<HomeScreenPage>
    with TickerProviderStateMixin {
  final values = [75, 60, 55];
  bool isInTeam = false;
  String teamName = "";
  String createdBy = "";
  bool startIsClicked = false;

  late ScrollController _scrollController;
  late String greetingMessage = greetingPhrases[1];
  late bool showGreeting = false;
  int _currentIndex = 0;
  DateTime selectedDay = DateTime.now();
  List<String> quotes = [];
  int currentQuoteIndex = 0;

  final List<String> greetingPhrases = [
    "How's your day?",
    "Penny for your thoughts!",
    "Hopefully, life has been treating you well."
  ];

  // Training tab variables
  bool showOptions = false;
  bool isBottomImageVisible = true;

  // Changed from late to nullable and provide default values
  AnimationController? _fadeController;
  AnimationController? _slideController;
  AnimationController? _pulseController;

  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    showGreeting = true;
    _setupAnimations();
    _loadAndSetQuotes();
    _startQuoteRotation();
    _startGreetingTimer();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController!,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeOutBack,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController!,
      curve: Curves.easeInOut,
    ));

    _fadeController!.forward();
    _slideController!.forward();
    _pulseController!.repeat(reverse: true);
  }

  Future<void> _loadAndSetQuotes() async {
    quotes = await loadQuotes();
    _selectRandomQuote();
    setState(() {});
    _startQuoteRotation();
  }

  void _startGreetingTimer() {
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          showGreeting = false;
          _fadeController?.reset();
          _fadeController?.forward();
        });
      }
    });
  }

  void _selectRandomQuote() {
    final random = Random();
    currentQuoteIndex = random.nextInt(quotes.length);
  }

  void _startQuoteRotation() {
    Future.delayed(const Duration(minutes: 30), () {
      if (mounted) {
        setState(() {
          _selectRandomQuote();
        });
        _fadeController?.reset();
        _fadeController?.forward();
        _startQuoteRotation();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController?.dispose();
    _slideController?.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Modern dark background
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
    return SafeArea(
      child: _fadeAnimation != null ? FadeTransition(
        opacity: _fadeAnimation!,
        child: _slideAnimation != null ? SlideTransition(
          position: _slideAnimation!,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                _buildModernQuoteSection(),
                const SizedBox(height: 40),
                _buildModernSectionTitle("Your Progress"),
                const SizedBox(height: 20),
                _buildModernProgressCards(),
                const SizedBox(height: 30),
                _buildModernLastSessionSection(),
              ],
            ),
          ),
        ) : SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildModernQuoteSection(),
              const SizedBox(height: 40),
              _buildModernSectionTitle("Your Progress"),
              const SizedBox(height: 20),
              _buildModernProgressCards(),
              const SizedBox(height: 30),
              _buildModernLastSessionSection(),
            ],
          ),
        ),
      ) : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildModernQuoteSection(),
            const SizedBox(height: 40),
            _buildModernSectionTitle("Your Progress"),
            const SizedBox(height: 20),
            _buildModernProgressCards(),
            const SizedBox(height: 30),
            _buildModernLastSessionSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernQuoteSection() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: getUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        } else if (snapshot.hasError) {
          return _buildErrorCard('Error fetching user data');
        } else if (!snapshot.hasData || snapshot.data == null) {
          return _buildErrorCard('No user data found');
        } else {
          String userName = snapshot.data!['name'] ?? 'User';

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.1),
                  Colors.blue.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.green.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hi, $userName",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Fixed FadeTransition with proper null check
                      _fadeAnimation != null ? FadeTransition(
                        opacity: _fadeAnimation!,
                        child: Text(
                          showGreeting
                              ? greetingMessage
                              : (quotes.isNotEmpty && currentQuoteIndex < quotes.length)
                              ? quotes[currentQuoteIndex]
                              : 'Loading...',
                          style: TextStyle(
                            color: Colors.green.shade300,
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ) : Text(
                        showGreeting
                            ? greetingMessage
                            : (quotes.isNotEmpty && currentQuoteIndex < quotes.length)
                            ? quotes[currentQuoteIndex]
                            : 'Loading...',
                        style: TextStyle(
                          color: Colors.green.shade300,
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => showUserInfo(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green, Colors.teal],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.green,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.red),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildModernSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -1,
      ),
    );
  }

  Widget _buildModernProgressCards() {
    return _pulseAnimation != null ? AnimatedBuilder(
      animation: _pulseAnimation!,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation!.value,
          child: Container(
            height: 450,
            child: ModernProgressCard(values: values),
          ),
        );
      },
    ) : Container(
      height: 450,
      child: ModernProgressCard(values: values),
    );
  }

  Widget _buildModernLastSessionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.1),
            Colors.blue.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.purple.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.purple, Colors.pink]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                "Last Session Assessment",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LastSessionAssismentSection(55),
        ],
      ),
    );
  }

  // Training Content with Camera Page Style
  Widget _buildTrainingContent() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // Modern header
            Container(
              padding: const EdgeInsets.all(24),
              child: const Text(
                "Training Session",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ),

            // Hero image with modern styling
            const SizedBox(height: 20),
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 1000),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 250,
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.transparent,
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        "assets/image/1738577169848.png",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),

            Expanded(
              child: Center(
                child: showOptions
                    ? _buildModernChoiceButtons()
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Visibility(
        visible: isBottomImageVisible,
        child: GestureDetector(
          onTap: _onBottomImagePressed,
          child: Container(
            margin: const EdgeInsets.all(20),
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.transparent],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.transparent,
                  blurRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                "assets/image/1738577174871.png",
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernChoiceButtons() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Choose Your Training",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Select your preferred training method",
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 40),
          _buildModernOption(
            title: "Camera Analysis",
            description: "AI-powered video analysis",
            icon: Icons.videocam_rounded,
            gradient: [Colors.green, Colors.teal],
            onTap: _openCameraPage,
          ),
          const SizedBox(height: 20),
          _buildModernOption(
            title: "IMU Analysis",
            description: "Motion sensor analysis",
            icon: Icons.sensors_rounded,
            gradient: [Colors.blue, Colors.purple],
            onTap: _openImusPage,
          ),
        ],
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
        padding: const EdgeInsets.all(5),
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

  void _onBottomImagePressed() {
    setState(() {
      isBottomImageVisible = false;
      showOptions = true;
    });
  }

  void _openCameraPage() {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder(
          future: getUserData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const AlertDialog(content: Text('Error fetching user data'));
            } else if (!snapshot.hasData || snapshot.data == null) {
              return const AlertDialog(content: Text('No user data found'));
            } else {
              String userName = snapshot.data!['name'] ?? 'User';
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CameraPage(username: userName),
                  ),
                ).then((_) {
                  setState(() {
                    showOptions = false;
                    isBottomImageVisible = true;
                  });
                });
              });
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
        showOptions = false;
        isBottomImageVisible = true;
      });
    });
  }

  // Modern More Tab
  Widget _buildMoreContent() {
    return SafeArea(
      child: _fadeAnimation != null ? FadeTransition(
        opacity: _fadeAnimation!,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                "Profile & Settings",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 30),
              _buildModernUserCard(),
              const SizedBox(height: 30),
              _buildModernSettingsSection(),
            ],
          ),
        ),
      ) : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              "Profile & Settings",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 30),
            _buildModernUserCard(),
            const SizedBox(height: 30),
            _buildModernSettingsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernUserCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: getUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        } else if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorCard('Error loading user data');
        } else {
          final userData = snapshot.data!;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.1),
                  Colors.purple.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.blue.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.blue, Colors.purple]),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userData['name'] ?? 'User Name',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userData['email'] ?? 'user@example.com',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildUserInfoRow('Phone', userData['phone'] ?? '+123456789', Icons.phone),
                _buildUserInfoRow('Height', '${userData['height'] ?? 0} cm', Icons.height),
                _buildUserInfoRow('Weight', '${userData['weight'] ?? 0} kg', Icons.monitor_weight),
                _buildUserInfoRow('Gender', userData['gender'] ?? 'Unknown', Icons.person_outline),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildUserInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 20),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSettingsSection() {
    final settingsOptions = [
      {'title': 'Modify Profile', 'icon': Icons.edit, 'action': () {}},
      {'title': 'Personalization', 'icon': Icons.settings, 'action': () {}},
      {'title': 'Help & Support', 'icon': Icons.help, 'action': () => _launchURL('https://example.com/help_support')},
      {'title': 'Terms & Conditions', 'icon': Icons.description, 'action': () => _showTermsAndConditions()},
      {'title': 'About Us', 'icon': Icons.info, 'action': () => _showAboutUs()},
      {'title': 'Sign Out', 'icon': Icons.logout, 'action': () => _signOut()},
    ];

    return Column(
      children: settingsOptions.map((option) {
        final isSignOut = option['title'] == 'Sign Out';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: option['action'] as VoidCallback,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSignOut
                    ? Colors.red.withOpacity(0.1)
                    : Colors.grey[800]?.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSignOut
                      ? Colors.red.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    option['icon'] as IconData,
                    color: isSignOut ? Colors.red : Colors.green.shade400,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      option['title'] as String,
                      style: TextStyle(
                        color: isSignOut ? Colors.red : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
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
          ),
        );
      }).toList(),
    );
  }

  // Bottom Navigation Bar with modern style
  Widget _buildBottomNavigationBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[900]!,
            Colors.grey[800]!,
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _currentIndex,
          selectedItemColor: Colors.green.shade300,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: [
            _buildNavItem(Icons.home_rounded, 'Home', 0),
            _buildNavItem(Icons.sports_tennis_rounded, 'Training', 1),
            _buildNavItem(Icons.person_rounded, 'Profile', 2),
          ],
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [Colors.green, Colors.teal])
              : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey,
          size: 24,
        ),
      ),
      label: label,
    );
  }

  // Helper methods
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _showTermsAndConditions() {
    _showModernDialog(
      title: 'Terms & Conditions',
      content: 'Your terms and conditions go here. This is a placeholder text for the actual terms and conditions that users need to agree to.',
      icon: Icons.description_rounded,
    );
  }

  void _showAboutUs() {
    _showModernDialog(
      title: 'About Us',
      content: 'ProSwing is a cutting-edge sports analysis app that helps athletes improve their performance through AI-powered motion analysis and personalized training recommendations.',
      icon: Icons.info_rounded,
    );
  }

  void _showModernDialog({
    required String title,
    required String content,
    required IconData icon,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
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
                    gradient: LinearGradient(colors: [Colors.blue, Colors.purple]),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Close",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  void _signOut() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
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
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Sign Out?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Are you sure you want to sign out of your account?",
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
                        onPressed: () => Navigator.pop(context),
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
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.of(context).pop();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Sign Out",
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

  void showUserInfo(BuildContext context) async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        String userName = userDoc['name'] ?? 'No name available';
        String userEmail = userDoc['email'] ?? 'No email available';
        String userPhone = userDoc['phone'] ?? 'No phone number available';

        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'User Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade300,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoTile(Icons.person, 'Name', userName),
                  _buildInfoTile(Icons.email, 'Email', userEmail),
                  _buildInfoTile(Icons.phone, 'Phone', userPhone),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _signOut();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.green.shade400,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Modern Progress Card Component
class ModernProgressCard extends StatelessWidget {
  final List<int> values;
  final List<String> titles = ["Level", "Efficiency"];
  final List<Color> colors = [
    Colors.green,
    Colors.purple,
  ];

  ModernProgressCard({Key? key, required this.values}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[850]!.withOpacity(0.8),
            Colors.grey[800]!.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: SfCircularChart(
              annotations: <CircularChartAnnotation>[
                CircularChartAnnotation(
                  widget: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.green, Colors.teal]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              series: <RadialBarSeries<int, String>>[
                RadialBarSeries<int, String>(
                  dataSource: [values[0]],
                  xValueMapper: (_, __) => titles[0],
                  yValueMapper: (int data, _) => data,
                  pointColorMapper: (_, __) => colors[0],
                  radius: '110%',
                  innerRadius: '75%',
                  maximumValue: 100,
                  cornerStyle: CornerStyle.bothCurve,
                ),
                RadialBarSeries<int, String>(
                  dataSource: [values[1]],
                  xValueMapper: (_, __) => titles[1],
                  yValueMapper: (int data, _) => data,
                  pointColorMapper: (_, __) => colors[1],
                  radius: '72%',
                  innerRadius: '60%',
                  maximumValue: 100,
                  cornerStyle: CornerStyle.bothCurve,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: titles.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _navigateToDetail(context, index),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors[index].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors[index].withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        color: colors[index],
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          titles[index],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.grey[500],
                        size: 14,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(BuildContext context, int index) {
    if (titles[index] == "Level") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LevelPage(values[0]),
        ),
      );
    } else if (titles[index] == "Efficiency") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Efficiency(
            value: values[1],
            userLevel: values[0],
          ),
        ),
      );
    }
  }
}

// Keep the existing helper functions
Future<List<String>> loadQuotes() async {
  final rawData = await rootBundle.loadString('assets/quotes.csv');
  final List<List<dynamic>> csvTable =
  const CsvToListConverter().convert(rawData);
  return csvTable.map((row) => row[0] as String).toList();
}