import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class Detection {
  final String label;
  final double score;
  final List<double> boundingBox; // [ymin, xmin, ymax, xmax] coordinates normalized (0.0 to 1.0)

  Detection({
    required this.label,
    required this.score,
    required this.boundingBox,
  });
}

class ObjectDetectorService {
  Interpreter? _interpreter;
  List<String>? _labels;

  bool get isLoaded => _interpreter != null && _labels != null;

  Future<void> loadModel() async {
    try {
      // Load interpreter from assets
      _interpreter = await Interpreter.fromAsset('assets/models/ssd_mobilenet_v2.tflite');
      
      // Load labels from assets
      final labelsText = await rootBundle.loadString('assets/models/coco_labels.txt');
      _labels = labelsText.split('\n').map((e) => e.trim()).toList();
      print("TFLite Model and labels loaded successfully");
    } catch (e) {
      print("Error loading TFLite model: $e");
    }
  }

  Future<List<Detection>> detectObjects(File imageFile, {double threshold = 0.4}) async {
    if (!isLoaded) await loadModel();
    if (_interpreter == null || _labels == null) return [];

    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return [];

      // Resize to 300x300 (standard input for SSD MobileNet V2)
      final resizedImage = img.copyResize(image, width: 300, height: 300);

      // Prepare input tensor: [1, 300, 300, 3] Float32
      final input = List.generate(
        1,
        (_) => List.generate(
          300,
          (y) => List.generate(
            300,
            (x) {
              final pixel = resizedImage.getPixel(x, y);
              // Normalize Float values between -1.0 and 1.0 (standard for SSD MobileNet V2 float models)
              return [
                (pixel.r - 127.5) / 127.5,
                (pixel.g - 127.5) / 127.5,
                (pixel.b - 127.5) / 127.5,
              ];
            },
          ),
        ),
      );

      // Prepare outputs:
      // Output 0: Locations [1, 100, 4]
      // Output 1: Classes [1, 100]
      // Output 2: Scores [1, 100]
      // Output 3: Number of detections [1]
      final outputLocations = List.generate(1, (_) => List.generate(100, (_) => List.filled(4, 0.0)));
      final outputClasses = List.generate(1, (_) => List.filled(100, 0.0));
      final outputScores = List.generate(1, (_) => List.filled(100, 0.0));
      final numDetections = List.filled(1, 0.0);

      final outputs = {
        0: outputLocations,
        1: outputClasses,
        2: outputScores,
        3: numDetections,
      };

      _interpreter!.runForMultipleInputs([input], outputs);

      final List<Detection> detections = [];
      final count = numDetections[0].toInt().clamp(0, 100);

      for (var i = 0; i < count; i++) {
        final score = outputScores[0][i];
        if (score >= threshold) {
          final classId = outputClasses[0][i].toInt();
          final label = (classId < _labels!.length) ? _labels![classId] : "Unknown";
          
          if (label != '???') { // Skip coco placeholder labels
            detections.add(
              Detection(
                label: label,
                score: score,
                boundingBox: outputLocations[0][i], // [ymin, xmin, ymax, xmax]
              ),
            );
          }
        }
      }
      return detections;
    } catch (e) {
      print("Error during object detection: $e");
      return [];
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}
