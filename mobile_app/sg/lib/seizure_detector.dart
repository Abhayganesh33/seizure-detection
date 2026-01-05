import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ Added for Settings
import 'classifier.dart';
import 'pose_painter.dart';

// This list is populated by main.dart
List<CameraDescription> cameras = [];

class SeizureDetectorPage extends StatefulWidget {
  // Callback to send data to the Graph on Home Page
  final Function(double) onDataUpdate;

  const SeizureDetectorPage({super.key, required this.onDataUpdate});

  @override
  State<SeizureDetectorPage> createState() => _SeizureDetectorPageState();
}

class _SeizureDetectorPageState extends State<SeizureDetectorPage> with WidgetsBindingObserver {
  CameraController? _controller;
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  final Classifier _classifier = Classifier();

  bool _isDetecting = false;
  bool _isCameraOn = true;

  List<List<double>> _frameBuffer = [];
  String _status = "Initializing...";
  Color _statusColor = Colors.grey;

  CustomPaint? _customPaint;

  // Window Logic
  final int _windowSize = 10;
  final List<int> _detectionHistory = [];

  // Store previous landmarks for speed calculation
  Map<PoseLandmarkType, PoseLandmark>? _prevLandmarks;

  // ✅ Settings Variables (Defaults)
  double _modelThreshold = 0.60;
  double _jerkThreshold = 1.2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Fix for app lifecycle
    _loadSettings(); // ✅ Load settings from storage
    _initCamera();
    _classifier.loadModel();
  }

  // ✅ Load values from Settings Page
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _modelThreshold = prefs.getDouble('model_threshold') ?? 0.60;
        _jerkThreshold = prefs.getDouble('jerk_threshold') ?? 1.2;
      });
    }
  }

  Future<void> _initCamera() async {
    await Permission.camera.request();

    if (cameras.isEmpty) {
      debugPrint("No cameras found");
      return;
    }

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _controller!.initialize();
    if (!mounted) return;

    // Start stream immediately if flag is true
    if (_isCameraOn) {
      _startScanning();
    }
    setState(() {});
  }

  void _startScanning() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    // ✅ Safety Check: Prevent multiple streams
    if (!_controller!.value.isStreamingImages) {
      _controller?.startImageStream((image) {
        if (!_isDetecting) {
          _isDetecting = true;
          _processFrame(image);
        }
      });
    }
  }

  Future<void> _stopScanning() async {
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller?.stopImageStream();
    }
    if (mounted) {
      setState(() {
        _isDetecting = false;
        _status = "Camera Paused";
        _statusColor = Colors.grey;
        _customPaint = null; // Clear skeleton
        widget.onDataUpdate(0.0); // Send 0 to graph
      });
    }
  }

  void _toggleCamera() async {
    if (_isCameraOn) {
      await _stopScanning();
      setState(() => _isCameraOn = false);
    } else {
      _startScanning();
      setState(() => _isCameraOn = true);
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      if (!mounted) return; // Prevent crash if closed

      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final List<Pose> poses = await _poseDetector.processImage(inputImage);

      if (!mounted) return;

      if (inputImage.metadata?.size != null && inputImage.metadata?.rotation != null) {
        _customPaint = CustomPaint(
          painter: PosePainter(poses, inputImage.metadata!.size, inputImage.metadata!.rotation),
        );
      }

      if (poses.isNotEmpty) {
        if (_status == "No Body Detected") {
          _status = "Normal";
          _statusColor = Colors.green.withOpacity(0.8);
        }

        List<double> currentFrameLandmarks = [];
        final pose = poses.first;

        double headShakeScore = _calculateHeadShakeScore(pose);
        _prevLandmarks = pose.landmarks;

        double width = inputImage.metadata?.size.width ?? 1.0;
        double height = inputImage.metadata?.size.height ?? 1.0;

        pose.landmarks.forEach((_, landmark) {
          currentFrameLandmarks.add(landmark.x / width);
          currentFrameLandmarks.add(landmark.y / height);
          currentFrameLandmarks.add(landmark.z);
        });

        if (currentFrameLandmarks.length == 99) {
          _frameBuffer.add(currentFrameLandmarks);
        }

        if (_frameBuffer.length == 75) {
          double modelScore = await _classifier.predict(_frameBuffer);
          _updateStatus(modelScore, headShakeScore);
          _frameBuffer.removeAt(0);
        }
      } else {
        if (mounted) {
          setState(() {
            _status = "No Body Detected";
            _statusColor = Colors.grey;
            _detectionHistory.clear();
            _frameBuffer.clear();
            widget.onDataUpdate(0.0);
          });
        }
      }

      if (mounted) setState(() {});

    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      _isDetecting = false;
    }
  }

  double _calculateHeadShakeScore(Pose currentPose) {
    if (_prevLandmarks == null) return 0.0;

    final leftShoulder = currentPose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = currentPose.landmarks[PoseLandmarkType.rightShoulder];
    final prevLeftShoulder = _prevLandmarks![PoseLandmarkType.leftShoulder];
    final prevRightShoulder = _prevLandmarks![PoseLandmarkType.rightShoulder];

    if (leftShoulder == null || rightShoulder == null ||
        prevLeftShoulder == null || prevRightShoulder == null) {
      return 0.0;
    }

    double totalJerk = 0.0;
    int pointsChecked = 0;

    List<PoseLandmarkType> headPoints = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftEyeInner, PoseLandmarkType.leftEye, PoseLandmarkType.leftEyeOuter,
      PoseLandmarkType.rightEyeInner, PoseLandmarkType.rightEye, PoseLandmarkType.rightEyeOuter,
      PoseLandmarkType.leftEar, PoseLandmarkType.rightEar,
      PoseLandmarkType.leftMouth, PoseLandmarkType.rightMouth
    ];

    for (var type in headPoints) {
      final currHead = currentPose.landmarks[type];
      final prevHead = _prevLandmarks![type];

      if (currHead != null && prevHead != null) {
        double distL_curr = _dist(currHead, leftShoulder);
        double distL_prev = _dist(prevHead, prevLeftShoulder);
        double distR_curr = _dist(currHead, rightShoulder);
        double distR_prev = _dist(prevHead, prevRightShoulder);

        totalJerk += (distL_curr - distL_prev).abs();
        totalJerk += (distR_curr - distR_prev).abs();
        pointsChecked++;
      }
    }

    if (pointsChecked == 0) return 0.0;
    return totalJerk / pointsChecked;
  }

  double _dist(PoseLandmark p1, PoseLandmark p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }

  void _updateStatus(double modelScore, double headShakeScore) {
    // Send data to Graph
    widget.onDataUpdate(headShakeScore);

    // ✅ USE SETTINGS VALUES HERE
    bool modelSaysSeizure = modelScore > _modelThreshold;
    bool headIsShaking = headShakeScore > _jerkThreshold;

    if (modelSaysSeizure && headIsShaking) {
      _detectionHistory.add(1);
    } else {
      _detectionHistory.add(0);
    }

    if (_detectionHistory.length > _windowSize) {
      _detectionHistory.removeAt(0);
    }

    int seizureVotes = _detectionHistory.where((val) => val == 1).length;
    bool isSeizure = seizureVotes > (_detectionHistory.length / 2);

    setState(() {
      if (isSeizure) {
        _status = "⚠️ SEIZURE DETECTED!\n(Model: ${(modelScore*100).toInt()}% | Head Jerk: ${headShakeScore.toStringAsFixed(1)})";
        _statusColor = Colors.red.withOpacity(0.8);
      } else {
        _status = "Normal\n(Model: ${(modelScore*100).toInt()}% | Jerk: ${headShakeScore.toStringAsFixed(1)})";
        _statusColor = Colors.green.withOpacity(0.8);
      }
    });
  }

  InputImage? _convertCameraImage(CameraImage image) {
    if (cameras.isEmpty) return null;

    final camera = cameras[0];
    InputImageRotation? rotation;
    if (defaultTargetPlatform == TargetPlatform.android) {
      rotation = InputImageRotation.rotation90deg;
    }
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final InputImageFormat inputImageFormat = InputImageFormat.nv21;
    final inputImageData = InputImageMetadata(
      size: imageSize,
      rotation: rotation ?? InputImageRotation.rotation0deg,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );
    return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
  }

  // ✅ CRITICAL FIX: STOP STREAM BEFORE CLOSING
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_controller != null && _controller!.value.isStreamingImages) {
      _controller!.stopImageStream();
    }
    _controller?.dispose();
    _poseDetector.close();
    _classifier.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera Layer: Only show if Camera is ON
        if (_isCameraOn)
          CameraPreview(_controller!)
        else
          Container(
            color: Colors.black87,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_off, color: Colors.white54, size: 50),
                  SizedBox(height: 10),
                  Text("Camera Paused", style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),

        if (_isCameraOn && _customPaint != null) _customPaint!,

        // Toggle Button (Top Right)
        Positioned(
          top: 20,
          right: 20,
          child: FloatingActionButton.small(
            backgroundColor: _isCameraOn ? Colors.redAccent : Colors.green,
            onPressed: _toggleCamera,
            child: Icon(_isCameraOn ? Icons.stop : Icons.play_arrow),
          ),
        ),

        // Overlay Status Bar
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: _statusColor,
            child: Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold
              ),
            ),
          ),
        ),
      ],
    );
  }
}