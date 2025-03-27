import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart'; // Syncfusion charts package
import 'package:proswing/page/Home/Progress/LastSessionAssisment.dart';

class LastSessionAssismentSection extends StatefulWidget {
  final int value; // Level percentage (0-100)
  const LastSessionAssismentSection(this.value, {Key? key}) : super(key: key);

  @override
  _LastSessionAssismentSectionState createState() =>
      _LastSessionAssismentSectionState();
}

class _LastSessionAssismentSectionState
    extends State<LastSessionAssismentSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  // Dummy metric data for the performance section.
  final List<_MetricData> _metrics = [
    _MetricData("Speed", 80),
    _MetricData("Accuracy", 70),
    _MetricData("Consistency", 90),
  ];

  @override
  void initState() {
    super.initState();

    // Initialize Animation Controller for fade-in effect.
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    // Start the animation when the widget loads.
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double percentage = widget.value / 100.0;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildLevelSection(percentage),
            const SizedBox(height: 20),
            _buildPerformanceMetrics(),
            const SizedBox(height: 20),
            _buildSessionDetails(),
            const SizedBox(height: 20),
            _buildImprovementTips(),
          ],
        ),
      ),
    );
  }

  /// Builds the header with title and a brief summary.
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    LastSessionAssismentPage(75), // Pass an appropriate value
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Last Session Assessment",
                style: TextStyle(
                  color: Colors.green.shade400,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.green.shade400,
                size: 30,
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          "A comprehensive analysis of your performance in the last session.",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ],
    );
  }

  /// Builds the circular level progress chart.
  Widget _buildLevelSection(double percentage) {
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
              series: <CircularSeries<int, String>>[
                RadialBarSeries<int, String>(
                  maximumValue: 1, // 100% represented as 1.
                  radius: '75%',
                  dataSource: [widget.value],
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
              'You have reached ${(percentage * 100).toStringAsFixed(0)}% of your current level. Keep pushing to reach the next milestone!',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a bar chart displaying performance metrics.
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
                  color: Colors.deepPurple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a session details section that shows a summary of the session.
  Widget _buildSessionDetails() {
    return Card(
      color: Colors.grey[900],
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Session Details',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Your session was marked by steady performance with room for improvement in consistency. Focus on maintaining high accuracy while increasing speed. Detailed logs and metrics have been recorded for further analysis.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the improvement tips section.
  Widget _buildImprovementTips() {
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
              '• Review your performance metrics regularly.\n'
              '• Focus on increasing your speed and consistency.\n'
              '• Analyze session logs for specific areas of improvement.\n'
              '• Stay motivated and keep practicing!',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a call-to-action button for further review.
}

/// Data model for performance metrics.
class _MetricData {
  final String metric;
  final double value;
  _MetricData(this.metric, this.value);
}
