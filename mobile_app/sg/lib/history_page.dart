import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

    setState(() {
      _historyData = savedList.map((item) {
        return jsonDecode(item) as Map<String, dynamic>;
      }).toList();
      // Show newest first
      _historyData = _historyData.reversed.toList();
    });
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('seizure_history');
    _loadHistory();
  }

  // ✅ New Function to Generate and Share PDF
  Future<void> _exportPdf() async {
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

    // Save and Share
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/seizure_history.pdf");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Here is the Seizure History Report.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Seizure History"),
        actions: [
          // ✅ Download PDF Button
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearHistory,
          )
        ],
      ),
      body: _historyData.isEmpty
          ? const Center(child: Text("No history recorded"))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _historyData.length,
        itemBuilder: (context, index) {
          final data = _historyData[index];

          final DateTime date = DateTime.parse(data['time']);
          final String dateStr = DateFormat('MMM d, yyyy').format(date);
          final String timeStr = DateFormat('h:mm a').format(date);
          final double intensity = data['intensity'] ?? 0.0;

          return Card(
            child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: Text("Seizure Detected"),
              subtitle: Text("$dateStr at $timeStr"),
              trailing: Text(
                "Intensity: ${intensity.toStringAsFixed(1)}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}