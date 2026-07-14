import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../services/face_registration_service.dart';
import '../../constants/colors.dart';
import '../dashboard/components/custom_navbar.dart';
import '../dashboard/components/buddy_assistant_sheet.dart';
import 'registered_faces_screen.dart';
import '../../utils/app_route.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen>
    with SingleTickerProviderStateMixin {
  // Step: 0 = choose photo, 1 = detecting, 2 = name input, 3 = success
  int _step = 0;

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
        enableLandmarks: false,
        enableContours: false,
        enableClassification: false,
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
          _step = 2; // Proceed to name input
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

  // ── Save profile ──────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name.')),
      );
      return;
    }
    final profile = FaceProfile(
      id: 'face_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      imageLocalPath: _pickedImage?.path,
      registeredAt: DateTime.now(),
    );
    await FaceRegistrationService().saveProfile(profile);
    if (!mounted) return;
    setState(() => _step = 3);
  }

  // ── Builders ──────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    final labels = ['Capture', 'Detect', 'Name', 'Done'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(labels.length, (i) {
        final isActive = i <= _step;
        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: i == _step ? 28 : 18,
              height: 18,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF7C3AED)
                    : AppColors.unselectedBorder,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (i < labels.length - 1)
              Container(
                width: 24,
                height: 2,
                color: i < _step
                    ? const Color(0xFF7C3AED)
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
        // Hero icon
        ScaleTransition(
          scale: _pulseAnim,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.45),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.face_retouching_natural,
              size: 60,
              color: Colors.white,
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
          'Take a clear photo of someone.\nEasyLens will remember them by name.',
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
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.4)),
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
        const SizedBox(height: 40),
        // Camera button
        _GlassButton(
          icon: Icons.camera_alt_rounded,
          label: 'Take a Photo',
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          ),
          onTap: () => _pickAndDetect(ImageSource.camera),
        ),
        const SizedBox(height: 12),
        // Gallery button
        _GlassButton(
          icon: Icons.photo_library_rounded,
          label: 'Choose from Gallery',
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.12),
              Colors.white.withOpacity(0.06),
            ],
          ),
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
          icon: const Icon(Icons.people_alt_rounded,
              color: Color(0xFFA78BFA), size: 18),
          label: Text(
            'View Registered Faces',
            style: GoogleFonts.inter(
              color: const Color(0xFFA78BFA),
              fontWeight: FontWeight.w600,
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
            child: Image.file(
              _pickedImage!,
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 28),
        const CircularProgressIndicator(
          color: Color(0xFF7C3AED),
          strokeWidth: 3,
        ),
        const SizedBox(height: 16),
        Text(
          'Scanning for faces…',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'ML Kit is analyzing the image',
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
        // Image with bounding box overlay
        LayoutBuilder(
          builder: (context, constraints) {
            final displayWidth = constraints.maxWidth;
            const displayHeight = 240.0;
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
                    // Draw bounding boxes for each detected face
                    if (_imageSize != Size.zero)
                      ..._detectedFaces.map((face) {
                        final scaleX = displayWidth / _imageSize.width;
                        final scaleY = displayHeight / _imageSize.height;
                        final r = face.boundingBox;
                        return Positioned(
                          left: r.left * scaleX,
                          top: r.top * scaleY,
                          width: r.width * scaleX,
                          height: r.height * scaleY,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF34D399),
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
                                  color: Color(0xFF34D399),
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
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF34D399), width: 1.2),
                        ),
                        child: Text(
                          '${_detectedFaces.length} face${_detectedFaces.length != 1 ? 's' : ''} detected',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF34D399),
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
          'EasyLens will announce their name when seen.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: AppColors.primaryBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.unselectedBorder),
          ),
          child: TextField(
            controller: _nameController,
            style: GoogleFonts.inter(
                color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Enter name (e.g. Mom, John)',
              hintStyle: GoogleFonts.inter(
                  color: AppColors.textMuted.withOpacity(0.6), fontSize: 15),
              prefixIcon: const Icon(Icons.badge_rounded,
                  color: Color(0xFF7C3AED)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _saveProfile(),
          ),
        ),
        const SizedBox(height: 20),
        _GlassButton(
          icon: Icons.save_rounded,
          label: 'Save Face Profile',
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          ),
          onTap: _saveProfile,
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
    final name = _nameController.text.trim();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Success animation
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF34D399), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF34D399).withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
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
          '"$name" has been saved.\nEasyLens will recognize them on the camera.',
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
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          ),
          onTap: () {
            setState(() {
              _step = 0;
              _pickedImage = null;
              _detectedFaces = [];
              _nameController.clear();
              _errorMessage = '';
            });
          },
        ),
        const SizedBox(height: 12),
        _GlassButton(
          icon: Icons.people_alt_rounded,
          label: 'View All Registered Faces',
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.12),
              Colors.white.withOpacity(0.06),
            ],
          ),
          onTap: () {
            Navigator.of(context).pushReplacement(
              AppRoute.to(const RegisteredFacesScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
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
                                : _buildStep3(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable glass-style button ────────────────────────────────────────────────
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  const _GlassButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
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
      ),
    );
  }
}
