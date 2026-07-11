import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../services/settings_service.dart';

class InteractiveTutorialOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const InteractiveTutorialOverlay({super.key, required this.onComplete});

  @override
  State<InteractiveTutorialOverlay> createState() => _InteractiveTutorialOverlayState();
}

class _InteractiveTutorialOverlayState extends State<InteractiveTutorialOverlay> {
  int _currentStep = 0;

  final List<Map<String, String>> _steps = [
    {
      'title': 'Welcome to EasyLens!',
      'description': 'Let\'s take a quick 1-minute tour to help you navigate Buddy and your sensor dashboard.',
      'actionText': 'Start Tour',
    },
    {
      'title': 'Meet Buddy, Your AI Guide',
      'description': 'Tap the floating Buddy Mascot button (or the center button on the navbar) to open the Buddy Assistant sheet. Ask Buddy anything or let him guide your navigation!',
      'actionText': 'Next',
    },
    {
      'title': 'Sensors & Obstacle alerts',
      'description': 'Use the "Hardware" tab to access real-time object detection, text recognition, and hazard mapping sensors.',
      'actionText': 'Next',
    },
    {
      'title': 'Audio Navigation & SOS',
      'description': 'Access the "Navigation" tab for hands-free audio route guidance, or trigger "SOS Emergency" from the dashboard for immediate help.',
      'actionText': 'Next',
    },
    {
      'title': 'Voice Control Enabled!',
      'description': 'You can activate "Speech Navigation" in settings to navigate screens and click elements entirely hands-free using simple voice commands.',
      'actionText': 'Finish',
    },
  ];

  Future<void> _finishTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_tutorial', true);
    widget.onComplete();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _finishTutorial();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();
    final isDefault = settings.selectedContrastTheme == 'Default';
    final step = _steps[_currentStep];

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.85),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Skip option
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _finishTutorial,
                  child: Text(
                    'Skip Tour',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              // Tutorial Card Content
              Card(
                color: isDefault ? Colors.white : AppColors.primaryBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: isDefault ? BorderSide.none : BorderSide(color: AppColors.cardBorder, width: 2),
                ),
                elevation: 12,
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mascot Illustration representation
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEFF6FF),
                          border: Border.all(color: const Color(0xFF3B82F6), width: 2),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/Mascots/App Mascot.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.pets_rounded,
                              color: Color(0xFF2563EB),
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        step['title']!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDefault ? const Color(0xFF002663) : AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description
                      Text(
                        step['description']!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDefault ? const Color(0xFF64748B) : AppColors.primaryText.withOpacity(0.8),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Step indicator dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_steps.length, (index) {
                          final isActive = index == _currentStep;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: isActive ? 24 : 8,
                            decoration: BoxDecoration(
                              color: isActive 
                                  ? const Color(0xFF2563EB)
                                  : (isDefault ? Colors.grey.shade300 : AppColors.cardBorder),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),

              // Navigation Action Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    step['actionText']!,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
