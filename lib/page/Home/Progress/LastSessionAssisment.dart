import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart'; // Syncfusion charts package

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

  // Dummy metric data for additional performance assessment
  final List<_MetricData> _metrics = [
    _MetricData("Speed", 80),
    _MetricData("Accuracy", 70),
    _MetricData("Consistency", 90),
  ];

  @override
  void initState() {
    super.initState();

    // Initialize Animation Controller for fade-in effect
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    // Start the animation when the page loads
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
            SfCartesianChart(
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
                  dataSource: _metrics,
                  xValueMapper: (_MetricData data, _) => data.metric,
                  yValueMapper: (_MetricData data, _) => data.value,
                  dataLabelSettings: const DataLabelSettings(isVisible: true),
                  color: Colors.blueAccent,
                ),
              ],
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
            const Text(
              'Review your performance metrics and work on improving areas where you lag behind. Focus on increasing your speed and consistency while maintaining high accuracy.',
              style: TextStyle(color: Colors.white, fontSize: 16),
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
