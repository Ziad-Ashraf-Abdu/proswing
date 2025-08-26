// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Efficiency extends StatefulWidget {
  final int value; // Passed value into class (progress percentage)
  final int userLevel; // Passed value into class (user level)

  const Efficiency({Key? key, required this.value, required this.userLevel})
      : super(key: key);

  @override
  _EfficiencyState createState() => _EfficiencyState();
}

class _EfficiencyState extends State<Efficiency> with TickerProviderStateMixin {
  late Future<AnalysisData> _analysisDataFuture;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  // Standard ranges for key parameters
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
    _analysisDataFuture = loadAnalysisData();
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

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Stagger the animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _scaleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      _pulseController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<AnalysisData> loadAnalysisData() async {
    try {
      List<File> latestFiles = await getLatestAnalysisFiles(4);

      if (latestFiles.isEmpty) {
        print("No analysis files found");
        return AnalysisData(
          averageEfficiency: 0.0,
          parameterRanges: {},
        );
      }

      double totalEfficiency = 0.0;
      int validFiles = 0;
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
              double efficiency = double.parse(match.group(1)!);
              totalEfficiency += efficiency;
              validFiles++;
            }
          }

          if (lines.isNotEmpty) {
            List<String> headers = lines[0].split(',').map((h) => h.trim().replaceAll('"', '')).toList();

            for (int i = 1; i < lines.length - 1; i++) {
              String line = lines[i].trim();
              if (line.isEmpty || line.contains('Session Accuracy')) continue;

              List<String> values = line.split(',');
              if (values.length >= headers.length) {
                for (String paramName in standardRanges.keys) {
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

      Map<String, List<double>> parameterRanges = {};
      for (String paramName in standardRanges.keys) {
        if (allParameterValues.containsKey(paramName) && allParameterValues[paramName]!.isNotEmpty) {
          List<double> values = allParameterValues[paramName]!;
          values.sort();
          double minValue = values.first;
          double maxValue = values.last;
          parameterRanges[paramName] = [minValue, maxValue];
        } else {
          parameterRanges[paramName] = [0.0, 0.0];
        }
      }

      double averageEfficiency = validFiles > 0 ? totalEfficiency / validFiles : 0.0;

      return AnalysisData(
        averageEfficiency: averageEfficiency,
        parameterRanges: parameterRanges,
      );
    } catch (e) {
      print("Error loading analysis data: $e");
      return AnalysisData(
        averageEfficiency: 0.0,
        parameterRanges: {},
      );
    }
  }

  Future<List<File>> getLatestAnalysisFiles(int count) async {
    try {
      Directory appDir = await getApplicationSupportDirectory();
      Directory hiddenDir = Directory('${appDir.path}/.analysis_results');

      if (!await hiddenDir.exists()) {
        print("Analysis results directory does not exist");
        return [];
      }

      List<FileSystemEntity> files = await hiddenDir.list().toList();
      List<File> csvFiles = files
          .whereType<File>()
          .where((file) => file.path.endsWith('.csv'))
          .toList();

      if (csvFiles.isEmpty) {
        print("No CSV files found in analysis directory");
        return [];
      }

      csvFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return csvFiles.take(count).toList();
    } catch (e) {
      print("Error getting latest analysis files: $e");
      return [];
    }
  }

  String calculateLevel(int userLevel) {
    if (widget.userLevel >= 70) {
      return 'Advanced';
    } else if (widget.userLevel >= 50) {
      return 'Intermediate';
    } else {
      return 'Beginner';
    }
  }

  Color _getEfficiencyColor(double efficiency) {
    if (efficiency >= 80) {
      return Colors.green;
    } else if (efficiency >= 60) {
      return Colors.orange;
    } else {
      return Colors.red;
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
                      "Efficiency Analysis",
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
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: _buildEfficiencySection(),
                      ),
                      const SizedBox(height: 30),
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildChartSection(),
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

  Widget _buildEfficiencySection() {
    return FutureBuilder<AnalysisData>(
      future: _analysisDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        double efficiency = snapshot.hasData ? snapshot.data!.averageEfficiency : 0.0;
        final double percentage = efficiency / 100.0;
        Color efficiencyColor = _getEfficiencyColor(efficiency);

        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      efficiencyColor.withOpacity(0.15),
                      efficiencyColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: efficiencyColor.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: efficiencyColor.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header with icon
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [efficiencyColor, efficiencyColor.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: efficiencyColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.speed_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'EFFICIENCY SCORE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Last 4 Sessions Average',
                      style: TextStyle(
                        color: efficiencyColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Modern circular chart
                    Container(
                      width: 220,
                      height: 220,
                      child: SfCircularChart(
                        annotations: <CircularChartAnnotation>[
                          CircularChartAnnotation(
                            widget: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${efficiency.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  '%',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 18,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: efficiencyColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getEfficiencyLabel(efficiency),
                                    style: TextStyle(
                                      color: efficiencyColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        series: <CircularSeries>[
                          RadialBarSeries<double, String>(
                            maximumValue: 1,
                            radius: '85%',
                            innerRadius: '70%',
                            dataSource: [percentage],
                            cornerStyle: CornerStyle.bothCurve,
                            xValueMapper: (double data, _) => '',
                            yValueMapper: (double data, _) => data,
                            pointColorMapper: (double data, _) => efficiencyColor,
                            trackColor: Colors.grey.shade800,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Your average efficiency across the last 4 sessions is ${efficiency.toStringAsFixed(1)}%.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      _getEfficiencyMessage(efficiency),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: efficiencyColor,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
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

  String _getEfficiencyLabel(double efficiency) {
    if (efficiency >= 80) {
      return 'EXCELLENT';
    } else if (efficiency >= 60) {
      return 'GOOD';
    } else {
      return 'NEEDS IMPROVEMENT';
    }
  }

  String _getEfficiencyMessage(double efficiency) {
    if (efficiency >= 80) {
      return 'Outstanding performance! Keep maintaining this level.';
    } else if (efficiency >= 60) {
      return 'Good progress! Work on consistency for better results.';
    } else {
      return 'Focus on technique and form to improve efficiency.';
    }
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
                color: Colors.purple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                color: Colors.purple,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Calculating efficiency...",
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

  Widget _buildChartSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.1),
            Colors.cyan.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.cyan],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parameter Analysis',
                      style: TextStyle(
                        color: Colors.blue.shade300,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Your Performance vs Standard Ranges',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<AnalysisData>(
            future: _analysisDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 250,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  ),
                );
              } else if (snapshot.hasError) {
                return Container(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red.shade400,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading data',
                          style: TextStyle(color: Colors.red.shade400, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (!snapshot.hasData) {
                return Container(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.data_usage_rounded,
                          color: Colors.grey[400],
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No data found',
                          style: TextStyle(color: Colors.grey[400], fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                final AnalysisData analysisData = snapshot.data!;
                List<ChartData> chartData = [];

                for (String paramName in standardRanges.keys) {
                  List<double> standardRange = standardRanges[paramName]!;
                  List<double> userRange = analysisData.parameterRanges[paramName] ?? [0.0, 0.0];

                  chartData.add(ChartData(
                    parameter: paramName,
                    standardMin: standardRange[0],
                    standardMax: standardRange[1],
                    userMin: userRange[0],
                    userMax: userRange[1],
                  ));
                }

                return Column(
                  children: [
                    Container(
                      height: 350,
                      child: SfCartesianChart(
                        primaryXAxis: CategoryAxis(
                          labelRotation: -45,
                          labelIntersectAction: AxisLabelIntersectAction.multipleRows,
                          majorGridLines: MajorGridLines(width: 0),
                          axisLine: AxisLine(width: 0),
                        ),
                        primaryYAxis: NumericAxis(
                          labelFormat: '{value}',
                          majorGridLines: MajorGridLines(
                            width: 0.5,
                            color: Colors.grey.withOpacity(0.2),
                          ),
                          axisLine: AxisLine(width: 0),
                        ),
                        plotAreaBorderWidth: 0,
                        zoomPanBehavior: ZoomPanBehavior(
                          enablePanning: true,
                          enablePinching: true,
                          zoomMode: ZoomMode.xy,
                        ),
                        tooltipBehavior: TooltipBehavior(enable: true),
                        legend: Legend(
                          isVisible: true,
                          position: LegendPosition.bottom,
                          textStyle: TextStyle(color: Colors.white),
                        ),
                        series: <CartesianSeries>[
                          RangeAreaSeries<ChartData, String>(
                            name: 'Standard Range',
                            dataSource: chartData,
                            xValueMapper: (ChartData data, _) => _getShortParameterName(data.parameter),
                            lowValueMapper: (ChartData data, _) => data.standardMin,
                            highValueMapper: (ChartData data, _) => data.standardMax,
                            color: Colors.green.withOpacity(0.3),
                            borderColor: Colors.green,
                            borderWidth: 2,
                          ),
                          RangeAreaSeries<ChartData, String>(
                            name: 'Your Performance',
                            dataSource: chartData,
                            xValueMapper: (ChartData data, _) => _getShortParameterName(data.parameter),
                            lowValueMapper: (ChartData data, _) => data.userMin,
                            highValueMapper: (ChartData data, _) => data.userMax,
                            color: Colors.blue.withOpacity(0.3),
                            borderColor: Colors.blue,
                            borderWidth: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildLegendItem(Colors.green, 'Standard Range'),
                        _buildLegendItem(Colors.blue, 'Your Performance'),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
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
            Colors.indigo.withOpacity(0.1),
            Colors.purple.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.indigo.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.1),
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
                    colors: [Colors.indigo, Colors.purple],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Understanding Your Analysis',
                style: TextStyle(
                  color: Colors.indigo.shade300,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoCard(
            'Performance Overview',
            'This analysis shows your performance across key biomechanical parameters compared to standard ranges. The chart displays your actual performance range from the last 4 sessions.',
            Icons.timeline_rounded,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            'Chart Interpretation',
            'Green areas represent the standard/optimal ranges for each parameter. Blue areas show your actual performance. Aim to keep your performance within or close to the standard ranges.',
            Icons.insights_rounded,
            Colors.green,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            'Interactive Features',
            'Use pinch-to-zoom and pan gestures to explore the chart in detail. This helps you analyze specific parameters more closely.',
            Icons.touch_app_rounded,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
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

/// Data model for analysis results
class AnalysisData {
  final double averageEfficiency;
  final Map<String, List<double>> parameterRanges;

  AnalysisData({
    required this.averageEfficiency,
    required this.parameterRanges,
  });
}

/// Data model for the chart
class ChartData {
  final String parameter;
  final double standardMin;
  final double standardMax;
  final double userMin;
  final double userMax;

  ChartData({
    required this.parameter,
    required this.standardMin,
    required this.standardMax,
    required this.userMin,
    required this.userMax,
  });
}