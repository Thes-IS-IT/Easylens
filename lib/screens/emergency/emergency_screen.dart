import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _isCountdownActive = true;
  bool _alertSent = false;
  int _countdownTimer = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    HapticFeedback.vibrate();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownTimer > 1) {
        setState(() {
          _countdownTimer--;
        });
        HapticFeedback.vibrate();
      } else {
        _timer?.cancel();
        setState(() {
          _isCountdownActive = false;
          _alertSent = true;
        });
        HapticFeedback.vibrate();
      }
    });
  }

  void _cancelSOS() {
    _timer?.cancel();
    // Return back to dashboard
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isCountdownActive ? 'SENDING SOS IN...' : 'SOS SENT!';
    
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Floating Pill Back Button
              GestureDetector(
                onTap: _cancelSOS,
                child: Container(
                  width: 95,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chevron_left, color: Color(0xFF002663), size: 24),
                      const SizedBox(width: 4),
                      Text(
                        'Back',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF002663),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const Spacer(),
              
              // 2. SOS Title Indicator
              Center(
                child: Text(
                  titleText,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFC53030), // Dark red / orange S01
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              
              const SizedBox(height: 48),
              
              // 3. Main SOS Center Circle
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8E8), // Light pink S01
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFC53030), // Dark red S01
                      width: 5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC53030).withOpacity(0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Center(
                    child: _isCountdownActive
                        ? Text(
                            '$_countdownTimer',
                            style: GoogleFonts.inter(
                              fontSize: 104,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFC53030),
                            ),
                          )
                        : Text(
                            'sos',
                            style: GoogleFonts.inter(
                              fontSize: 78,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFC53030),
                            ),
                          ),
                  ),
                ),
              ),
              
              const Spacer(flex: 2),
              
              // 4. Cancel SOS Bottom Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDE8E8), // Light pink S01
                    foregroundColor: const Color(0xFFC53030), // Dark red S01
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.0),
                    ),
                  ),
                  onPressed: _cancelSOS,
                  child: Text(
                    'Cancel SOS',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
