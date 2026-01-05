import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ Required for "First Time" check
import 'seizure_detector.dart'; // Import to access 'cameras' list
import 'home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Cameras
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Error initializing cameras: $e");
  }

  // 2. Check if user has already seen the disclaimer
  final prefs = await SharedPreferences.getInstance();
  final bool hasAcceptedDisclaimer = prefs.getBool('accepted_disclaimer') ?? false;

  runApp(MyApp(showDisclaimer: !hasAcceptedDisclaimer));
}

class MyApp extends StatelessWidget {
  final bool showDisclaimer;

  const MyApp({super.key, required this.showDisclaimer});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SeizureGuard',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      ),
      // ✅ Decide which page to show first
      home: showDisclaimer ? const DisclaimerPage() : const HomePage(),
    );
  }
}

// ================= DISCLAIMER SCREEN =================
class DisclaimerPage extends StatelessWidget {
  const DisclaimerPage({super.key});

  Future<void> _acceptDisclaimer(BuildContext context) async {
    // Save that the user accepted
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('accepted_disclaimer', true);

    // Go to Home Page
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medical_information, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              "Important Disclaimer",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "This app is not a medical diagnostic device.\n\nIt is an assistive alert tool designed to help monitor movements. It does not replace professional medical advice, diagnosis, or treatment.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _acceptDisclaimer(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "I Understand",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}