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
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Future<SessionData> _sessionDataFuture;

  // Key parameters we want to analyze
  final List<String> keyParameters = [
    "Left Knee Power(Watts)",
    "Left Knee Torque(Nm)",
    "Cervical Torque(Nm)",
    "Cervical Force(N)",
    "Left Hip Torque(Nm)"
  ];

  // Standard ranges for comparison
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
    _setupAnimations();
    _sessionDataFuture = loadSessionData();
    _startAnimations();
  }

  void _setupAnimations() {
    // Fade animation for main content
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Pulse animation for scores
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Slide animation for cards
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _startAnimations() {
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      _pulseController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Modern header
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      "Session Assessment",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 44), // Balance the back button
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSessionOverview(),
                        const SizedBox(height: 24),
                        _buildPerformanceMetrics(),
                        const SizedBox(height: 24),
                        _buildDetailedAnalysis(),
                        const SizedBox(height: 24),
                        _buildInfoSection(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Displays session overview with accuracy
  Widget _buildSessionOverview() {
    return FutureBuilder<SessionData>(
      future: _sessionDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        SessionData sessionData = snapshot.data ?? getDefaultSessionData();
        double percentage = sessionData.sessionAccuracy / 100.0;

        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
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
                            'Session Accuracy',
                            style: TextStyle(
                              color: Colors.green.shade400,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${sessionData.sessionAccuracy.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Latest Analysis',
                              style: TextStyle(
                                color: Colors.green.shade300,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${sessionData.timestamp.day}/${sessionData.timestamp.month}/${sessionData.timestamp.year}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: SfCircularChart(
                        annotations: <CircularChartAnnotation>[
                          CircularChartAnnotation(
                            widget: Text(
                              '${sessionData.sessionAccuracy.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        series: <CircularSeries>[
                          RadialBarSeries<double, String>(
                            maximumValue: 1,
                            radius: '85%',
                            dataSource: [percentage],
                            cornerStyle: CornerStyle.bothCurve,
                            xValueMapper: (double data, _) => '',
                            yValueMapper: (double data, _) => data,
                            pointColorMapper: (double data, _) => Colors.green,
                            trackColor: Colors.grey.shade800,
                            gap: '5%',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Displays performance metrics in a modern chart.
  Widget _buildPerformanceMetrics() {
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.purple, Colors.blue]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Performance Metrics',
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
          FutureBuilder<SessionData>(
            future: _sessionDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.purple,
                    strokeWidth: 2,
                  ),
                );
              }

              SessionData sessionData = snapshot.data ?? getDefaultSessionData();
              List<_MetricData> metrics = keyParameters.map((param) {
                ParameterStats stats = sessionData.parameterStats[param]!;
                String shortName = _getShortParameterName(param);
                return _MetricData(shortName, stats.performanceScore);
              }).toList();

              return Container(
                height: 300,
                child: SfCartesianChart(
                  backgroundColor: Colors.transparent,
                  plotAreaBorderWidth: 0,
                  primaryXAxis: CategoryAxis(
                    majorGridLines: const MajorGridLines(width: 0),
                    axisLine: const AxisLine(width: 0),
                    labelRotation: -45,
                    labelStyle: TextStyle(color: Colors.grey[400]),
                  ),
                  primaryYAxis: NumericAxis(
                    minimum: 0,
                    maximum: 100,
                    interval: 25,
                    majorGridLines: MajorGridLines(
                      width: 1,
                      color: Colors.grey.withOpacity(0.2),
                      dashArray: [5, 5],
                    ),
                    axisLine: const AxisLine(width: 0),
                    labelStyle: TextStyle(color: Colors.grey[400]),
                  ),
                  series: <CartesianSeries<_MetricData, String>>[
                    ColumnSeries<_MetricData, String>(
                      dataSource: metrics,
                      xValueMapper: (_MetricData data, _) => data.metric,
                      yValueMapper: (_MetricData data, _) => data.value,
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        labelAlignment: ChartDataLabelAlignment.top,
                        textStyle: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      gradient: LinearGradient(
                        colors: [Colors.purple.withOpacity(0.8), Colors.blue.withOpacity(0.8)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      pointColorMapper: (_MetricData data, _) {
                        if (data.value >= 80) return Colors.green;
                        if (data.value >= 60) return Colors.orange;
                        return Colors.red;
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Builds detailed parameter analysis
  Widget _buildDetailedAnalysis() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.teal.withOpacity(0.1),
            Colors.green.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.teal.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.teal, Colors.green]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Detailed Analysis',
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
          FutureBuilder<SessionData>(
            future: _sessionDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.teal,
                    strokeWidth: 2,
                  ),
                );
              }

              SessionData sessionData = snapshot.data ?? getDefaultSessionData();

              return Column(
                children: keyParameters.asMap().entries.map((entry) {
                  int index = entry.key;
                  String param = entry.value;
                  ParameterStats stats = sessionData.parameterStats[param]!;
                  List<double> standardRange = standardRanges[param]!;

                  return TweenAnimationBuilder(
                    duration: Duration(milliseconds: 500 + (index * 100)),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, double value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[900]?.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _getScoreColor(stats.performanceScore).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _getShortParameterName(param),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getScoreColor(stats.performanceScore).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${stats.performanceScore.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          color: _getScoreColor(stats.performanceScore),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatItem(
                                        'Average',
                                        stats.average.toStringAsFixed(2),
                                        Icons.trending_up,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildStatItem(
                                        'Range',
                                        '${stats.min.toStringAsFixed(1)} - ${stats.max.toStringAsFixed(1)}',
                                        Icons.straighten,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildStatItem(
                                        'Points',
                                        '${stats.dataPoints}',
                                        Icons.data_usage,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.grey[400],
          size: 16,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
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

  /// Displays tips/info section for improvements.
  Widget _buildInfoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.withOpacity(0.1),
            Colors.purple.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.indigo.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.indigo, Colors.purple]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Recommendations',
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
          FutureBuilder<SessionData>(
            future: _sessionDataFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                SessionData sessionData = snapshot.data!;

                // Find the parameter with the lowest score
                String? lowestParam;
                double lowestScore = 100.0;

                for (String param in keyParameters) {
                  double score = sessionData.parameterStats[param]!.performanceScore;
                  if (score < lowestScore) {
                    lowestScore = score;
                    lowestParam = param;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (lowestParam != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.priority_high_rounded,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Focus Area: Work on improving your ${_getShortParameterName(lowestParam).toLowerCase()} (${lowestScore.toStringAsFixed(1)}% score).',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Overall session accuracy: ${sessionData.sessionAccuracy.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Parameters with scores above 80% are excellent. Scores between 60-80% need improvement, and below 60% require focused attention.',
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Analyze your biomechanical parameters to identify areas for improvement. Focus on maintaining consistent form and staying within optimal ranges.',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading session data...',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data model for session analysis
class SessionData {
  final double sessionAccuracy;
  final Map<String, ParameterStats> parameterStats;
  final String fileName;
  final DateTime timestamp;

  SessionData({
    required this.sessionAccuracy,
    required this.parameterStats,
    required this.fileName,
    required this.timestamp,
  });
}

/// Statistics for individual parameters
class ParameterStats {
  final double min;
  final double max;
  final double average;
  final double performanceScore;
  final int dataPoints;

  ParameterStats({
    required this.min,
    required this.max,
    required this.average,
    required this.performanceScore,
    required this.dataPoints,
  });
}

/// Data model for performance metrics.
class _MetricData {
  final String metric;
  final double value;
  _MetricData(this.metric, this.value);
}