import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart'; // Syncfusion charts package

class LevelPage extends StatefulWidget {
  final int value;

  const LevelPage(this.value, {super.key});

  @override
  _LevelPageState createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage>
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
                  _buildLevelSection(widget.value),
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

  // Function to get the user status based on level
  String _getUserStatus(double level) {
    if (level < 4) {
      return 'Beginner'; // Level below 4
    } else if (level < 7) {
      return 'Intermediate'; // Level between 4 and 6
    } else {
      return 'Advanced'; // Level 7 and above
    }
  }

  Widget _buildLevelSection(int value) {
    double level = value / 10; // Convert value to a scale of 10

    // Get the status message based on the level
    String status = _getUserStatus(level);

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center, // Center column contents vertically
        crossAxisAlignment:
            CrossAxisAlignment.center, // Center column contents horizontally
        children: [
          Text(
            'Level Progress - $status',
            style: TextStyle(
              color: Colors.green.shade400,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Center(
            // Using Syncfusion's radial chart to replace CircularPercentIndicator
            child: SfCircularChart(
              annotations: <CircularChartAnnotation>[
                CircularChartAnnotation(
                  widget: Text(
                    '${level.toStringAsFixed(0)}/10',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              series: <CircularSeries>[
                RadialBarSeries<int, String>(
                  maximumValue: 10, // Set the maximum value to 10
                  radius: '80%',
                  dataSource: [value],
                  cornerStyle: CornerStyle.bothCurve,
                  xValueMapper: (int data, _) => '',
                  yValueMapper: (int data, _) =>
                      level, // Progress in scale of 10
                  pointColorMapper: (int data, _) => Colors.green.shade400,
                  trackColor: Colors.grey.shade700, // Track background color
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'You have reached level $level out of 10. Keep pushing to reach the next level!',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      color: Colors.grey[850],
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tips',
              style: TextStyle(
                color: Colors.green.shade400,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This section contains additional details about your serve and progress milestones, and tips to improve your level.',
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
