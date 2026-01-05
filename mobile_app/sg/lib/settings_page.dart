import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Default Values
  double _modelThreshold = 0.60;
  double _jerkThreshold = 1.2;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load saved values
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _modelThreshold = prefs.getDouble('model_threshold') ?? 0.60;
      _jerkThreshold = prefs.getDouble('jerk_threshold') ?? 1.2;
    });
  }

  // Save values when changed
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('model_threshold', _modelThreshold);
    await prefs.setDouble('jerk_threshold', _jerkThreshold);
  }

  Future<void> _resetDefaults() async {
    setState(() {
      _modelThreshold = 0.60;
      _jerkThreshold = 1.2;
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Detection Settings")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("AI Confidence Threshold", style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _modelThreshold,
              min: 0.1,
              max: 1.0,
              divisions: 9,
              label: "${(_modelThreshold * 100).toInt()}%",
              onChanged: (value) {
                setState(() => _modelThreshold = value);
                _saveSettings();
              },
            ),
            Text("Current: ${(_modelThreshold * 100).toInt()}% (Higher = Less Sensitive)"),

            const SizedBox(height: 30),

            const Text("Head Jerk Sensitivity", style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _jerkThreshold,
              min: 0.5,
              max: 5.0,
              divisions: 45,
              label: _jerkThreshold.toStringAsFixed(1),
              onChanged: (value) {
                setState(() => _jerkThreshold = value);
                _saveSettings();
              },
            ),
            Text("Current: ${_jerkThreshold.toStringAsFixed(1)} (Lower = More Sensitive)"),

            const Spacer(),
            Center(
              child: ElevatedButton.icon(
                onPressed: _resetDefaults,
                icon: const Icon(Icons.refresh),
                label: const Text("Reset to Defaults"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}