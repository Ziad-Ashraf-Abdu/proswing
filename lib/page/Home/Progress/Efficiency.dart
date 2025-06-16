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

class _EfficiencyState extends State<Efficiency> {
  late Future<List<ChartData>> _idealProgressFuture;
  late Future<List<ChartData>> _userProgressFuture;

  @override
  void initState() {
    super.initState();
    _idealProgressFuture = loadIdealProgress();
    _userProgressFuture = loadUserProgress();
  }

  Future<List<ChartData>> loadIdealProgress() async {
    final String data =
    await rootBundle.loadString('assets/parameter_ranges_launch.csv');
    final List<String> lines = data.split('\n');
    final List<ChartData> progress = [];

    for (int i = 1; i < lines.length; i++) {
      final String line = lines[i].trim();
      if (line.isEmpty) continue;

      final List<String> values = line.split(',');
      if (values.length >= 3) {
        final String parameter = values[0].trim();
        try {
          final double minValue = double.tryParse(values[1].trim()) ?? 0.0;
          final double maxValue = double.tryParse(values[2].trim()) ?? 0.0;
          progress.add(ChartData(parameter, minValue, maxValue));
        } catch (e) {
          print("Error parsing line: $line");
        }
      }
    }
    return progress;
  }

  Future<List<ChartData>> loadUserProgress() async {
    try {
      // Get the most recent analysis file
      File? mostRecentFile = await getMostRecentAnalysisFile();

      if (mostRecentFile == null || !await mostRecentFile.exists()) {
        print("No analysis file found, using default progress");
        return await loadDefaultUserProgress();
      }

      final String data = await mostRecentFile.readAsString();
      final List<String> lines = data.split('\n');
      final List<ChartData> progress = [];

      // Parse the CSV data from the analysis file
      for (int i = 1; i < lines.length; i++) {
        final String line = lines[i].trim();
        if (line.isEmpty) continue;

        final List<String> values = line.split(',');
        if (values.length >= 3) {
          final String parameter = values[0].trim();
          try {
            final double minValue = double.tryParse(values[1].trim()) ?? 0.0;
            final double maxValue = double.tryParse(values[2].trim()) ?? 0.0;
            progress.add(ChartData(parameter, minValue, maxValue));
          } catch (e) {
            print("Error parsing analysis line: $line");
          }
        }
      }

      return progress.isEmpty ? await loadDefaultUserProgress() : progress;
    } catch (e) {
      print("Error loading user progress: $e");
      return await loadDefaultUserProgress();
    }
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

  Future<List<ChartData>> loadDefaultUserProgress() async {
    // Fallback: Load ideal progress and apply 55% factor
    final List<ChartData> idealData = await loadIdealProgress();
    return idealData.map((data) {
      return ChartData(
        data.parameter,
        data.minValue * 0.55,
        data.maxValue * 0.55,
      );
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildLevelSection(widget.value),
            const SizedBox(height: 30),
            _buildChartSection(),
            const SizedBox(height: 30),
            _buildInfoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelSection(int value) {
    final double percentage = value / 100.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Efficiency',
          style: TextStyle(
            color: Colors.green.shade400,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
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
              maximumValue: 1,
              radius: '75%',
              dataSource: [value],
              cornerStyle: CornerStyle.bothCurve,
              xValueMapper: (int data, _) => '',
              yValueMapper: (int data, _) => percentage,
              pointColorMapper: (int data, _) => Colors.purple.shade600,
              trackColor: Colors.grey.shade700,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'You have reached ${(percentage * 100).toStringAsFixed(0)}% of your current level. Keep pushing to reach the next level!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildChartSection() {
    final String level = calculateLevel(widget.userLevel);

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Efficiency Over Parameters',
            style: TextStyle(
              color: Colors.green.shade400,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<List<ChartData>>>(
            future: Future.wait([_idealProgressFuture, _userProgressFuture]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                    child: Text('Error loading data: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                    child: Text('No data found',
                        style: const TextStyle(color: Colors.white)));
              } else {
                final List<ChartData> idealData = snapshot.data![0];
                final List<ChartData> userProgress = snapshot.data![1];

                return SfCartesianChart(
                  primaryXAxis: CategoryAxis(),
                  zoomPanBehavior: ZoomPanBehavior(
                    enablePanning: true,
                  ),
                  series: <CartesianSeries>[
                    // Ideal progress range (yellow) from CSV data.
                    RangeAreaSeries<ChartData, String>(
                      dataSource: idealData,
                      xValueMapper: (ChartData data, _) => data.parameter,
                      lowValueMapper: (ChartData data, _) => data.minValue,
                      highValueMapper: (ChartData data, _) => data.maxValue,
                      color: Colors.yellowAccent.withOpacity(0.3),
                      borderColor: Colors.yellowAccent,
                      borderWidth: 2,
                    ),
                    // Player progress range (red) from analysis results.
                    RangeAreaSeries<ChartData, String>(
                      dataSource: userProgress,
                      xValueMapper: (ChartData data, _) => data.parameter,
                      lowValueMapper: (ChartData data, _) => data.minValue,
                      highValueMapper: (ChartData data, _) => data.maxValue,
                      color: Colors.red.withOpacity(0.3),
                      borderColor: Colors.red,
                      borderWidth: 2,
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(width: 20, height: 20, color: Colors.yellowAccent),
              const SizedBox(width: 10),
              Text('Ideal Progress for $level',
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(width: 20),
              Container(width: 20, height: 20, color: Colors.red),
              const SizedBox(width: 10),
              const Text('Your Progress',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

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
            Text('Tips',
                style: TextStyle(
                    color: Colors.green.shade400,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
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

/// Data model for the chart.
/// [parameter] holds the parameter name and [minValue] and [maxValue] are the range.
class ChartData {
  final String parameter;
  final double minValue;
  final double maxValue;

  ChartData(this.parameter, this.minValue, this.maxValue);
}