import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../dashboard/dashboard_screen.dart';

/// Full-screen celebration shown after successful registration.
/// Fires confetti automatically and navigates to [DashboardScreen].
class CelebrationScreen extends StatefulWidget {
  final String userName;

  const CelebrationScreen({super.key, required this.userName});

  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiCenter;
  late ConfettiController _confettiLeft;
  late ConfettiController _confettiRight;
  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _confettiCenter = ConfettiController(duration: const Duration(seconds: 4));
    _confettiLeft = ConfettiController(duration: const Duration(seconds: 5));
    _confettiRight = ConfettiController(duration: const Duration(seconds: 5));

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    // Fire everything on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiCenter.play();
      _confettiLeft.play();
      _confettiRight.play();
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _confettiCenter.dispose();
    _confettiLeft.dispose();
    _confettiRight.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _goToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const DashboardScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // ── LEFT confetti cannon ──
          Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              confettiController: _confettiLeft,
              blastDirection: -pi / 4, // down-right
              emissionFrequency: 0.05,
              numberOfParticles: 18,
              maxBlastForce: 30,
              minBlastForce: 15,
              gravity: 0.3,
              colors: _confettiColors,
            ),
          ),

          // ── RIGHT confetti cannon ──
          Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              confettiController: _confettiRight,
              blastDirection: -3 * pi / 4, // down-left
              emissionFrequency: 0.05,
              numberOfParticles: 18,
              maxBlastForce: 30,
              minBlastForce: 15,
              gravity: 0.3,
              colors: _confettiColors,
            ),
          ),

          // ── CENTER burst ──
          Align(
            alignment: const Alignment(0, -0.25),
            child: ConfettiWidget(
              confettiController: _confettiCenter,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.03,
              numberOfParticles: 25,
              maxBlastForce: 50,
              minBlastForce: 20,
              gravity: 0.25,
              colors: _confettiColors,
            ),
          ),

          // ── Main content ──
          FadeTransition(
            opacity: _fadeIn,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mascot / celebration image
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: Image.asset(
                        'assets/Mascots/04 Congratulations.gif',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.celebration_outlined,
                          size: 80,
                          color: AppColors.primaryButton,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      '🎉 Welcome,',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.userName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                        height: 1.1,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppColors.cardBorder, width: 1),
                      ),
                      child: Text(
                        'Your profile has been saved.\nLet\'s explore EasyLens together!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppColors.textMuted,
                          height: 1.6,
                        ),
                      ),
                    ),

                    const SizedBox(height: 44),

                    // Get Started button
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: AppColors.primaryButtonText,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _goToDashboard,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Get Started',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 22),
                          ],
                        ),
                      ),
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

  static const List<Color> _confettiColors = [
    Color(0xFF1B3D72), // navy
    Color(0xFF2E6FE0), // blue
    Color(0xFF38BDF8), // sky
    Color(0xFFFBBF24), // amber
    Color(0xFF34D399), // emerald
    Color(0xFFF472B6), // pink
    Color(0xFFFFFFFF), // white
  ];
}
