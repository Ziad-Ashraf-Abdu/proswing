import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LastSessionAssismentPage extends StatefulWidget {
  final int value;
  const LastSessionAssismentPage(this.value, {Key? key}) : super(key: key);

  @override
  _LastSessionAssismentPageState createState() =>
      _LastSessionAssismentPageState();
}

class _LastSessionAssismentPageState extends State<LastSessionAssismentPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Future<List<_MetricData>> _metricsFuture;

  @override
  void initState() {
    super.initState();

    // Initialize Animation Controller for fade-in effect
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    // Load metrics from analysis file
    _metricsFuture = loadMetricsFromAnalysis();

    // Start the animation when the page loads
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<_MetricData>> loadMetricsFromAnalysis() async {
    try {
      File? mostRecentFile = await getMostRecentAnalysisFile();

      if (mostRecentFile == null || !await mostRecentFile.exists()) {
        print("No analysis file found, using default metrics");
        return getDefaultMetrics();
      }

      final String data = await mostRecentFile.readAsString();
      final List<String> lines = data.split('\n');

      // Parse metrics from the analysis file
      // Assuming the CSV has columns: metric_name, value
      List<_MetricData> metrics = [];

      for (int i = 1; i < lines.length; i++) {
        final String line = lines[i].trim();
        if (line.isEmpty) continue;

        final List<String> values = line.split(',');
        if (values.length >= 2) {
          final String metricName = values[0].trim();
          final double metricValue = double.tryParse(values[1].trim()) ?? 0.0;

          // Map common metric names to display names
          String displayName = mapMetricName(metricName);
          if (displayName.isNotEmpty) {
            metrics.add(_MetricData(displayName, metricValue));
          }
        }
      }

      return metrics.isEmpty ? getDefaultMetrics() : metrics;
    } catch (e) {
      print("Error loading metrics from analysis: $e");
      return getDefaultMetrics();
    }
  }

  String mapMetricName(String metricName) {
    // Map analysis metric names to user-friendly display names
    switch (metricName.toLowerCase()) {
      case 'speed':
      case 'velocity':
      case 'ball_speed':
        return 'Speed';
      case 'accuracy':
      case 'precision':
      case 'target_accuracy':
        return 'Accuracy';
      case 'consistency':
      case 'stability':
      case 'variation':
        return 'Consistency';
      case 'power':
      case 'force':
        return 'Power';
      case 'spin':
      case 'rotation':
        return 'Spin';
      case 'angle':
      case 'trajectory':
        return 'Angle';
      default:
        return metricName.replaceAll('_', ' ').toUpperCase();
    }
  }

  List<_MetricData> getDefaultMetrics() {
    // Default metrics when no analysis file is available
    return [
      _MetricData("Speed", 80),
      _MetricData("Accuracy", 70),
      _MetricData("Consistency", 90),
    ];
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
      appBar: AppBar(
        title: const Text("Last Session Assessment"),
        backgroundColor: Colors.grey[900],
      ),
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
                  _buildAssessmentHeader(),
                  const SizedBox(height: 20),
                  _buildLevelSection(widget.value),
                  const SizedBox(height: 20),
                  _buildPerformanceMetrics(),
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

  /// Builds a header for the assessment section.
  Widget _buildAssessmentHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        "Last Session Assessment",
        style: TextStyle(
          color: Colors.green.shade400,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Displays the level progress using a radial bar chart.
  Widget _buildLevelSection(int value) {
    double percentage = value / 100.0; // Convert value to percentage

    return Card(
      color: Colors.transparent,
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SfCircularChart(
              annotations: <CircularChartAnnotation>[
                CircularChartAnnotation(
                  widget: Text(
                    '${(percentage * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              series: <CircularSeries>[
                RadialBarSeries<int, String>(
                  maximumValue: 1, // Maximum value represents 100%
                  radius: '75%',
                  dataSource: [value],
                  cornerStyle: CornerStyle.bothCurve,
                  xValueMapper: (int data, _) => '',
                  yValueMapper: (int data, _) => percentage,
                  pointColorMapper: (int data, _) => Colors.pinkAccent.shade700,
                  trackColor: Colors.grey.shade700,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Level Progress',
              style: TextStyle(
                color: Colors.green.shade400,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You have reached ${(percentage * 100).toStringAsFixed(0)}% of your current level. Keep pushing to reach the next level!',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays additional performance metrics in a bar chart.
  Widget _buildPerformanceMetrics() {
    return Card(
      color: Colors.grey[850],
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Metrics',
              style: TextStyle(
                color: Colors.green.shade400,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<_MetricData>>(
              future: _metricsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading metrics: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No metrics available',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final List<_MetricData> metrics = snapshot.data!;
                return SfCartesianChart(
                  primaryXAxis: CategoryAxis(
                    majorGridLines: const MajorGridLines(width: 0),
                  ),
                  primaryYAxis: NumericAxis(
                    minimum: 0,
                    maximum: 100,
                    interval: 20,
                    majorGridLines: const MajorGridLines(width: 0),
                  ),
                  series: <CartesianSeries<_MetricData, String>>[
                    ColumnSeries<_MetricData, String>(
                      dataSource: metrics,
                      xValueMapper: (_MetricData data, _) => data.metric,
                      yValueMapper: (_MetricData data, _) => data.value,
                      dataLabelSettings: const DataLabelSettings(isVisible: true),
                      color: Colors.blueAccent,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Displays a tips/info section for improvements.
  Widget _buildInfoSection() {
    return Card(
      color: Colors.grey[850],
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Improvement Tips',
              style: TextStyle(
                color: Colors.green.shade400,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<_MetricData>>(
              future: _metricsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  // Generate tips based on actual metrics
                  List<_MetricData> metrics = snapshot.data!;
                  _MetricData? lowestMetric = metrics.reduce((a, b) => a.value < b.value ? a : b);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Based on your latest session analysis, focus on improving your ${lowestMetric.metric.toLowerCase()} (${lowestMetric.value.toStringAsFixed(1)}%).',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Review your performance metrics and work on improving areas where you lag behind. Consistent practice will help you reach your goals!',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  );
                } else {
                  return const Text(
                    'Review your performance metrics and work on improving areas where you lag behind. Focus on increasing your speed and consistency while maintaining high accuracy.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            const Text(
              'Keep up the good work – every session is an opportunity to grow and improve!',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data model for performance metrics.
class _MetricData {
  final String metric;
  final double value;
  _MetricData(this.metric, this.value);
}