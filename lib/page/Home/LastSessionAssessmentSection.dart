import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:proswing/page/Home/Progress/LastSessionAssisment.dart';

class LastSessionAssismentSection extends StatefulWidget {
  final int value; // Keep for backward compatibility, but will use actual data
  const LastSessionAssismentSection(this.value, {Key? key}) : super(key: key);

  @override
  _LastSessionAssismentSectionState createState() =>
      _LastSessionAssismentSectionState();
}

class _LastSessionAssismentSectionState
    extends State<LastSessionAssismentSection>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fadeAnimation;
  Animation<double>? _slideAnimation;
  Future<SessionData>? _sessionDataFuture;

  // Key parameters we want to analyze (same as in LastSessionAssismentPage)
  final List<String> keyParameters = [
    "Left Knee Power(Watts)",
    "Left Knee Torque(Nm)",
    "Cervical Torque(Nm)",
    "Cervical Force(N)",
    "Left Hip Torque(Nm)"
  ];

  // Standard ranges for comparison (same as in LastSessionAssismentPage)
  final Map<String, List<double>> standardRanges = {
    "Left Knee Power(Watts)": [-2477.62793, 2353.145996],
    "Left Knee Torque(Nm)": [0.05497811, 719.8560181],
    "Cervical Torque(Nm)": [0.047000591, 124.5862427],
    "Cervical Force(N)": [17.46109772, 1094.576782],
    "Left Hip Torque(Nm)": [0.876266956, 3227.84375],
  };

  @override
  void initState() {
    super.initState();

    // Initialize Animation Controller for fade-in effect.
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOut,
    );

    _slideAnimation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOutBack,
    );

    // Load session data from latest analysis file
    _sessionDataFuture = loadSessionData();

    // Start the animation when the widget loads.
    _controller?.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<SessionData> loadSessionData() async {
    try {
      File? mostRecentFile = await getMostRecentAnalysisFile();

      if (mostRecentFile == null || !await mostRecentFile.exists()) {
        print("No analysis file found, using default data");
        return getDefaultSessionData();
      }

      final String content = await mostRecentFile.readAsString();
      final List<String> lines = content.split('\n');

      if (lines.isEmpty) {
        return getDefaultSessionData();
      }

      // Parse headers
      List<String> headers = lines[0].split(',').map((h) => h.trim().replaceAll('"', '')).toList();

      // Extract session accuracy
      double sessionAccuracy = 0.0;
      String? sessionAccuracyLine;
      for (int i = lines.length - 1; i >= 0; i--) {
        if (lines[i].trim().isNotEmpty && lines[i].contains('Session Accuracy')) {
          sessionAccuracyLine = lines[i];
          break;
        }
      }

      if (sessionAccuracyLine != null) {
        RegExp regex = RegExp(r'(\d+\.?\d*)%');
        Match? match = regex.firstMatch(sessionAccuracyLine);
        if (match != null) {
          sessionAccuracy = double.parse(match.group(1)!);
        }
      }

      // Process parameter data
      Map<String, List<double>> parameterValues = {};
      Map<String, ParameterStats> parameterStats = {};

      // Initialize parameter value lists
      for (String param in keyParameters) {
        parameterValues[param] = [];
      }

      // Parse data rows (skip header and last session accuracy line)
      for (int i = 1; i < lines.length - 1; i++) {
        String line = lines[i].trim();
        if (line.isEmpty || line.contains('Session Accuracy')) continue;

        List<String> values = line.split(',');
        if (values.length >= headers.length) {
          for (String paramName in keyParameters) {
            int paramIndex = headers.indexOf(paramName);
            if (paramIndex != -1 && paramIndex < values.length) {
              try {
                double value = double.parse(values[paramIndex].trim());
                parameterValues[paramName]!.add(value);
              } catch (e) {
                // Skip invalid values
              }
            }
          }
        }
      }

      // Calculate statistics for each parameter
      for (String paramName in keyParameters) {
        List<double> values = parameterValues[paramName]!;
        if (values.isNotEmpty) {
          values.sort();
          double min = values.first;
          double max = values.last;
          double average = values.reduce((a, b) => a + b) / values.length;

          // Calculate performance score (0-100) based on how well values fit in standard range
          List<double> standardRange = standardRanges[paramName]!;
          double score = calculatePerformanceScore(average, standardRange);

          parameterStats[paramName] = ParameterStats(
            min: min,
            max: max,
            average: average,
            performanceScore: score,
            dataPoints: values.length,
          );
        } else {
          parameterStats[paramName] = ParameterStats(
            min: 0.0,
            max: 0.0,
            average: 0.0,
            performanceScore: 0.0,
            dataPoints: 0,
          );
        }
      }

      return SessionData(
        sessionAccuracy: sessionAccuracy,
        parameterStats: parameterStats,
        fileName: mostRecentFile.path.split('/').last,
        timestamp: mostRecentFile.lastModifiedSync(),
      );

    } catch (e) {
      print("Error loading session data: $e");
      return getDefaultSessionData();
    }
  }

  double calculatePerformanceScore(double value, List<double> standardRange) {
    double min = standardRange[0];
    double max = standardRange[1];

    if (value >= min && value <= max) {
      // Value is within standard range, score based on how centered it is
      double center = (min + max) / 2;
      double range = max - min;
      double distanceFromCenter = (value - center).abs();
      double normalizedDistance = distanceFromCenter / (range / 2);
      return (100 * (1 - normalizedDistance)).clamp(60, 100); // Min 60% if in range
    } else {
      // Value is outside range, score based on how far outside
      double distance = value < min ? (min - value) : (value - max);
      double range = max - min;
      double penalty = (distance / range) * 50; // Penalty factor
      return (60 - penalty).clamp(0, 60); // Max 60% if outside range
    }
  }

  SessionData getDefaultSessionData() {
    Map<String, ParameterStats> defaultStats = {};
    for (String param in keyParameters) {
      defaultStats[param] = ParameterStats(
        min: 0.0,
        max: 100.0,
        average: 50.0,
        performanceScore: 75.0,
        dataPoints: 10,
      );
    }

    return SessionData(
      sessionAccuracy: 85.0,
      parameterStats: defaultStats,
      fileName: "default_session.csv",
      timestamp: DateTime.now(),
    );
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

  String _getShortParameterName(String fullName) {
    Map<String, String> shortNames = {
      "Left Knee Power(Watts)": "L Knee Power",
      "Left Knee Torque(Nm)": "L Knee Torque",
      "Cervical Torque(Nm)": "Cervical Torque",
      "Cervical Force(N)": "Cervical Force",
      "Left Hip Torque(Nm)": "L Hip Torque",
    };
    return shortNames[fullName] ?? fullName;
  }

  @override
  Widget build(BuildContext context) {
    return _fadeAnimation != null ? FadeTransition(
      opacity: _fadeAnimation!,
      child: FutureBuilder<SessionData>(
        future: _sessionDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingCard();
          }

          // Handle error case or null data
          if (snapshot.hasError) {
            print("Error loading session data: ${snapshot.error}");
          }

          SessionData sessionData = snapshot.data ?? getDefaultSessionData();

          return Column(
            children: [
              _buildSessionOverviewCard(sessionData),
              const SizedBox(height: 16),
              _buildPerformanceMetricsCard(sessionData),
              const SizedBox(height: 16),
              _buildImprovementTipsCard(sessionData),
            ],
          );
        },
      ),
    ) : FutureBuilder<SessionData>(
      future: _sessionDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        SessionData sessionData = snapshot.data ?? getDefaultSessionData();

        return Column(
          children: [
            _buildSessionOverviewCard(sessionData),
            const SizedBox(height: 16),
            _buildPerformanceMetricsCard(sessionData),
            const SizedBox(height: 16),
            _buildImprovementTipsCard(sessionData),
          ],
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[850]!.withOpacity(0.3),
            Colors.grey[800]!.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 3,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.green,
          strokeWidth: 4.0,
        ),
      ),
    );
  }

  /// Modern session overview card with circular progress
  Widget _buildSessionOverviewCard(SessionData sessionData) {
    double percentage = sessionData.sessionAccuracy / 100.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LastSessionAssismentPage(sessionData.sessionAccuracy.round()),
          ),
        );
      },
      child: Container(
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
        child: Row(
          children: [
            // Circular Progress Chart
            SizedBox(
              width: 100,
              height: 100,
              child: SfCircularChart(
                annotations: <CircularChartAnnotation>[
                  CircularChartAnnotation(
                    widget: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${sessionData.sessionAccuracy.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Accuracy',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                series: <CircularSeries<double, String>>[
                  RadialBarSeries<double, String>(
                    maximumValue: 1,
                    radius: '150%',
                    innerRadius: '70%',
                    dataSource: [percentage],
                    cornerStyle: CornerStyle.bothCurve,
                    xValueMapper: (double data, _) => '',
                    yValueMapper: (double data, _) => data,
                    pointColorMapper: (double data, _) {
                      if (data >= 0.8) return Colors.green;
                      if (data >= 0.6) return Colors.orange;
                      return Colors.red;
                    },
                    trackColor: Colors.grey.shade800,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Session Information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Session Performance",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${sessionData.fileName}",
                    style: TextStyle(
                      color: Colors.blue.shade300,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${sessionData.timestamp.day}/${sessionData.timestamp.month}/${sessionData.timestamp.year}",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getAccuracyColor(sessionData.sessionAccuracy).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getAccuracyColor(sessionData.sessionAccuracy).withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      _getAccuracyLabel(sessionData.sessionAccuracy),
                      style: TextStyle(
                        color: _getAccuracyColor(sessionData.sessionAccuracy),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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

  /// Modern performance metrics card with horizontal bars
  Widget _buildPerformanceMetricsCard(SessionData sessionData) {
    List<_MetricData> metrics = keyParameters.take(3).map((param) {
      ParameterStats stats = sessionData.parameterStats[param]!;
      String shortName = _getShortParameterName(param);
      return _MetricData(shortName, stats.performanceScore);
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.1),
            Colors.teal.withOpacity(0.1),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green, Colors.teal]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.assessment_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                "Key Metrics",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...metrics.map((metric) => _buildMetricRow(metric)),
        ],
      ),
    );
  }

  Widget _buildMetricRow(_MetricData metric) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                metric.metric,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${metric.value.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: _getScoreColor(metric.value),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: metric.value / 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getScoreColor(metric.value),
                      _getScoreColor(metric.value).withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Modern improvement tips card
  Widget _buildImprovementTipsCard(SessionData sessionData) {
    List<String> improvementAreas = [];
    for (String param in keyParameters) {
      double score = sessionData.parameterStats[param]!.performanceScore;
      if (score < 80) {
        improvementAreas.add(_getShortParameterName(param));
      }
    }

    String improvementText = '';
    IconData tipIcon;
    List<Color> gradientColors;

    if (improvementAreas.isEmpty) {
      improvementText = 'Excellent performance across all parameters! Keep maintaining your current form.';
      tipIcon = Icons.emoji_events_rounded;
      gradientColors = [Colors.amber, Colors.orange];
    } else {
      improvementText = 'Focus areas: ${improvementAreas.join(', ')}';
      tipIcon = Icons.trending_up_rounded;
      gradientColors = [Colors.orange, Colors.red];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors.map((c) => c.withOpacity(0.1)).toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gradientColors.first.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.1),
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
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  tipIcon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                "Improvement Tips",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            improvementText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.grey[400],
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                "Tap above for detailed analysis",
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 80) return Colors.green;
    if (accuracy >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getAccuracyLabel(double accuracy) {
    if (accuracy >= 80) return "Excellent";
    if (accuracy >= 60) return "Good";
    return "Needs Work";
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}

/// Data model for performance metrics.
class _MetricData {
  final String metric;
  final double value;
  _MetricData(this.metric, this.value);
}