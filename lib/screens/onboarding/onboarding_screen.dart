import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../signup/signup_screen.dart';
import '../login/login_screen.dart';
import '../../services/rag_service.dart';
import '../../services/sound_service.dart';
import '../../widgets/gyro_3d_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  bool _isModelInstalled = false;
  bool _isCheckingModel = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = "";
  bool _showLocalAiCard = true;

  late AnimationController _zoomDiveController;
  late Animation<double> _zoomScaleAnimation;
  late Animation<double> _zoomFadeAnimation;

  @override
  void initState() {
    super.initState();

    // Smooth, normal-paced cinematic zoom-in on the center white canvas
    _zoomDiveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _zoomScaleAnimation = Tween<double>(begin: 1.0, end: 8.0).animate(
      CurvedAnimation(
        parent: _zoomDiveController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _zoomFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _zoomDiveController,
        curve: const Interval(0.25, 0.85, curve: Curves.easeInOut),
      ),
    );

    _checkModelStatus();
  }

  @override
  void dispose() {
    _zoomDiveController.dispose();
    super.dispose();
  }

  Future<void> _checkModelStatus() async {
    setState(() {
      _isCheckingModel = true;
    });
    await RagService().extractModelFromAssets();
    final exists = await RagService().checkGemmaModelExists();
    setState(() {
      _isModelInstalled = exists;
      _isCheckingModel = false;
    });
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = "Initializing setup...";
    });

    final success = await RagService().downloadGemmaModel((progress) {
      setState(() {
        _downloadProgress = progress;
        _downloadStatus = progress < 1.0 
            ? "Downloading: ${(progress * 100).toStringAsFixed(0)}%"
            : "Finalizing install...";
      });
    });

    if (success) {
      setState(() {
        _isDownloading = false;
        _isModelInstalled = true;
      });
    } else {
      setState(() {
        _isDownloading = false;
        _downloadStatus = "Setup failed. Tap to try again.";
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Model download failed. Please check your internet connection and try again.",
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  /// Triggers a literal camera dive into the center white background, then smoothly fades in the destination screen.
  Future<void> _handleNavigate(Widget targetScreen) async {
    if (_isDownloading) return;
    SoundService.playPop();

    // 1. Dive deep into the center white canvas
    _zoomDiveController.forward();

    // 2. Wait until the zoom engulfs the viewport into clean white
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // 3. Seamlessly fade in the target screen over the white background
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        reverseTransitionDuration: const Duration(milliseconds: 480),
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return FadeTransition(
            opacity: fade,
            child: child,
          );
        },
      ),
    );

    // 4. When the user returns (pops back to this screen), smoothly zoom back out
    if (mounted) {
      _zoomDiveController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _zoomDiveController,
          builder: (context, child) {
            return Transform.scale(
              scale: _zoomScaleAnimation.value,
              alignment: Alignment.center,
              child: Opacity(
                opacity: _zoomFadeAnimation.value,
                child: child,
              ),
            );
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          
                          // 3D Gyroscopic Mascot Logo
                          Column(
                            children: [
                              const Gyro3dLogo(size: 170),
                              const SizedBox(height: 18),
                              // App Name
                              Text(
                                'BUDDY',
                                style: GoogleFonts.inter(
                                  textStyle: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryText,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // App Tagline
                              Text(
                                'VISION ASSISTANT',
                                style: GoogleFonts.inter(
                                  textStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryText,
                                    letterSpacing: 2.5,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Dynamic Local AI Setup Card S01
                          if (_isCheckingModel)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(color: Color(0xFF0F3E8F)),
                              ),
                            )
                          else if (_showLocalAiCard && !_isModelInstalled) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.lightBackground,
                                  border: Border.all(
                                    color: AppColors.cardBorder,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F3E8F).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: const Icon(
                                              Icons.offline_bolt_rounded,
                                              color: Color(0xFF0F3E8F),
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'On-Device AI Engine',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primaryText,
                                                  ),
                                                ),
                                                Text(
                                                  'Fast & private offline assistance',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: AppColors.primaryText.withOpacity(0.6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Download the Gemma 2 vision & speech model (~2.0GB) for continuous intelligence without needing internet.',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          height: 1.4,
                                          color: AppColors.primaryText.withOpacity(0.8),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      if (_isDownloading) ...[
                                        LinearProgressIndicator(
                                          value: _downloadProgress > 0 ? _downloadProgress : null,
                                          backgroundColor: AppColors.primaryText.withOpacity(0.1),
                                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F3E8F)),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _downloadStatus,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F3E8F),
                                          ),
                                        ),
                                      ] else ...[
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: _startDownload,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF0F3E8F),
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                ),
                                                child: Text(
                                                  'Download Model',
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: Icon(
                                                Icons.close_rounded,
                                                color: AppColors.primaryText.withOpacity(0.5),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _showLocalAiCard = false;
                                                });
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              splashRadius: 16,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Push the remaining widget to the bottom
                          const Spacer(),

                          // Bottom Action Buttons
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Sign Up Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryButton,
                                    foregroundColor: AppColors.primaryButtonText,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28.0),
                                    ),
                                  ),
                                  onPressed: _isDownloading
                                      ? null
                                      : () => _handleNavigate(const SignUpScreen()),
                                  child: Text(
                                    'Create an account',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Log In Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryText,
                                    backgroundColor: AppColors.lightBackground,
                                    side: BorderSide(color: AppColors.cardBorder, width: 2.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28.0),
                                    ),
                                  ),
                                  onPressed: _isDownloading
                                      ? null
                                      : () => _handleNavigate(const LoginScreen()),
                                  child: Text(
                                    'Sign in',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
