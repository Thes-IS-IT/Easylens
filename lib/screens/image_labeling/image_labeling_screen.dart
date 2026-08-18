import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../constants/colors.dart';
import '../../services/tts_service.dart';
import '../../services/settings_service.dart';
import '../../services/rag_service.dart';
import '../dashboard/components/custom_navbar.dart';
import '../hardware/hardware_screen.dart';
import '../../utils/app_route.dart';
import '../../widgets/screen_tutorial_card.dart';
import '../../services/sound_service.dart';

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
  String _displayedExtractedText = '';
  String _explanation = '';
  String _displayedExplanation = '';

  bool _isLoading = false;
  bool _isSpeaking = false;
  bool _isExplaining = false;

  // Mascot GIF Asset & Dynamic Speech state
  String _mascotAsset = 'assets/mascots/01_happy.gif';
  String _buddySpeech =
      "Woof! Point your camera at any text — menus, signs, labels — and I'll read it aloud for you!";

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  Timer? _typewriterTimer;
  Timer? _explanationTypewriterTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScreenTutorialCard.showIfNeeded(
        context,
        tutorialKey: 'labeling',
        titleKey: 'tutorial_labeling_title',
        descriptionKey: 'tutorial_labeling_desc',
        mascotAsset: 'assets/mascots/05_welcome.gif',
      );
    });
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _explanationTypewriterTimer?.cancel();
    _pulseController.dispose();
    _textRecognizer.close();
    TtsService().stop();
    super.dispose();
  }

  void _startTypewriterForExtractedText(String fullText) {
    _typewriterTimer?.cancel();
    int index = 0;
    setState(() => _displayedExtractedText = '');
    _typewriterTimer =
        Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (index < fullText.length) {
        final step = min(4, fullText.length - index);
        index += step;
        setState(() {
          _displayedExtractedText = fullText.substring(0, index);
        });
      } else {
        timer.cancel();
        setState(() {
          _displayedExtractedText = fullText;
        });
      }
    });
  }

  void _startTypewriterForExplanation(String fullText) {
    _explanationTypewriterTimer?.cancel();
    int index = 0;
    setState(() => _displayedExplanation = '');
    _explanationTypewriterTimer =
        Timer.periodic(const Duration(milliseconds: 18), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (index < fullText.length) {
        final step = min(3, fullText.length - index);
        index += step;
        setState(() {
          _displayedExplanation = fullText.substring(0, index);
        });
      } else {
        timer.cancel();
        setState(() {
          _displayedExplanation = fullText;
        });
      }
    });
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
        _displayedExtractedText = '';
        _explanation = '';
        _displayedExplanation = '';
        _isLoading = true;
        _isSpeaking = false;
        _isExplaining = false;
        _mascotAsset = 'assets/mascots/03_loading.gif';
        _buddySpeech = "Looking closely at the text... hold on a second!";
      });

      await TtsService().stop();
      await TtsService().speak("Scanning image for text...");

      final inputImage = InputImage.fromFile(_image!);
      final RecognizedText result =
          await _textRecognizer.processImage(inputImage);

      final text = result.text.trim();

      if (text.isNotEmpty) {
        setState(() {
          _extractedText = text;
          _isLoading = false;
          _mascotAsset = 'assets/mascots/01_happy.gif';
          _buddySpeech =
              "Woof! I found text! Here is what I read for you:";
          _isSpeaking = true;
        });

        _startTypewriterForExtractedText(text);
        await TtsService().speak(text);
        if (mounted) {
          setState(() => _isSpeaking = false);
        }
      } else {
        setState(() {
          _isLoading = false;
          _mascotAsset = 'assets/mascots/02_error.gif';
          _buddySpeech =
              "Oops! I couldn't find any clear text in this image. Try taking another picture closer up!";
        });
        await TtsService()
            .speak('No text found in this image. Please try another photo.');
      }
    } catch (e) {
      print('OCR error: $e');
      setState(() {
        _isLoading = false;
        _mascotAsset = 'assets/mascots/02_error.gif';
        _buddySpeech = "Oh no! Something went wrong while reading the image.";
      });
      await TtsService().speak('An error occurred while reading the image.');
    }
  }

  Future<void> _readAloud() async {
    if (_extractedText.isEmpty) return;
    setState(() {
      _isSpeaking = true;
      _mascotAsset = 'assets/mascots/01_happy.gif';
      _buddySpeech = "Reading out loud for you...";
    });
    await TtsService().speak(_extractedText);
    if (mounted) {
      setState(() => _isSpeaking = false);
    }
  }

  Future<void> _stopReading() async {
    await TtsService().stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _buddySpeech = "Paused reading. Tap Read Aloud to resume!";
      });
    }
  }

  Future<void> _explainText() async {
    if (_extractedText.isEmpty) return;
    setState(() {
      _isExplaining = true;
      _mascotAsset = 'assets/mascots/06_thinking.gif';
      _buddySpeech =
          "Buddy is thinking real hard about what this text means...";
    });

    await TtsService().stop();
    setState(() => _isSpeaking = false);

    final prompt =
        "Analyze and give a clear, simple, and friendly explanation of the following text scanned nearby: '$_extractedText'. Focus on what it means and why it might be important. Keep it concise, warm, and helpful.";
    final result = await RagService().askBuddy(prompt);

    if (mounted) {
      setState(() {
        _explanation = result;
        _isExplaining = false;
        _mascotAsset = 'assets/mascots/01_happy.gif';
        _buddySpeech = "Here is my simple explanation for you!";
        _isSpeaking = true;
      });

      _startTypewriterForExplanation(result);
      await TtsService().speak(result);
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    }
  }

  Future<void> _copyTextToClipboard() async {
    if (_extractedText.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _extractedText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Text copied to clipboard!',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      await TtsService().speak("Text copied to clipboard!");
    }
  }

  void _clearImageAndText() {
    TtsService().stop();
    setState(() {
      _image = null;
      _extractedText = '';
      _displayedExtractedText = '';
      _explanation = '';
      _displayedExplanation = '';
      _isSpeaking = false;
      _isExplaining = false;
      _mascotAsset = 'assets/mascots/01_happy.gif';
      _buddySpeech =
          "Woof! Point your camera at any text — menus, signs, labels — and I'll read it aloud for you!";
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final settings = SettingsService();
        final theme = settings.selectedContrastTheme;
        final isDefault = theme == 'Default';
        final isBlack = settings.appearanceTheme == 'Black';

        return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: GestureDetector(
            onTap: () {
              SoundService.playClick();
              TtsService().stop();
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_ios_new, size: 14, color: AppColors.primaryText),
                  const SizedBox(width: 4),
                  Text(
                    'Back',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        leadingWidth: 100,
        title: Text(
          'Nearby Text',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            color: AppColors.primaryText,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_image != null || _extractedText.isNotEmpty)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.primaryText),
              tooltip: 'Reset Camera',
              onPressed: _clearImageAndText,
            ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ── Cute Animated Buddy Speech Banner Header ─────────────
                _buildBuddyMascotHeader(isDefault, isBlack),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Camera/Gallery Action Bar ─────────────────────
                        _buildScanActionBar(isDefault),
                        const SizedBox(height: 16),

                        // ── Image Preview Viewfinder ─────────────────────
                        _buildImagePreviewViewfinder(isDefault),
                        const SizedBox(height: 20),

                        // ── OCR Extracted Text Card ───────────────────────
                        if (_extractedText.isNotEmpty || _isLoading)
                          _buildExtractedTextCard(isDefault),

                        // ── Buddy's Explanation Card ─────────────────────
                        if (_isExplaining || _explanation.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _buildExplanationCard(isDefault),
                        ],

                        // Spacing so floating navbar does not cover content
                        const SizedBox(height: 160),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Floating Custom Navbar ─────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomNavbar(
              currentIndex: 0,
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
                  AppRoute.to(const HardwareScreen(initialStep: 4)),
                );
              },
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  /// Cute Buddy Mascot Header with animated GIF & speech bubble
  Widget _buildBuddyMascotHeader(bool isDefault, bool isBlack) {
    final bannerBg = isDefault
        ? const Color(0xFF002663)
        : (isBlack ? AppColors.primaryBackground : Colors.black);

    final bubbleBg = isDefault ? Colors.white : AppColors.primaryBackground;
    final headerTextColor =
        isDefault ? const Color(0xFF002663) : AppColors.primaryText;
    final bodyTextColor =
        isDefault ? const Color(0xFF334155) : AppColors.primaryText;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isDefault
            ? const LinearGradient(
                colors: [Color(0xFF001B47), Color(0xFF002663), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isDefault ? null : bannerBg,
        boxShadow: [
          if (isDefault)
            BoxShadow(
              color: const Color(0xFF002663).withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Buddy Mascot GIF (just the mascot without circular frame/border)
          ScaleTransition(
            scale: _pulseAnim,
            child: SizedBox(
              width: 96,
              height: 96,
              child: Image.asset(
                _mascotAsset,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Speech Bubble Card
          Expanded(
            child: GestureDetector(
              onTap: () {
                TtsService().speak(_buddySpeech);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: bubbleBg,
                  borderRadius: BorderRadius.circular(20),
                  border: isDefault
                      ? Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5)
                      : Border.all(color: AppColors.cardBorder, width: 1.5),
                  boxShadow: [
                    if (isDefault)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Buddy',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            color: headerTextColor,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isLoading
                                ? const Color(0xFFF59E0B)
                                : (_isSpeaking
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF2563EB)),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDefault
                                ? const Color(0xFFEFF6FF)
                                : AppColors.unselectedBorder,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.volume_up_rounded,
                                size: 13,
                                color: isDefault ? const Color(0xFF2563EB) : headerTextColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tap to Hear',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDefault ? const Color(0xFF2563EB) : headerTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _buddySpeech,
                      style: GoogleFonts.inter(
                        color: bodyTextColor,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Scan Action Bar (Take Photo vs Gallery Buttons)
  Widget _buildScanActionBar(bool isDefault) {
    return Row(
      children: [
        Expanded(
          child: _CuteButton(
            icon: Icons.camera_alt_rounded,
            label: 'Take Photo',
            gradientColors: isDefault
                ? const [Color(0xFF002663), Color(0xFF1D4ED8)]
                : null,
            color: AppColors.primaryButton,
            textColor: isDefault ? Colors.white : AppColors.primaryButtonText,
            isPrimary: true,
            isDisabled: _isLoading,
            onTap: () => _scanText(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CuteButton(
            icon: Icons.photo_library_rounded,
            label: 'Upload Gallery',
            gradientColors: isDefault
                ? const [Color(0xFF2563EB), Color(0xFF3B82F6)]
                : null,
            color: isDefault ? const Color(0xFF2563EB) : AppColors.primaryButton,
            textColor: isDefault ? Colors.white : AppColors.primaryButtonText,
            isPrimary: true,
            isDisabled: _isLoading,
            onTap: () => _scanText(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  /// Camera/Gallery Viewfinder & Image Preview
  Widget _buildImagePreviewViewfinder(bool isDefault) {
    if (_isLoading) {
      return Container(
        height: 210,
        decoration: BoxDecoration(
          color: AppColors.primaryBackground,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDefault ? const Color(0xFF2563EB) : AppColors.cardBorder,
            width: 2,
          ),
          boxShadow: [
            if (isDefault)
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
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
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: (isDefault ? const Color(0xFF2563EB) : AppColors.primaryButton)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.center_focus_strong_rounded,
                    color: isDefault ? const Color(0xFF2563EB) : AppColors.primaryText,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Buddy is scanning the text…',
                style: GoogleFonts.inter(
                  color: isDefault ? const Color(0xFF002663) : AppColors.primaryText,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Extracting words & sentences with OCR',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
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
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDefault ? const Color(0xFF002663) : AppColors.cardBorder,
            width: 2,
          ),
          boxShadow: [
            if (isDefault)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.file(
                _image!,
                height: 210,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            // Top Status Badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Photo Ready',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Default Camera Scanner Viewfinder Placeholder
    return Container(
      height: 255,
      decoration: BoxDecoration(
        color: isDefault ? const Color(0xFFF8FAFC) : AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDefault
              ? const Color(0xFF2563EB).withValues(alpha: 0.3)
              : AppColors.cardBorder,
          width: 2,
        ),
        boxShadow: [
          if (isDefault)
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _scanText(ImageSource.camera),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDefault
                          ? const Color(0xFFEFF6FF)
                          : AppColors.unselectedBorder,
                      shape: BoxShape.circle,
                      border: isDefault
                          ? Border.all(color: const Color(0xFF93C5FD), width: 1.5)
                          : null,
                    ),
                    child: Icon(
                      Icons.add_a_photo_rounded,
                      size: 42,
                      color: isDefault
                          ? const Color(0xFF2563EB)
                          : AppColors.primaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap here to take a photo of text',
                  style: GoogleFonts.inter(
                    color: isDefault ? const Color(0xFF002663) : AppColors.primaryText,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Menus, labels, books, signs & documents',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),

                // Feature Pill Badges Wrap
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildFeaturePill('⚡ Fast OCR', isDefault),
                    _buildFeaturePill('🔊 Read Aloud', isDefault),
                    _buildFeaturePill('🤖 AI Assistant', isDefault),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePill(String label, bool isDefault) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDefault ? Colors.white : AppColors.unselectedBorder,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? const Color(0xFFE2E8F0) : AppColors.cardBorder,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDefault ? const Color(0xFF334155) : AppColors.primaryText,
        ),
      ),
    );
  }

  /// OCR Extracted Text Card with Typewriter Effect & Controls
  Widget _buildExtractedTextCard(bool isDefault) {
    final wordCount = _extractedText.trim().isEmpty
        ? 0
        : _extractedText.trim().split(RegExp(r'\s+')).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1.5,
        ),
        boxShadow: [
          if (isDefault)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDefault
                      ? const Color(0xFF3F83F8).withValues(alpha: 0.12)
                      : AppColors.unselectedBorder,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.text_snippet_rounded,
                  color: isDefault ? const Color(0xFF3F83F8) : AppColors.primaryText,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Extracted Text',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryText,
                    ),
                  ),
                  Text(
                    '$wordCount words • ${_extractedText.length} chars',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (_isSpeaking)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.volume_up_rounded,
                          color: Color(0xFF10B981), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Reading…',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.unselectedBorder),
          const SizedBox(height: 14),

          // Animated Typewriter Text Container
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDefault
                  ? const Color(0xFFF8FAFC)
                  : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.unselectedBorder,
                width: 1,
              ),
            ),
            child: SelectableText(
              _displayedExtractedText.isNotEmpty
                  ? _displayedExtractedText
                  : _extractedText,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.6,
                color: AppColors.primaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Toolbar Buttons (Read Aloud, Explain, Copy)
          Row(
            children: [
              Expanded(
                child: _isSpeaking
                    ? _CuteButton(
                        icon: Icons.stop_circle_rounded,
                        label: 'Stop',
                        color: const Color(0xFFEF4444),
                        textColor: Colors.white,
                        isPrimary: true,
                        onTap: _stopReading,
                      )
                    : _CuteButton(
                        icon: Icons.volume_up_rounded,
                        label: 'Read Aloud',
                        color: isDefault
                            ? const Color(0xFF10B981)
                            : AppColors.primaryButton,
                        textColor: Colors.white,
                        isPrimary: true,
                        onTap: _readAloud,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CuteButton(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Explain Text',
                  color: isDefault
                      ? const Color(0xFF8B5CF6)
                      : AppColors.primaryButton,
                  textColor: Colors.white,
                  isPrimary: true,
                  onTap: _explainText,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: isDefault
                      ? const Color(0xFFE2E8F0)
                      : AppColors.unselectedBorder,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: 'Copy Text',
                onPressed: _copyTextToClipboard,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Buddy's AI Explanation Card with Animated Response
  Widget _buildExplanationCard(bool isDefault) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryButton.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryButton.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primaryButton,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Buddy's Explanation ✨",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryText,
                    ),
                  ),
                  Text(
                    'AI Summary & Key Takeaways',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.unselectedBorder),
          const SizedBox(height: 14),

          if (_isExplaining)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryButton),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "Buddy is crafting your explanation…",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            )
          else
            SelectableText(
              _displayedExplanation.isNotEmpty
                  ? _displayedExplanation
                  : _explanation,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.6,
                color: AppColors.primaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

/// Cute Custom Button Widget with Rounded Styling & Scale Feedback
class _CuteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final List<Color>? gradientColors;
  final bool isPrimary;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _CuteButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    this.gradientColors,
    this.isPrimary = true,
    this.isDisabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            gradient: (isPrimary && gradientColors != null && !isDisabled)
                ? LinearGradient(
                    colors: gradientColors!,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: (isPrimary && gradientColors == null) ? color : (isPrimary ? null : Colors.transparent),
            borderRadius: BorderRadius.circular(18),
            border: isPrimary ? null : Border.all(color: color, width: 2),
            boxShadow: [
              if (isPrimary && !isDisabled)
                BoxShadow(
                  color: (gradientColors != null ? gradientColors!.first : color)
                      .withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isPrimary ? textColor : color, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isPrimary ? textColor : color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
