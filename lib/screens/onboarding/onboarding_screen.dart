import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../signup/signup_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../login/login_screen.dart';
import '../../utils/app_route.dart';
import '../../services/rag_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isModelInstalled = false;
  bool _isCheckingModel = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = "";
  bool _showLocalAiCard = true;

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
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
                        
                        // Animated Mascot Container (Card)
                        Column(
                          children: [
                            Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0F3E8F), // Premium accent blue
                                    Color(0xFF001F52), // Deep theme navy
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(28.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryText.withOpacity(0.18),
                                    blurRadius: 20.0,
                                    offset: const Offset(0, 10),
                                  )
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(
                                'assets/Mascots/App Logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, err, st) => const Icon(
                                  Icons.pets,
                                  size: 80,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
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
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.offline_bolt_outlined,
                                              color: AppColors.welcomeAccentGold,
                                              size: 28,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'Help without internet',
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primaryText,
                                                ),
                                              ),
                                            ),
                                            // Buffer space to not overlap with the X button
                                            const SizedBox(width: 24),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Download our guide database to use Buddy even when you don\'t have internet or cell service.',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: AppColors.textMuted,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        if (_isDownloading) ...[
                                          LinearProgressIndicator(
                                            value: _downloadProgress,
                                            backgroundColor: AppColors.unselectedBorder,
                                            color: AppColors.primaryButton,
                                            minHeight: 8,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _downloadStatus,
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                              Text(
                                                '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primaryText,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else
                                          SizedBox(
                                            width: double.infinity,
                                            height: 44,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.welcomeAccentGold,
                                                foregroundColor: AppColors.primaryButtonText,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              onPressed: _startDownload,
                                              icon: const Icon(Icons.download_for_offline_outlined, size: 20),
                                              label: Text(
                                                'Set up offline helper',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (!_isDownloading)
                                      Positioned(
                                        top: -6,
                                        right: -6,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                                          onPressed: () {
                                            setState(() {
                                              _showLocalAiCard = false;
                                            });
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          splashRadius: 16,
                                        ),
                                      ),
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
                                    : () {
                                        Navigator.of(context).push(
                                          AppRoute.splitDoor(const SignUpScreen()),
                                        );
                                      },
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
                                    : () {
                                        Navigator.of(context).push(
                                          AppRoute.to(const LoginScreen()),
                                        );
                                      },
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
    );
  }
}
