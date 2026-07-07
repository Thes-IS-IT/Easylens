import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../constants/colors.dart';
import '../../services/tts_service.dart';
import '../../services/settings_service.dart';
import '../../services/rag_service.dart';
import '../dashboard/components/custom_navbar.dart';
import '../object_detection/object_detection_screen.dart';
import '../../utils/app_route.dart';

class ImageLabelingScreen extends StatefulWidget {
  final ValueChanged<int>? onTabSelected;
  const ImageLabelingScreen({super.key, this.onTabSelected});

  @override
  State<ImageLabelingScreen> createState() => _ImageLabelingScreenState();
}

class _ImageLabelingScreenState extends State<ImageLabelingScreen>
    with SingleTickerProviderStateMixin {
  File? _image;
  final _picker = ImagePicker();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  String _extractedText = '';
  String _explanation = '';
  bool _isLoading = false;
  bool _isSpeaking = false;
  bool _isExplaining = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textRecognizer.close();
    TtsService().stop();
    super.dispose();
  }

  Future<void> _scanText(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (picked == null) return;

      setState(() {
        _image = File(picked.path);
        _extractedText = '';
        _explanation = '';
        _isLoading = true;
        _isSpeaking = false;
        _isExplaining = false;
      });

      await TtsService().stop();

      final inputImage = InputImage.fromFile(_image!);
      final RecognizedText result =
          await _textRecognizer.processImage(inputImage);

      final text = result.text.trim();

      setState(() {
        _extractedText = text;
        _isLoading = false;
      });

      if (text.isNotEmpty) {
        setState(() => _isSpeaking = true);
        await TtsService().speak(text);
        setState(() => _isSpeaking = false);
      } else {
        await TtsService()
            .speak('No text found in this image. Try another photo.');
      }
    } catch (e) {
      print('OCR error: $e');
      setState(() => _isLoading = false);
      await TtsService().speak('An error occurred while reading the image.');
    }
  }

  Future<void> _readAloud() async {
    if (_extractedText.isEmpty) return;
    setState(() => _isSpeaking = true);
    await TtsService().speak(_extractedText);
    setState(() => _isSpeaking = false);
  }

  Future<void> _stopReading() async {
    await TtsService().stop();
    setState(() => _isSpeaking = false);
  }

  Future<void> _explainText() async {
    if (_extractedText.isEmpty) return;
    setState(() {
      _isExplaining = true;
    });

    await TtsService().stop();
    setState(() => _isSpeaking = false);

    // Call lightweight LLM to summarize/explain
    final prompt = "Analyze and give a clear, simple, and friendly explanation of the following text scanned nearby: '$_extractedText'. Focus on what it means and why it might be important. Keep it concise.";
    final result = await RagService().askBuddy(prompt);

    setState(() {
      _explanation = result;
      _isExplaining = false;
      _isSpeaking = true;
    });

    await TtsService().speak(result);
    setState(() => _isSpeaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SettingsService().selectedContrastTheme;
    final isDefault = theme == 'Default';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryButton,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.primaryButtonText),
          onPressed: () {
            TtsService().stop();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'Nearby Text',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryButtonText,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Content Area inside SafeArea (excluding bottom)
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ── Gradient header strip (only on default theme) ────────────
                if (isDefault)
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF002663), Color(0xFF3F83F8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Text(
                      'Point your camera at any text — menus, signs, labels, books — and Buddy will read it aloud for you.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    color: AppColors.primaryButton,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Text(
                      'Point your camera at any text — menus, signs, labels, books — and Buddy will read it aloud for you.',
                      style: GoogleFonts.inter(
                        color: AppColors.primaryButtonText,
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Image preview ─────────────────────────────────────
                        _buildImagePreview(isDefault),
                        const SizedBox(height: 20),

                        // ── Scan buttons ──────────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.camera_alt_rounded,
                                label: 'Take Photo',
                                color: AppColors.primaryButton,
                                textColor: AppColors.primaryButtonText,
                                isOutlined: false,
                                onTap: _isLoading
                                    ? null
                                    : () => _scanText(ImageSource.camera),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.photo_library_rounded,
                                label: 'Gallery',
                                color: isDefault ? const Color(0xFF3F83F8) : AppColors.primaryButton,
                                textColor: isDefault ? Colors.white : AppColors.primaryText,
                                isOutlined: !isDefault,
                                onTap: _isLoading
                                    ? null
                                    : () => _scanText(ImageSource.gallery),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── OCR result card ───────────────────────────────────
                        _buildResultCard(isDefault),

                        const SizedBox(height: 16),

                        // ── Speak / Stop / Explain buttons ──────────────────────────────
                        if (_extractedText.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          if (_isExplaining)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: isDefault ? const Color(0xFF3F83F8).withOpacity(0.1) : AppColors.unselectedBorder,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3F83F8)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Buddy is thinking…",
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryText,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: _isSpeaking
                                      ? _ActionButton(
                                          icon: Icons.stop_circle_rounded,
                                          label: 'Stop Reading',
                                          color: const Color(0xFFEF4444),
                                          textColor: Colors.white,
                                          isOutlined: false,
                                          onTap: _stopReading,
                                        )
                                      : _ActionButton(
                                          icon: Icons.record_voice_over_rounded,
                                          label: 'Read Aloud',
                                          color: isDefault ? const Color(0xFF238290) : AppColors.primaryButton,
                                          textColor: isDefault ? Colors.white : AppColors.primaryButtonText,
                                          isOutlined: false,
                                          onTap: _readAloud,
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ActionButton(
                                    icon: Icons.auto_awesome,
                                    label: 'Explain Text',
                                    color: const Color(0xFF85581A),
                                    textColor: Colors.white,
                                    isOutlined: false,
                                    onTap: _explainText,
                                  ),
                                ),
                              ],
                            ),
                          
                          if (_explanation.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildExplanationCard(isDefault),
                          ],
                        ],
                        // Spacing so it doesn't get covered by floating navbar
                        const SizedBox(height: 110),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Floating Navbar at the bottom (outside SafeArea so it spans fully and overlays properly)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomNavbar(
              currentIndex: 0, // Since it is a sub-feature of Home tab
              onTap: (index) {
                TtsService().stop();
                if (widget.onTabSelected != null) {
                  widget.onTabSelected!(index);
                } else {
                  Navigator.of(context).pop();
                }
              },
              onEasyLensTap: () {
                TtsService().stop();
                Navigator.of(context).pushReplacement(
                  AppRoute.to(const ObjectDetectionScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(bool isDefault) {
    if (_isLoading) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.primaryBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.unselectedBorder,
            width: 2,
          ),
          boxShadow: [
            if (isDefault)
              BoxShadow(
                color: const Color(0xFF3F83F8).withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnim,
                child: Icon(
                  Icons.document_scanner_rounded,
                  color: isDefault ? const Color(0xFF3F83F8) : AppColors.primaryText,
                  size: 56,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Reading text…',
                style: GoogleFonts.inter(
                  color: isDefault ? const Color(0xFF3F83F8) : AppColors.primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_image != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.unselectedBorder,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.file(
            _image!,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDefault ? const Color(0xFF3F83F8).withOpacity(0.3) : AppColors.unselectedBorder,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 56,
            color: isDefault ? const Color(0xFF3F83F8).withOpacity(0.5) : AppColors.primaryText,
          ),
          const SizedBox(height: 12),
          Text(
            'Tap "Take Photo" to scan nearby text',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(bool isDefault) {
    if (_extractedText.isEmpty && !_isLoading) {
      return const SizedBox.shrink();
    }

    if (_isLoading) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.unselectedBorder,
          width: 1,
        ),
        boxShadow: [
          if (isDefault)
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDefault ? const Color(0xFF3F83F8).withOpacity(0.1) : AppColors.unselectedBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.text_snippet_rounded,
                  color: AppColors.primaryText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Extracted Text',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.primaryText,
                ),
              ),
              const Spacer(),
              if (_isSpeaking)
                Row(
                  children: [
                    Icon(Icons.volume_up_rounded,
                        color: AppColors.primaryText, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Reading…',
                      style: GoogleFonts.inter(
                        color: AppColors.primaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.unselectedBorder),
          const SizedBox(height: 14),
          SelectableText(
            _extractedText,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.65,
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationCard(bool isDefault) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.unselectedBorder,
          width: 1,
        ),
        boxShadow: [
          if (isDefault)
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF85581A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF85581A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Buddy's Explanation",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.unselectedBorder),
          const SizedBox(height: 14),
          SelectableText(
            _explanation,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.65,
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final bool isOutlined;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.isOutlined,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isOutlined ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(16),
            border: isOutlined ? Border.all(color: color, width: 2) : null,
            boxShadow: [
              if (!isOutlined && !isDisabled && color != Colors.transparent)
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isOutlined ? color : textColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isOutlined ? color : textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
