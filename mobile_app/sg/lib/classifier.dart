import 'dart:developer';
import 'package:tflite_flutter/tflite_flutter.dart';

class Classifier {
  Interpreter? _interpreter;

  Future<void> loadModel() async {
    try {
      // Load the Clean TFLite model
      _interpreter = await Interpreter.fromAsset('assets/seizure_lstm.tflite');
      log('✅ Model loaded successfully!');

      // Print shape just to be sure
      var inputShape = _interpreter!.getInputTensor(0).shape;
      log('Model Input Shape: $inputShape');
    } catch (e) {
      log('❌ Error loading model: $e');
    }
  }

  /// Runs prediction on a buffer of 75 frames
  /// Input: List of 75 frames, where each frame has 99 values (33 landmarks x 3)
  Future<double> predict(List<List<double>> inputBuffer) async {
    if (_interpreter == null) {
      return 0.0;
    }

    try {
      // 1. Reshape input to [1, 75, 99] matches your model
      var input = [inputBuffer];

      // 2. Output buffer: [1, 1] (Single number result)
      var output = List.filled(1 * 1, 0.0).reshape([1, 1]);

      // 3. Run Inference
      _interpreter!.run(input, output);

      // 4. Return the score (0.0 to 1.0)
      var score = output[0][0];
      log("Prediction Score: $score");
      return score;

    } catch (e) {
      log("Prediction Error: $e");
      return 0.0;
    }
  }

  void close() {
    _interpreter?.close();
  }
}