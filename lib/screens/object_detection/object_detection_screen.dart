import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/colors.dart';
import '../../services/object_detector_service.dart';
import '../../services/tts_service.dart';

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  File? _image;
  int _imageWidth = 1;
  int _imageHeight = 1;
  final _picker = ImagePicker();
  final _detectorService = ObjectDetectorService();
  List<Detection> _detections = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _detectorService.loadModel();
  }

  @override
  void dispose() {
    _detectorService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final bytes = await file.readAsBytes();
        final decoded = await decodeImageFromList(bytes);

        setState(() {
          _image = file;
          _imageWidth = decoded.width;
          _imageHeight = decoded.height;
          _detections = [];
          _isLoading = true;
        });

        // Run object detection
        final results = await _detectorService.detectObjects(_image!);

        setState(() {
          _detections = results;
          _isLoading = false;
        });

        // Announce results via TTS
        if (results.isNotEmpty) {
          final labels = results.map((d) => d.label).toSet().join(', ');
          TtsService().speak("Buddy saw: $labels");
        } else {
          TtsService().speak("Buddy did not see any objects in this frame.");
        }
      }
    } catch (e) {
      print("Error picking image: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Object Detector',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Instructions text
              Text(
                'Upload an image or capture a photo to perform local on-device object detection.',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Image display box
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: AppColors.primaryButton),
                        )
                      : _image == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_search,
                                    size: 80,
                                    color: AppColors.primaryText.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No Image Selected',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryText.withOpacity(0.6),
                                    ),
                                  )
                                ],
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                double imageRatio = _imageWidth / _imageHeight;
                                double containerRatio = constraints.maxWidth / constraints.maxHeight;

                                double renderWidth;
                                double renderHeight;
                                double offsetLeft = 0;
                                double offsetTop = 0;

                                if (imageRatio > containerRatio) {
                                  // Image is wider than container (width constrained)
                                  renderWidth = constraints.maxWidth;
                                  renderHeight = constraints.maxWidth / imageRatio;
                                  offsetTop = (constraints.maxHeight - renderHeight) / 2;
                                } else {
                                  // Image is taller than container (height constrained)
                                  renderHeight = constraints.maxHeight;
                                  renderWidth = constraints.maxHeight * imageRatio;
                                  offsetLeft = (constraints.maxWidth - renderWidth) / 2;
                                }

                                return Stack(
                                  children: [
                                    // The Image itself
                                    Positioned.fill(
                                      child: Image.file(
                                        _image!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    // Bounding Box Overlays
                                    ..._detections.map((detection) {
                                      // MobileNet coordinates format: [ymin, xmin, ymax, xmax]
                                      final ymin = detection.boundingBox[0];
                                      final xmin = detection.boundingBox[1];
                                      final ymax = detection.boundingBox[2];
                                      final xmax = detection.boundingBox[3];

                                      final boxTop = offsetTop + (ymin * renderHeight);
                                      final boxLeft = offsetLeft + (xmin * renderWidth);
                                      final boxWidth = (xmax - xmin) * renderWidth;
                                      final boxHeight = (ymax - ymin) * renderHeight;

                                      return Positioned(
                                        top: boxTop,
                                        left: boxLeft,
                                        width: boxWidth,
                                        height: boxHeight,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.red,
                                              width: 3.0,
                                            ),
                                          ),
                                          child: Align(
                                            alignment: Alignment.topLeft,
                                            child: Container(
                                              color: Colors.red,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 4.0,
                                                vertical: 2.0,
                                              ),
                                              child: Text(
                                                '${detection.label} ${(detection.score * 100).toStringAsFixed(0)}%',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                );
                              },
                            ),
                ),
              ),
              const SizedBox(height: 20),

              // Control buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryButton,
                          foregroundColor: AppColors.primaryButtonText,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: Text(
                        'Gallery',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryButton,
                          foregroundColor: AppColors.primaryButtonText,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: Text(
                        'Camera',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
