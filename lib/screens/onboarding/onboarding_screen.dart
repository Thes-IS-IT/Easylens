import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../signup/signup_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../login/login_screen.dart';
import '../../utils/app_route.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 10),
              
              // Animated Mascot Container (Card)
              Column(
                children: [
                  Container(
                    width: 210,
                    height: 210,
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
                        size: 100,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  // App Name
                  Text(
                    'BUDDY',
                    style: GoogleFonts.inter(
                      textStyle: TextStyle(fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryText,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // App Tagline
                  Text(
                    'VISION ASSISTANT',
                    style: GoogleFonts.inter(
                      textStyle: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom Action Buttons
              Column(
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
                      onPressed: () {
                        Navigator.of(context).push(
                          AppRoute.to(const SignUpScreen()),
                        );
                      },
                      child: Text(
                        'Sign Up',
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
                        backgroundColor: Colors.white,
                        side: BorderSide(color: AppColors.cardBorder, width: 2.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28.0),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          AppRoute.to(const LoginScreen()),
                        );
                      },
                      child: Text(
                        'Log In',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
