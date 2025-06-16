import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
  late Future<int> _adjustedLevelFuture;

  @override
  void initState() {
    super.initState();

    // Initializing Animation Controller for fade-in effect
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    // Load adjusted level from analysis
    _adjustedLevelFuture = loadAdjustedLevel();

    // Start animation when page loads
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<int> loadAdjustedLevel() async {
    try {
      File? mostRecentFile = await getMostRecentAnalysisFile();

      if (mostRecentFile == null || !await mostRecentFile.exists()) {
        print("No analysis file found, using default level");
        return widget.value;
      }

      final String data = await mostRecentFile.readAsString();
      final List<String> lines = data.split('\n');

      // Look for level-related metrics in the analysis file
      double totalScore = 0.0;
      int metricCount = 0;

      for (int i = 1; i < lines.length; i++) {
        final String line = lines[i].trim();
        if (line.isEmpty) continue;

        final List<String> values = line.split(',');
        if (values.length >= 2) {
          final String metricName = values[0].trim().toLowerCase();
          final double metricValue = double.tryParse(values[1].trim()) ?? 0.0;

          // Consider metrics that contribute to overall level
          if (isLevelRelevantMetric(metricName)) {
            totalScore += metricValue;
            metricCount++;
          }
        }
      }

      if (metricCount > 0) {
        // Calculate average score and convert to level (0-100 scale)
        double averageScore = totalScore / metricCount;
        int adjustedLevel = (averageScore * 100 / 100).round().clamp(0, 100);
        return adjustedLevel;
      }

      return widget.value;
    } catch (e) {
      print("Error loading adjusted level: $e");
      return widget.value;
    }
  }

  bool isLevelRelevantMetric(String metricName) {
    // Define which metrics contribute to overall level calculation
    List<String> relevantMetrics = [
      'speed', 'velocity', 'ball_speed',
      'accuracy', 'precision', 'target_accuracy',
      'consistency', 'stability',
      'power', 'force',
      'technique', 'form',
      'overall_score', 'total_score'
    ];

    return relevantMetrics.any((metric) => metricName.contains(metric));
  }

  Future<File?> getMostRecentAnalysisFile() async {
    try {
      Directory appDir = await getApplicationSupportDirectory();
      Directory hiddenDir = Directory('${appDir.path}/.analysis_results');

      if (!await hiddenDir.exists()) {
        return null;
      }

      List<FileSystemEntity> files = await hiddenDir.list().toList();

      // Filter CSV files and sort by modification time
      List<File> csvFiles = files
          .whereType<File>()
          .where((file) => file.path.endsWith('.csv'))
          .toList();

      if (csvFiles.isEmpty) {
        return null;
      }

      // Sort by modification time (most recent first)
      csvFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      return csvFiles.first;
    } catch (e) {
      print("Error getting most recent analysis file: $e");
      return null;
    }
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
                  FutureBuilder<int>(
                    future: _adjustedLevelFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return _buildLevelSection(widget.value);
                      } else {
                        int adjustedLevel = snapshot.data ?? widget.value;
                        return _buildLevelSection(adjustedLevel);
                      }
                    },
                  ),
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
            'You have reached level ${level.toStringAsFixed(1)} out of 10. Keep pushing to reach the next level!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 10),
          FutureBuilder<int>(
            future: _adjustedLevelFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != widget.value) {
                return Text(
                  'Level updated based on your latest analysis results!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blue.shade300,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
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
            FutureBuilder<int>(
              future: _adjustedLevelFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  double level = snapshot.data! / 10;
                  String status = _getUserStatus(level);

                  String tips = '';
                  switch (status) {
                    case 'Beginner':
                      tips = 'Focus on building fundamental skills and consistency. Practice basic techniques regularly and don\'t rush your progress.';
                      break;
                    case 'Intermediate':
                      tips = 'Work on refining your technique and increasing accuracy. Start incorporating more advanced strategies into your practice.';
                      break;
                    case 'Advanced':
                      tips = 'Fine-tune your performance and work on consistency under pressure. Focus on mental game and strategic play.';
                      break;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'As a $status level player, $tips',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Your level is automatically updated based on your latest session analysis. Keep practicing to see continued improvement!',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  );
                } else {
                  return const Text(
                    'This section contains additional details about your serve and progress milestones, and tips to improve your level.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  );
                }
              },
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