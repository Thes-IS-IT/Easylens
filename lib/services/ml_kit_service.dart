import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

class ImageLabelInfo {
  final String text;
  final double confidence;
  final int index;

  ImageLabelInfo({
    required this.text,
    required this.confidence,
    required this.index,
  });
}

class MlKitService {
  ImageLabeler? _imageLabeler;

  Future<void> initialize() async {
    try {
      final ImageLabelerOptions options = ImageLabelerOptions(confidenceThreshold: 0.4);
      _imageLabeler = ImageLabeler(options: options);
      print("ML Kit Image Labeler initialized successfully");
    } catch (e) {
      print("Error initializing ML Kit: $e");
    }
  }

  Future<List<ImageLabelInfo>> labelImage(File imageFile) async {
    if (_imageLabeler == null) {
      await initialize();
    }
    if (_imageLabeler == null) return [];

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final List<ImageLabel> labels = await _imageLabeler!.processImage(inputImage);
      
      return labels.map((label) => ImageLabelInfo(
        text: label.label,
        confidence: label.confidence,
        index: label.index,
      )).toList();
    } catch (e) {
      print("Error in ML Kit image labeling: $e");
      return [];
    }
  }

  void dispose() {
    _imageLabeler?.close();
  }
}
