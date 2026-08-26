import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login/login_screen.dart';
import '../../constants/colors.dart';
import '../onboarding/onboarding_screen.dart';
import '../../services/firebase_service.dart';
import '../../services/sound_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../../utils/app_route.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    
    // Play Buddy dog bark sound on fresh startup
    SoundService.playBark();
    
    Future.microtask(() {
      if (mounted) {
        precacheImage(const AssetImage('assets/mascots/01_happy.gif'), context);
        precacheImage(const AssetImage('assets/mascots/02_error.gif'), context);
        precacheImage(const AssetImage('assets/mascots/03_loading.gif'), context);
        precacheImage(const AssetImage('assets/mascots/04_congratulations.gif'), context);
        precacheImage(const AssetImage('assets/mascots/05_welcome.gif'), context);
        precacheImage(const AssetImage('assets/mascots/06_thinking.gif'), context);
        precacheImage(const AssetImage('assets/mascots/07_crying.gif'), context);
        precacheImage(const AssetImage('assets/mascots/08_fetch.gif'), context);
      }
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();

    _timer = Timer(const Duration(milliseconds: 2200), () async {
      if (!mounted) return;
      // Smooth fade out before switching screen
      try {
        await _animationController.reverse().orCancel;
      } catch (_) {}

      if (mounted) {
        final firebaseService = FirebaseService();
        final user = firebaseService.currentUser;
        final targetScreen = user != null 
            ? const DashboardScreen() 
            : const OnboardingScreen();

        Navigator.of(context).pushReplacement(
          AppRoute.fade(targetScreen, duration: const Duration(milliseconds: 500)),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [
                Color(0xFF0A3078), // Deep navy blue accent
                Color(0xFF001A4A), // Solid dark blue base
              ],
              center: Alignment.center,
              radius: 1.0,
            ),
          ),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mascot GIF
                  Image.asset(
                    'assets/mascots/05_welcome.gif',
                    width: 240,
                    height: 240,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.pets,
                        size: 120,
                        color: AppColors.welcomeAccentGold,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Golden Title
                  Text(
                    'BUDDY',
                    style: GoogleFonts.inter(
                      textStyle: TextStyle(fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: AppColors.welcomeAccentGold,
                        letterSpacing: 3.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
