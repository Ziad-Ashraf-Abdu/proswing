import 'package:flutter/material.dart'; // Syncfusion charts package

class training_tab extends StatefulWidget {
  const training_tab({super.key});

  @override
  _training_tabState createState() => _training_tabState();
}

class _training_tabState extends State<training_tab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initializing Animation Controller for fade-in effect
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    // Start animation when page loads
    _controller.forward();
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
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildLevelSection(),
                  const SizedBox(height: 30),
                  _buildInfoSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLevelSection() {
    return Container(
      child: ListView(
        children: [
          Tab(
            text: "User Name",
            icon: CircleAvatar(
              backgroundColor: Colors.greenAccent.shade100,
              child: const Icon(Icons.person, color: Colors.black),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      color: Colors.grey[850],
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Level Information',
              style: TextStyle(
                color: Colors.green.shade400,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This section contains additional details about your current level and progress milestones.',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 10),
            const Text(
              'Keep up the good work and stay motivated to reach your goals!',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
