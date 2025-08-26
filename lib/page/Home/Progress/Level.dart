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
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Future<LevelAnalysisData> _levelDataFuture;

  // Key parameters for level calculation
  final List<String> keyParameters = [
    "Left Knee Power(Watts)",
    "Left Knee Torque(Nm)",
    "Cervical Torque(Nm)",
    "Cervical Force(N)",
    "Left Hip Torque(Nm)"
  ];

  // Standard ranges for parameters
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
    _levelDataFuture = loadLevelAnalysisData();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // Stagger the animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<LevelAnalysisData> loadLevelAnalysisData() async {
    try {
      List<File> latestFiles = await getLatestAnalysisFiles(4);

      if (latestFiles.isEmpty) {
        print("No analysis files found, using default level");
        return LevelAnalysisData(
          level: widget.value / 10.0,
          sessionAccuracy: widget.value.toDouble(),
          parameterScores: {},
          improvementAreas: [],
        );
      }

      double totalSessionAccuracy = 0.0;
      int validSessions = 0;
      Map<String, List<double>> allParameterValues = {};

      for (File file in latestFiles) {
        try {
          String content = await file.readAsString();
          List<String> lines = content.split('\n');

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
              double accuracy = double.parse(match.group(1)!);
              totalSessionAccuracy += accuracy;
              validSessions++;
            }
          }

          if (lines.isNotEmpty) {
            List<String> headers = lines[0].split(',').map((h) => h.trim().replaceAll('"', '')).toList();

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
                      if (!allParameterValues.containsKey(paramName)) {
                        allParameterValues[paramName] = [];
                      }
                      allParameterValues[paramName]!.add(value);
                    } catch (e) {}
                  }
                }
              }
            }
          }
        } catch (e) {
          print("Error processing file ${file.path}: $e");
        }
      }

      double averageSessionAccuracy = validSessions > 0 ? totalSessionAccuracy / validSessions : widget.value.toDouble();

      Map<String, double> parameterScores = {};
      List<String> improvementAreas = [];

      for (String paramName in keyParameters) {
        if (allParameterValues.containsKey(paramName) && allParameterValues[paramName]!.isNotEmpty) {
          List<double> values = allParameterValues[paramName]!;
          List<double> standardRange = standardRanges[paramName]!;

          double score = calculateParameterScore(values, standardRange);
          parameterScores[paramName] = score;

          if (score < 60) {
            improvementAreas.add(paramName);
          }
        }
      }

      double overallLevel = calculateOverallLevel(averageSessionAccuracy, parameterScores);

      return LevelAnalysisData(
        level: overallLevel,
        sessionAccuracy: averageSessionAccuracy,
        parameterScores: parameterScores,
        improvementAreas: improvementAreas,
      );

    } catch (e) {
      print("Error loading level analysis data: $e");
      return LevelAnalysisData(
        level: widget.value / 10.0,
        sessionAccuracy: widget.value.toDouble(),
        parameterScores: {},
        improvementAreas: [],
      );
    }
  }

  double calculateParameterScore(List<double> userValues, List<double> standardRange) {
    if (userValues.isEmpty) return 0.0;

    double standardMin = standardRange[0];
    double standardMax = standardRange[1];
    double standardMid = (standardMin + standardMax) / 2;
    double standardRange_width = standardMax - standardMin;

    double totalScore = 0.0;
    for (double value in userValues) {
      if (value >= standardMin && value <= standardMax) {
        double distanceFromMid = (value - standardMid).abs();
        double normalizedDistance = distanceFromMid / (standardRange_width / 2);
        totalScore += (1.0 - normalizedDistance) * 100;
      } else {
        double distanceOutside = value < standardMin ?
        (standardMin - value) : (value - standardMax);
        double penalty = (distanceOutside / standardRange_width) * 50;
        totalScore += (50 - penalty).clamp(0, 50);
      }
    }

    return totalScore / userValues.length;
  }

  double calculateOverallLevel(double sessionAccuracy, Map<String, double> parameterScores) {
    double sessionWeight = 0.7;
    double parameterWeight = 0.3;

    double averageParameterScore = 0.0;
    if (parameterScores.isNotEmpty) {
      double totalParameterScore = parameterScores.values.reduce((a, b) => a + b);
      averageParameterScore = totalParameterScore / parameterScores.length;
    }

    double combinedScore = (sessionAccuracy * sessionWeight) + (averageParameterScore * parameterWeight);
    return (combinedScore / 10).clamp(0, 10);
  }

  Future<List<File>> getLatestAnalysisFiles(int count) async {
    try {
      Directory appDir = await getApplicationSupportDirectory();
      Directory hiddenDir = Directory('${appDir.path}/.analysis_results');

      if (!await hiddenDir.exists()) {
        return [];
      }

      List<FileSystemEntity> files = await hiddenDir.list().toList();
      List<File> csvFiles = files
          .whereType<File>()
          .where((file) => file.path.endsWith('.csv'))
          .toList();

      if (csvFiles.isEmpty) {
        return [];
      }

      csvFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return csvFiles.take(count).toList();
    } catch (e) {
      print("Error getting latest analysis files: $e");
      return [];
    }
  }

  String _getUserStatus(double level) {
    if (level < 4) {
      return 'Beginner';
    } else if (level < 7) {
      return 'Intermediate';
    } else {
      return 'Advanced';
    }
  }

  Color _getLevelColor(double level) {
    if (level < 4) {
      return Colors.red.shade400;
    } else if (level < 7) {
      return Colors.orange.shade400;
    } else {
      return Colors.green.shade400;
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
                      "Level Progress",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 44),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      FutureBuilder<LevelAnalysisData>(
                        future: _levelDataFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return _buildLoadingState();
                          } else if (snapshot.hasError) {
                            return _buildLevelSection(LevelAnalysisData(
                              level: widget.value / 10.0,
                              sessionAccuracy: widget.value.toDouble(),
                              parameterScores: {},
                              improvementAreas: [],
                            ));
                          } else {
                            return _buildLevelSection(snapshot.data!);
                          }
                        },
                      ),
                      const SizedBox(height: 30),
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildParameterScoresSection(),
                      ),
                      const SizedBox(height: 30),
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildInfoSection(),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                color: Colors.blue,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Analyzing your performance...",
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

  Widget _buildLevelSection(LevelAnalysisData levelData) {
    double level = levelData.level;
    String status = _getUserStatus(level);
    Color levelColor = _getLevelColor(level);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              levelColor.withOpacity(0.1),
              levelColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: levelColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: levelColor.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [levelColor, levelColor.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: levelColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                status.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Level Progress',
              style: TextStyle(
                color: levelColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Based on Recent Session Analysis',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 20),

            // Circular progress with modern styling
            Container(
              width: 200,
              height: 200,
              child: SfCircularChart(
                annotations: <CircularChartAnnotation>[
                  CircularChartAnnotation(
                    widget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${level.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          '/10',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${levelData.sessionAccuracy.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: Colors.blue.shade300,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                series: <CircularSeries>[
                  RadialBarSeries<double, String>(
                    maximumValue: 10,
                    radius: '85%',
                    innerRadius: '70%',
                    dataSource: [level],
                    cornerStyle: CornerStyle.bothCurve,
                    xValueMapper: (double data, _) => '',
                    yValueMapper: (double data, _) => data,
                    pointColorMapper: (double data, _) => levelColor,
                    trackColor: Colors.grey.shade800,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'You have reached level ${level.toStringAsFixed(1)} out of 10 based on your recent performance analysis.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Your level combines session accuracy (70%) and biomechanical parameter analysis (30%).',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blue.shade300,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterScoresSection() {
    return FutureBuilder<LevelAnalysisData>(
      future: _levelDataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.parameterScores.isEmpty) {
          return const SizedBox.shrink();
        }

        final parameterScores = snapshot.data!.parameterScores;
        List<ParameterScoreData> chartData = [];

        parameterScores.forEach((param, score) {
          chartData.add(ParameterScoreData(
            _getShortParameterName(param),
            score,
          ));
        });

        return Container(
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
            borderRadius: BorderRadius.circular(24),
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
                      gradient: LinearGradient(
                        colors: [Colors.purple, Colors.blue],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Parameter Performance',
                    style: TextStyle(
                      color: Colors.purple.shade300,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                height: 280,
                child: SfCartesianChart(
                  primaryXAxis: CategoryAxis(
                    labelRotation: -45,
                    labelIntersectAction: AxisLabelIntersectAction.multipleRows,
                    majorGridLines: MajorGridLines(width: 0),
                    axisLine: AxisLine(width: 0),
                  ),
                  primaryYAxis: NumericAxis(
                    minimum: 0,
                    maximum: 100,
                    interval: 20,
                    majorGridLines: MajorGridLines(
                      width: 0.5,
                      color: Colors.grey.withOpacity(0.2),
                    ),
                    axisLine: AxisLine(width: 0),
                  ),
                  plotAreaBorderWidth: 0,
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CartesianSeries>[
                    ColumnSeries<ParameterScoreData, String>(
                      dataSource: chartData,
                      xValueMapper: (ParameterScoreData data, _) => data.parameter,
                      yValueMapper: (ParameterScoreData data, _) => data.score,
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        textStyle: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                      pointColorMapper: (ParameterScoreData data, _) =>
                      data.score >= 70 ? Colors.green :
                      data.score >= 50 ? Colors.orange : Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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

  Widget _buildInfoSection() {
    return Container(
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.teal.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.1),
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
                  gradient: LinearGradient(
                    colors: [Colors.teal, Colors.green],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Level Analysis & Tips',
                style: TextStyle(
                  color: Colors.teal.shade300,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<LevelAnalysisData>(
            future: _levelDataFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                LevelAnalysisData levelData = snapshot.data!;
                String status = _getUserStatus(levelData.level);

                String tips = '';
                switch (status) {
                  case 'Beginner':
                    tips = 'Focus on building fundamental biomechanical patterns and consistency. Work on proper form and technique development.';
                    break;
                  case 'Intermediate':
                    tips = 'Refine your technique and work on parameter optimization. Focus on reducing variation in your key performance metrics.';
                    break;
                  case 'Advanced':
                    tips = 'Fine-tune your biomechanical efficiency and work on consistency under varying conditions. Focus on peak performance optimization.';
                    break;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'As a $status level player, $tips',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (levelData.improvementAreas.isNotEmpty) ...[
                      Text(
                        'Focus on improving these parameters:',
                        style: TextStyle(
                          color: Colors.orange.shade300,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...levelData.improvementAreas.map((area) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                              Icons.trending_up_rounded,
                              color: Colors.orange.shade300,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getShortParameterName(area),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 20),
                    ],
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_rounded,
                            color: Colors.blue.shade300,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your level combines session accuracy (70%) and biomechanical parameter performance (30%). Keep practicing to see continued improvement!',
                              style: TextStyle(
                                color: Colors.blue.shade300,
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
                return const Text(
                  'Your level is calculated based on comprehensive analysis of your performance metrics and biomechanical parameters.',
                  style: TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Data model for level analysis
class LevelAnalysisData {
  final double level;
  final double sessionAccuracy;
  final Map<String, double> parameterScores;
  final List<String> improvementAreas;

  LevelAnalysisData({
    required this.level,
    required this.sessionAccuracy,
    required this.parameterScores,
    required this.improvementAreas,
  });
}

/// Data model for parameter scores chart
class ParameterScoreData {
  final String parameter;
  final double score;

  ParameterScoreData(this.parameter, this.score);
}