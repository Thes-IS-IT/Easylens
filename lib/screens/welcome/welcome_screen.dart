import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../onboarding/onboarding_screen.dart';
import '../../services/firebase_service.dart';
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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    
    Future.microtask(() {
      if (mounted) {
        precacheImage(const AssetImage('assets/Mascots/01 Happy.gif'), context);
        precacheImage(const AssetImage('assets/Mascots/02 Error.gif'), context);
        precacheImage(const AssetImage('assets/Mascots/03 Loading.gif'), context);
        precacheImage(const AssetImage('assets/Mascots/05 Welcome.gif'), context);
        precacheImage(const AssetImage('assets/Mascots/06 Thinking.gif'), context);
      }
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();

    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        final firebaseService = FirebaseService();
        final user = firebaseService.currentUser;
        if (user != null) {
          Navigator.of(context).pushReplacement(
            AppRoute.to(const DashboardScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            AppRoute.to(const OnboardingScreen()),
          );
        }
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
      body: Container(
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
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mascot GIF
                Image.asset(
                  'assets/Mascots/05 Welcome.gif',
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
    );
  }
}
