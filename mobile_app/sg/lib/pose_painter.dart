import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size absoluteImageSize;
  final InputImageRotation rotation;

  PosePainter(this.poses, this.absoluteImageSize, this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.green;

    final paintLandmark = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 5.0
      ..color = Colors.red;

    for (final pose in poses) {
      // 1. Draw all dots (red)
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(
          Offset(
            translateX(landmark.x, size, absoluteImageSize, rotation),
            translateY(landmark.y, size, absoluteImageSize, rotation),
          ),
          4,
          paintLandmark,
        );
      });

      // Helper function to draw lines
      void paintLine(PoseLandmarkType type1, PoseLandmarkType type2) {
        final PoseLandmark joint1 = pose.landmarks[type1]!;
        final PoseLandmark joint2 = pose.landmarks[type2]!;
        canvas.drawLine(
          Offset(translateX(joint1.x, size, absoluteImageSize, rotation),
              translateY(joint1.y, size, absoluteImageSize, rotation)),
          Offset(translateX(joint2.x, size, absoluteImageSize, rotation),
              translateY(joint2.y, size, absoluteImageSize, rotation)),
          paint,
        );
      }

      // --- ARMS ---
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      paintLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      paintLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

      // --- TORSO ---
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

      // --- LEGS (New) ---
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      paintLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
      paintLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      paintLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

      // --- FACE / HEAD (New) ---
      // Connect Shoulders to Ears to show head position
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftEar);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightEar);

      // Connect Ears to Eyes to Nose
      paintLine(PoseLandmarkType.leftEar, PoseLandmarkType.leftEye);
      paintLine(PoseLandmarkType.leftEye, PoseLandmarkType.nose);
      paintLine(PoseLandmarkType.rightEar, PoseLandmarkType.rightEye);
      paintLine(PoseLandmarkType.rightEye, PoseLandmarkType.nose);
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return true;
  }

  double translateX(double x, Size canvasSize, Size imageSize, InputImageRotation rotation) {
    return x * canvasSize.width / imageSize.height;
  }

  double translateY(double y, Size canvasSize, Size imageSize, InputImageRotation rotation) {
    return y * canvasSize.height / imageSize.width;
  }
}