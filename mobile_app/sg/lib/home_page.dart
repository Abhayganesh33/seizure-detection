import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

// ✅ Custom Imports
import 'seizure_detector.dart';
import 'settings_page.dart'; // ✅ Make sure you created this file!

// ✅ PDF Imports
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ================= HOME PAGE =================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _isCameraActive = false;
  List<FlSpot> _graphData = [const FlSpot(0, 0)];
  double _timeCounter = 0;
  final double _seizureThreshold = 15.0;
  bool _isSeizureDetected = false;
  DateTime _lastSaveTime = DateTime.now();

  void _handleDataUpdate(double intensity) {
    // ✅ CRASH FIX: Stop processing if widget is closed or camera is off
    if (!mounted || !_isCameraActive) return;

    setState(() {
      _timeCounter++;
      _graphData.add(FlSpot(_timeCounter, intensity));

      _isSeizureDetected = intensity > _seizureThreshold;

      // ✅ SAVE LOGIC
      if (_isSeizureDetected) {
        if (DateTime.now().difference(_lastSaveTime).inSeconds >= 1) {
          _saveSeizureToHistory(intensity);
          _lastSaveTime = DateTime.now();
        }
      }

      if (_graphData.length > 20) {
        _graphData.removeAt(0);
      }
    });
  }

  Future<void> _saveSeizureToHistory(double intensity) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('seizure_history') ?? [];
    Map<String, dynamic> newEntry = {
      'time': DateTime.now().toIso8601String(),
      'intensity': intensity,
    };
    history.add(jsonEncode(newEntry));
    await prefs.setStringList('seizure_history', history);
  }

  void _toggleCamera() {
    setState(() {
      _isCameraActive = !_isCameraActive;
      if (!_isCameraActive) _isSeizureDetected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // PAGE 0: Monitor
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 400,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _isCameraActive
                    ? SeizureDetectorPage(onDataUpdate: _handleDataUpdate)
                    : Container(
                  color: Colors.black12,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.videocam_off,
                            size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("Camera is Off",
                            style: TextStyle(
                                color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            MotionGraph(points: _graphData, isSeizure: _isSeizureDetected),
          ],
        ),
      ),

      // PAGE 1: History
      const HistoryPage(),

      // PAGE 2: Settings (✅ Linked Correctly)
      const SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title:
        const Text("SeizureGuard", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Show buttons ONLY on Monitor Page
          if (_currentIndex == 0)
            GestureDetector(
              onTap: _toggleCamera,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isSeizureDetected
                      ? Colors.red.shade100
                      : (_isCameraActive
                      ? Colors.green.shade100
                      : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                        _isSeizureDetected
                            ? Icons.warning
                            : (_isCameraActive
                            ? Icons.stop_circle
                            : Icons.play_circle),
                        size: 18,
                        color: Colors.black),
                    const SizedBox(width: 6),
                    Text(
                        _isSeizureDetected
                            ? "ALARM"
                            : (_isCameraActive ? "STOP" : "START"),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        // ✅ CRITICAL: Stop Camera when switching tabs to prevent crash
        onTap: (i) {
          setState(() {
            _currentIndex = i;
            if (_currentIndex != 0) {
              _isCameraActive = false;
              _isSeizureDetected = false;
            }
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.videocam), label: "Monitor"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}

// ================= GRAPH WIDGET =================
class MotionGraph extends StatelessWidget {
  final List<FlSpot> points;
  final bool isSeizure;
  const MotionGraph({super.key, required this.points, required this.isSeizure});

  @override
  Widget build(BuildContext context) {
    final Color graphColor = isSeizure ? Colors.red : Colors.blue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSeizure ? Border.all(color: Colors.red, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Motion Intensity",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                points.isNotEmpty ? points.last.y.toStringAsFixed(1) : "0.0",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: graphColor,
                    fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toInt().toString(),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(value.toInt().toString(),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: points,
                    isCurved: true,
                    color: graphColor,
                    barWidth: 4,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                        show: true, color: graphColor.withOpacity(0.2)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= HISTORY PAGE =================
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _historyData = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedList = prefs.getStringList('seizure_history') ?? [];

    if (!mounted) return;

    setState(() {
      _historyData = savedList.map((item) {
        try {
          return jsonDecode(item) as Map<String, dynamic>;
        } catch (e) {
          return <String, dynamic>{};
        }
      }).where((item) => item.isNotEmpty).toList();

      _historyData = _historyData.reversed.toList();
    });
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('seizure_history');
    _loadHistory();
  }

  Future<void> _downloadPdf() async {
    if (_historyData.isEmpty) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Header(level: 0, child: pw.Text("Seizure History Report")),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Time', 'Intensity'],
                data: _historyData.map((item) {
                  final DateTime date = DateTime.parse(item['time']);
                  return [
                    DateFormat('MMM d, yyyy').format(date),
                    DateFormat('h:mm a').format(date),
                    (item['intensity'] as double).toStringAsFixed(1),
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/seizure_history.pdf");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Seizure History Report');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "pdf_btn",
            onPressed: _downloadPdf,
            backgroundColor: Colors.blue,
            child: const Icon(Icons.download),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "del_btn",
            onPressed: _clearHistory,
            backgroundColor: Colors.red,
            child: const Icon(Icons.delete),
          ),
        ],
      ),
      body: _historyData.isEmpty
          ? const Center(child: Text("No history recorded"))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _historyData.length,
        itemBuilder: (context, index) {
          final data = _historyData[index];
          final DateTime date = data['time'] != null
              ? DateTime.parse(data['time'])
              : DateTime.now();

          return Card(
            child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: Text("Seizure Detected"),
              subtitle: Text(DateFormat('MMM d, h:mm a').format(date)),
              trailing: Text(
                  "Int: ${(data['intensity'] ?? 0.0).toStringAsFixed(1)}"),
            ),
          );
        },
      ),
    );
  }
}