import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../services/face_registration_service.dart';
import '../../services/settings_service.dart';
import '../../constants/colors.dart';
import '../dashboard/components/custom_navbar.dart';
import '../dashboard/components/buddy_assistant_sheet.dart';
import 'registered_faces_screen.dart';
import '../../utils/app_route.dart';
import '../../widgets/screen_tutorial_card.dart';
import '../../services/sound_service.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();

  // ── Robust geometric feature extraction using contours ─────────────────
  /// Extracts ~25 normalized geometric ratios from face landmarks and contours.
  /// No pixel-grid extraction — purely geometric for cross-condition robustness.
  /// This is static so it can be called from hardware_screen.dart for live matching.
  static List<double> extractFaceFeatures(Face face, Size imageSize) {
    final bbox = face.boundingBox;
    final bw = bbox.width > 0 ? bbox.width : 1.0;
    final bh = bbox.height > 0 ? bbox.height : 1.0;

    final features = <double>[];

    // ─── Core landmark ratios (7 features) ───
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;
    final leftEar = face.landmarks[FaceLandmarkType.leftEar]?.position;
    final rightEar = face.landmarks[FaceLandmarkType.rightEar]?.position;
    final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth]?.position;
    final leftCheek = face.landmarks[FaceLandmarkType.leftCheek]?.position;
    final rightCheek = face.landmarks[FaceLandmarkType.rightCheek]?.position;

    // 1. Inter-eye distance / face width
    double eyeDist = 0.5;
    if (leftEye != null && rightEye != null) {
      eyeDist = _dist(leftEye, rightEye) / bw;
    }
    features.add(eyeDist);

    // 2. Eye-center to nose / face height
    double eyeNoseDist = 0.25;
    if (leftEye != null && rightEye != null && nose != null) {
      final eyeMidX = (leftEye.x + rightEye.x) / 2.0;
      final eyeMidY = (leftEye.y + rightEye.y) / 2.0;
      eyeNoseDist = math.sqrt(math.pow(eyeMidX - nose.x, 2) + math.pow(eyeMidY - nose.y, 2)) / bh;
    }
    features.add(eyeNoseDist);

    // 3. Mouth width / face width
    double mouthW = 0.4;
    if (leftMouth != null && rightMouth != null) {
      mouthW = _dist(leftMouth, rightMouth) / bw;
    }
    features.add(mouthW);

    // 4. Nose to mouth center / face height
    double noseMouthDist = 0.15;
    if (nose != null && leftMouth != null && rightMouth != null) {
      final mouthMidX = (leftMouth.x + rightMouth.x) / 2.0;
      final mouthMidY = (leftMouth.y + rightMouth.y) / 2.0;
      noseMouthDist = math.sqrt(math.pow(nose.x - mouthMidX, 2) + math.pow(nose.y - mouthMidY, 2)) / bh;
    }
    features.add(noseMouthDist);

    // 5. Eye vertical position (relative to bbox)
    double eyePosY = 0.35;
    if (leftEye != null && rightEye != null) {
      eyePosY = ((leftEye.y + rightEye.y) / 2.0 - bbox.top) / bh;
    }
    features.add(eyePosY);

    // 6. Nose vertical position
    double nosePosY = 0.55;
    if (nose != null) {
      nosePosY = (nose.y - bbox.top) / bh;
    }
    features.add(nosePosY);

    // 7. Mouth vertical position
    double mouthPosY = 0.7;
    if (leftMouth != null && rightMouth != null) {
      mouthPosY = ((leftMouth.y + rightMouth.y) / 2.0 - bbox.top) / bh;
    }
    features.add(mouthPosY);

    // ─── Extended landmark ratios (8 more features) ───

    // 8. Nose horizontal position (asymmetry indicator)
    double noseHorizPos = 0.5;
    if (nose != null) {
      noseHorizPos = (nose.x - bbox.left) / bw;
    }
    features.add(noseHorizPos);

    // 9. Left eye to left ear / face width
    double leftEyeEar = 0.25;
    if (leftEye != null && leftEar != null) {
      leftEyeEar = _dist(leftEye, leftEar) / bw;
    }
    features.add(leftEyeEar);

    // 10. Right eye to right ear / face width
    double rightEyeEar = 0.25;
    if (rightEye != null && rightEar != null) {
      rightEyeEar = _dist(rightEye, rightEar) / bw;
    }
    features.add(rightEyeEar);

    // 11. Bottom mouth to chin (bbox bottom) / face height
    double mouthChinDist = 0.2;
    if (bottomMouth != null) {
      mouthChinDist = (bbox.bottom - bottomMouth.y) / bh;
    }
    features.add(mouthChinDist);

    // 12. Left cheek to right cheek / face width
    double cheekDist = 0.6;
    if (leftCheek != null && rightCheek != null) {
      cheekDist = _dist(leftCheek, rightCheek) / bw;
    }
    features.add(cheekDist);

    // 13. Ear-to-ear / face width (face width ratio)
    double earDist = 0.9;
    if (leftEar != null && rightEar != null) {
      earDist = _dist(leftEar, rightEar) / bw;
    }
    features.add(earDist);

    // 14. Face aspect ratio (bbox width / height)
    features.add(bw / bh);

    // 15. Eye-line angle (tilt indicator, in radians normalized)
    double eyeAngle = 0.0;
    if (leftEye != null && rightEye != null) {
      eyeAngle = math.atan2(
        (rightEye.y - leftEye.y).toDouble(),
        (rightEye.x - leftEye.x).toDouble(),
      ) / math.pi; // normalize to [-1, 1]
    }
    features.add(eyeAngle);

    // ─── Contour-based features (up to ~10 more) ───

    // 16-17. Nose bridge length and width from contours
    final noseBridge = face.contours[FaceContourType.noseBridge]?.points;
    final noseBottom = face.contours[FaceContourType.noseBottom]?.points;
    if (noseBridge != null && noseBridge.length >= 2) {
      features.add(_dist(noseBridge.first, noseBridge.last) / bh);
    } else {
      features.add(0.15);
    }
    if (noseBottom != null && noseBottom.length >= 2) {
      features.add(_dist(noseBottom.first, noseBottom.last) / bw);
    } else {
      features.add(0.15);
    }

    // 18-19. Left eye width/height from contour
    final leftEyeContour = face.contours[FaceContourType.leftEye]?.points;
    if (leftEyeContour != null && leftEyeContour.length >= 4) {
      final eyeW = _contourWidth(leftEyeContour) / bw;
      final eyeH = _contourHeight(leftEyeContour) / bh;
      features.add(eyeW);
      features.add(eyeH);
    } else {
      features.add(0.12);
      features.add(0.04);
    }

    // 20-21. Right eye width/height from contour
    final rightEyeContour = face.contours[FaceContourType.rightEye]?.points;
    if (rightEyeContour != null && rightEyeContour.length >= 4) {
      final eyeW = _contourWidth(rightEyeContour) / bw;
      final eyeH = _contourHeight(rightEyeContour) / bh;
      features.add(eyeW);
      features.add(eyeH);
    } else {
      features.add(0.12);
      features.add(0.04);
    }

    // 22-23. Upper lip height, lower lip height
    final upperLip = face.contours[FaceContourType.upperLipTop]?.points;
    final lowerLip = face.contours[FaceContourType.lowerLipBottom]?.points;
    if (upperLip != null && upperLip.length >= 3) {
      features.add(_contourHeight(upperLip) / bh);
    } else {
      features.add(0.03);
    }
    if (lowerLip != null && lowerLip.length >= 3) {
      features.add(_contourHeight(lowerLip) / bh);
    } else {
      features.add(0.04);
    }

    // 24-25. Left eyebrow arch, right eyebrow arch
    final leftBrow = face.contours[FaceContourType.leftEyebrowTop]?.points;
    final rightBrow = face.contours[FaceContourType.rightEyebrowTop]?.points;
    if (leftBrow != null && leftBrow.length >= 3) {
      features.add(_contourHeight(leftBrow) / bh);
    } else {
      features.add(0.03);
    }
    if (rightBrow != null && rightBrow.length >= 3) {
      features.add(_contourHeight(rightBrow) / bh);
    } else {
      features.add(0.03);
    }

    return features;
  }

  /// Euclidean distance between two ML Kit points.
  static double _dist(dynamic p1, dynamic p2) {
    return math.sqrt(
      math.pow((p1.x - p2.x).toDouble(), 2) +
      math.pow((p1.y - p2.y).toDouble(), 2),
    );
  }

  /// Width (max X - min X) of a contour point list.
  static double _contourWidth(List<dynamic> points) {
    double minX = double.infinity, maxX = double.negativeInfinity;
    for (final p in points) {
      final x = p.x.toDouble();
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
    }
    return (maxX - minX).abs();
  }

  /// Height (max Y - min Y) of a contour point list.
  static double _contourHeight(List<dynamic> points) {
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final p in points) {
      final y = p.y.toDouble();
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    return (maxY - minY).abs();
  }
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen>
    with SingleTickerProviderStateMixin {
  // Step: 0 = choose photo, 1 = detecting, 2 = preview + name, 3 = multi-angle capture, 4 = success
  int _step = 0;

  // Multi-angle capture data
  final List<File> _capturedImages = [];
  final List<List<Face>> _capturedFaces = [];
  final List<Size> _capturedImageSizes = [];
  final List<String> _captureLabels = ['Front View', 'Slight Left Turn', 'Slight Right Turn'];
  int _currentCaptureIndex = 0;

  File? _pickedImage;
  List<Face> _detectedFaces = [];
  Size _imageSize = Size.zero;
  bool _isDetecting = false;
  String _errorMessage = '';

  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  late FaceDetector _faceDetector;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: true,
        enableClassification: true,
        minFaceSize: 0.10,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScreenTutorialCard.showIfNeeded(
        context,
        tutorialKey: 'faces',
        titleKey: 'tutorial_faces_title',
        descriptionKey: 'tutorial_faces_desc',
        mascotAsset: 'assets/mascots/05_welcome.gif',
      );
    });
  }

  @override
  void dispose() {
    _faceDetector.close();
    _nameController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }



  // ── Pick image & detect ───────────────────────────────────────────────
  Future<void> _pickAndDetect(ImageSource source) async {
    setState(() {
      _errorMessage = '';
      _detectedFaces = [];
      _pickedImage = null;
    });
    try {
      final picked = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
      );
      if (picked == null) return;

      final file = File(picked.path);
      setState(() {
        _pickedImage = file;
        _step = 1;
        _isDetecting = true;
      });

      // Decode image dimensions
      final decodedImage = await decodeImageFromList(await file.readAsBytes());
      final imgSize = Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );

      final inputImage = InputImage.fromFile(file);
      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _isDetecting = false;
          _errorMessage = 'No face detected. Please try again with a clearer photo facing the camera.';
          _step = 0;
          _pickedImage = null;
        });
      } else {
        setState(() {
          _detectedFaces = faces;
          _imageSize = imgSize;
          _isDetecting = false;
          _step = 2; // Proceed to preview + name input
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDetecting = false;
        _step = 0;
        _errorMessage = 'Something went wrong: ${e.toString()}';
      });
    }
  }

  /// Capture additional angle for multi-sample registration
  Future<void> _captureAngle(ImageSource source) async {
    setState(() {
      _errorMessage = '';
      _isDetecting = true;
    });
    try {
      final picked = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
      );
      if (picked == null) {
        setState(() => _isDetecting = false);
        return;
      }

      final file = File(picked.path);
      final decodedImage = await decodeImageFromList(await file.readAsBytes());
      final imgSize = Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );

      final inputImage = InputImage.fromFile(file);
      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _isDetecting = false;
          _errorMessage = 'No face detected in ${_captureLabels[_currentCaptureIndex]}. Please try again.';
        });
      } else {
        _capturedImages.add(file);
        _capturedFaces.add(faces);
        _capturedImageSizes.add(imgSize);

        if (_currentCaptureIndex < 2) {
          setState(() {
            _currentCaptureIndex++;
            _isDetecting = false;
          });
        } else {
          // All 3 angles captured — save
          setState(() => _isDetecting = false);
          await _saveProfile();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDetecting = false;
        _errorMessage = 'Capture failed: ${e.toString()}';
      });
    }
  }

  // ── Save profile ──────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name.')),
      );
      return;
    }

    // Extract features from all captured samples
    final allSamples = <List<double>>[];

    // First capture (from step 2)
    if (_detectedFaces.isNotEmpty) {
      allSamples.add(FaceRegistrationScreen.extractFaceFeatures(_detectedFaces.first, _imageSize));
    }

    // Additional multi-angle captures (from step 3)
    for (int i = 0; i < _capturedFaces.length; i++) {
      if (_capturedFaces[i].isNotEmpty) {
        allSamples.add(FaceRegistrationScreen.extractFaceFeatures(_capturedFaces[i].first, _capturedImageSizes[i]));
      }
    }

    // Use the first sample as the primary faceFeatures for backward compatibility
    final primaryFeatures = allSamples.isNotEmpty ? allSamples.first : null;

    final profile = FaceProfile(
      id: 'face_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      imageLocalPath: _pickedImage?.path,
      faceFeatures: primaryFeatures,
      multiSampleFeatures: allSamples.length > 1 ? allSamples : null,
      registeredAt: DateTime.now(),
    );
    await FaceRegistrationService().saveProfile(profile);
    if (!mounted) return;
    setState(() => _step = 4);
  }

  /// Quick save with just the first photo (skip multi-angle)
  Future<void> _quickSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name.')),
      );
      return;
    }

    List<double>? features;
    if (_detectedFaces.isNotEmpty) {
      features = FaceRegistrationScreen.extractFaceFeatures(_detectedFaces.first, _imageSize);
    }

    final profile = FaceProfile(
      id: 'face_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      imageLocalPath: _pickedImage?.path,
      faceFeatures: features,
      registeredAt: DateTime.now(),
    );
    await FaceRegistrationService().saveProfile(profile);
    if (!mounted) return;
    setState(() => _step = 4);
  }

  // ── Builders ──────────────────────────────────────────────────────────

  // ── Builders ──────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    final labels = ['Capture', 'Detect', 'Name', 'Angles', 'Done'];
    final activeStep = _step > 4 ? 4 : _step;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(labels.length, (i) {
        final isActive = i <= activeStep;
        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: i == activeStep ? 28 : 18,
              height: 18,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryButton
                    : AppColors.unselectedBorder,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isActive ? AppColors.primaryButtonText : AppColors.textMuted,
                  ),
                ),
              ),
            ),
            if (i < labels.length - 1)
              Container(
                width: 20,
                height: 2,
                color: i < activeStep
                    ? AppColors.primaryButton
                    : AppColors.unselectedBorder,
              ),
          ],
        );
      }),
    );
  }

  Widget _buildStep0() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Hero Mascot GIF
        ScaleTransition(
          scale: _pulseAnim,
          child: Container(
            width: 140,
            height: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.lightBackground,
              border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowColor,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/mascots/05_welcome.gif',
                width: 116,
                height: 116,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.face_retouching_natural,
                  size: 60,
                  color: AppColors.primaryButton,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Register a Face',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Take a clear photo of someone.\nBuddy will remember their landmark profile and announce their name.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage,
                    style: GoogleFonts.inter(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 36),
        // Camera button
        _GlassButton(
          icon: Icons.camera_alt_rounded,
          label: 'Take a Photo',
          isPrimary: true,
          onTap: () => _pickAndDetect(ImageSource.camera),
        ),
        const SizedBox(height: 12),
        // Gallery button
        _GlassButton(
          icon: Icons.photo_library_rounded,
          label: 'Choose from Gallery',
          isPrimary: false,
          onTap: () => _pickAndDetect(ImageSource.gallery),
        ),
        const SizedBox(height: 20),
        // View registered faces link
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              AppRoute.to(const RegisteredFacesScreen()),
            );
          },
          icon: Icon(Icons.people_alt_rounded, color: AppColors.primaryButton, size: 18),
          label: Text(
            'View Registered Faces',
            style: GoogleFonts.inter(
              color: AppColors.primaryButton,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_pickedImage != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Image.file(
                _pickedImage!,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        const SizedBox(height: 24),
        Image.asset(
          'assets/mascots/03_loading.gif',
          width: 100,
          height: 100,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => CircularProgressIndicator(
            color: AppColors.primaryButton,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Scanning for faces…',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'ML Kit is analyzing 25+ facial geometric landmarks',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        // Image with bounding box + landmark dots overlay
        LayoutBuilder(
          builder: (context, constraints) {
            final displayWidth = constraints.maxWidth;
            const displayHeight = 280.0;
            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: displayWidth,
                height: displayHeight,
                child: Stack(
                  children: [
                    Image.file(
                      _pickedImage!,
                      width: displayWidth,
                      height: displayHeight,
                      fit: BoxFit.cover,
                    ),
                    // Draw bounding boxes and landmark dots for each detected face
                    if (_imageSize != Size.zero)
                      ..._detectedFaces.map((face) {
                        final scaleX = displayWidth / _imageSize.width;
                        final scaleY = displayHeight / _imageSize.height;
                        final r = face.boundingBox;
                        return Stack(
                          children: [
                            // Bounding box
                            Positioned(
                              left: r.left * scaleX,
                              top: r.top * scaleY,
                              width: r.width * scaleX,
                              height: r.height * scaleY,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.greenAccent,
                                    width: 2.5,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.only(
                                        bottomRight: Radius.circular(4),
                                      ),
                                    ),
                                    child: Text(
                                      '✓ Face Detected',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Landmark dots
                            ..._buildLandmarkDots(face, scaleX, scaleY),
                          ],
                        );
                      }),
                    // Detected count badge
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBackground.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4), width: 1.2),
                        ),
                        child: Text(
                          '${_detectedFaces.length} face${_detectedFaces.length != 1 ? 's' : ''} • ${_getFeatureCount()} points',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryButton,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        // Name input
        Text(
          'Who is this person?',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Buddy will announce their name when recognized.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: AppColors.lightBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
          ),
          child: TextField(
            controller: _nameController,
            style: GoogleFonts.inter(
                color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Enter name (e.g. Mom, John)',
              hintStyle: GoogleFonts.inter(
                  color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 15),
              prefixIcon: Icon(Icons.badge_rounded, color: AppColors.primaryButton),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ),
        const SizedBox(height: 20),
        // Multi-angle capture button (recommended)
        _GlassButton(
          icon: Icons.camera_enhance_rounded,
          label: 'Continue with 3-Angle Capture',
          isPrimary: true,
          onTap: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a name first.')),
              );
              return;
            }
            // Store first capture
            _capturedImages.clear();
            _capturedFaces.clear();
            _capturedImageSizes.clear();
            _capturedImages.add(_pickedImage!);
            _capturedFaces.add(_detectedFaces);
            _capturedImageSizes.add(_imageSize);
            setState(() {
              _currentCaptureIndex = 1; // Next is "Slight Left"
              _step = 3;
              _errorMessage = '';
            });
          },
        ),
        const SizedBox(height: 12),
        // Quick save (single photo)
        _GlassButton(
          icon: Icons.save_rounded,
          label: 'Quick Save (1 Photo Only)',
          isPrimary: false,
          onTap: _quickSave,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() {
              _step = 0;
              _pickedImage = null;
              _detectedFaces = [];
              _nameController.clear();
              _errorMessage = '';
            });
          },
          child: Text(
            'Retake Photo',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    // Multi-angle capture step
    final label = _captureLabels[_currentCaptureIndex];
    final capturedCount = _currentCaptureIndex; // 0-indexed, but first is already done
    final totalAngles = 3;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Progress indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryButton.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < totalAngles; i++) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < capturedCount
                        ? Colors.green
                        : i == capturedCount
                            ? AppColors.primaryButton
                            : AppColors.unselectedBorder,
                  ),
                  child: Center(
                    child: Icon(
                      i < capturedCount ? Icons.check : Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                if (i < totalAngles - 1)
                  Container(
                    width: 32,
                    height: 2,
                    color: i < capturedCount
                        ? Colors.green
                        : AppColors.unselectedBorder,
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        // Mascot guiding turn angle
        Image.asset(
          'assets/mascots/06_thinking.gif',
          width: 120,
          height: 120,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            _currentCaptureIndex == 0
                ? Icons.face
                : _currentCaptureIndex == 1
                    ? Icons.rotate_left
                    : Icons.rotate_right,
            size: 80,
            color: AppColors.primaryButton,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _currentCaptureIndex == 1
              ? 'Turn your head slightly to the LEFT\nand take a photo.'
              : 'Turn your head slightly to the RIGHT\nand take a photo.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage,
                    style: GoogleFonts.inter(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
        if (_isDetecting)
          CircularProgressIndicator(color: AppColors.primaryButton, strokeWidth: 3)
        else ...[
          _GlassButton(
            icon: Icons.camera_alt_rounded,
            label: 'Capture $label',
            isPrimary: true,
            onTap: () => _captureAngle(ImageSource.camera),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              await _saveProfile();
            },
            child: Text(
              'Skip & Save with ${capturedCount + 1} photo${capturedCount > 0 ? 's' : ''}',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep4() {
    final name = _nameController.text.trim();
    final sampleCount = 1 + _capturedFaces.length;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Mascot Congratulations Animation
        Image.asset(
          'assets/mascots/04_congratulations.gif',
          width: 140,
          height: 140,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryButton,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 58),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          '🎉 Face Registered!',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '"$name" has been saved with $sampleCount angle${sampleCount > 1 ? 's' : ''}.\nBuddy will recognize them in real-time.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textMuted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 40),
        _GlassButton(
          icon: Icons.add_a_photo_rounded,
          label: 'Register Another',
          isPrimary: true,
          onTap: () {
            setState(() {
              _step = 0;
              _pickedImage = null;
              _detectedFaces = [];
              _capturedImages.clear();
              _capturedFaces.clear();
              _capturedImageSizes.clear();
              _currentCaptureIndex = 0;
              _nameController.clear();
              _errorMessage = '';
            });
          },
        ),
        const SizedBox(height: 12),
        _GlassButton(
          icon: Icons.people_alt_rounded,
          label: 'View All Registered Faces',
          isPrimary: false,
          onTap: () {
            Navigator.of(context).pushReplacement(
              AppRoute.to(const RegisteredFacesScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            SoundService.playClick();
            Navigator.of(context).pop();
          },
          child: Text(
            'Back to Dashboard',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Build landmark dot widgets for a face
  List<Widget> _buildLandmarkDots(Face face, double scaleX, double scaleY) {
    final dots = <Widget>[];
    const dotSize = 5.0;
    final dotColor = AppColors.primaryButton;

    // Draw all available landmarks as dots
    for (final type in FaceLandmarkType.values) {
      final landmark = face.landmarks[type];
      if (landmark != null) {
        dots.add(Positioned(
          left: landmark.position.x * scaleX - dotSize / 2,
          top: landmark.position.y * scaleY - dotSize / 2,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
        ));
      }
    }

    // Draw contour points as smaller dots
    const contourDotSize = 3.0;
    final contourColor = AppColors.primaryButton.withValues(alpha: 0.7);
    for (final type in FaceContourType.values) {
      final contour = face.contours[type];
      if (contour != null) {
        for (final point in contour.points) {
          dots.add(Positioned(
            left: point.x * scaleX - contourDotSize / 2,
            top: point.y * scaleY - contourDotSize / 2,
            child: Container(
              width: contourDotSize,
              height: contourDotSize,
              decoration: BoxDecoration(
                color: contourColor,
                shape: BoxShape.circle,
              ),
            ),
          ));
        }
      }
    }

    return dots;
  }

  int _getFeatureCount() {
    if (_detectedFaces.isEmpty) return 0;
    return FaceRegistrationScreen.extractFaceFeatures(_detectedFaces.first, _imageSize).length;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.primaryBackground,
          appBar: AppBar(
            backgroundColor: AppColors.primaryBackground,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.primaryText),
              onPressed: () {
                SoundService.playClick();
                Navigator.of(context).pop();
              },
            ),
            title: Text(
              'Face Registration',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
          ),
          bottomNavigationBar: CustomNavbar(
            currentIndex: 0,
            onTap: (index) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            onEasyLensTap: () {
              BuddyAssistantSheet.show(
                context,
                onNavigate: (screenKey) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              );
            },
          ),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Step indicator
                _buildStepIndicator(),
                const SizedBox(height: 24),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _step == 0
                            ? _buildStep0()
                            : _step == 1
                                ? _buildStep1()
                                : _step == 2
                                    ? _buildStep2()
                                    : _step == 3
                                        ? _buildStep3()
                                        : _buildStep4(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Reusable glass-style button ────────────────────────────────────────────────
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _GlassButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: isPrimary
          ? ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryButton,
                foregroundColor: AppColors.primaryButtonText,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
              ),
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.lightBackground,
                foregroundColor: AppColors.primaryText,
                side: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.4), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
              ),
              onPressed: onTap,
              icon: Icon(icon, size: 20, color: AppColors.primaryText),
              label: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }
}
