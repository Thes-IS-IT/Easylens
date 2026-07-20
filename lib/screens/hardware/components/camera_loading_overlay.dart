import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/settings_service.dart';

/// Premium dark HUD loading & initialization overlay shown while EasyLens camera/vision sensors warm up.
class CameraLoadingOverlay extends StatefulWidget {
  final String? customMessage;

  const CameraLoadingOverlay({super.key, this.customMessage});

  @override
  State<CameraLoadingOverlay> createState() => _CameraLoadingOverlayState();
}

class _CameraLoadingOverlayState extends State<CameraLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _currentMessageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _messageTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % 4;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = SettingsService().selectedLanguage.toLowerCase();
    final isTagalog = lang.contains('tagalog') || lang.contains('filipino');

    final messagesEn = [
      'Checking camera hardware...',
      'Warming up vision sensors...',
      'Configuring AI object detector...',
      'Preparing live feed...',
    ];

    final messagesFil = [
      'Sinisuri ang camera hardware...',
      'Inihahanda ang mga vision sensor...',
      'Kino-configure ang AI object detector...',
      'Inihahanda ang live feed...',
    ];

    final activeMessages = isTagalog ? messagesFil : messagesEn;
    final activeSubMessage = widget.customMessage ?? activeMessages[_currentMessageIndex];

    return Container(
      color: const Color(0xFF0F172A), // Sleek HUD deep dark slate background
      child: Stack(
        children: [
          // Background subtle grid pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.04,
              child: CustomPaint(
                painter: _GridBackgroundPainter(),
              ),
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Outer Pulsing & Rotating Lens Rings
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 1.0 + (0.07 * math.sin(_pulseController.value * 2 * math.pi));
                      final rotation = _pulseController.value * 2 * math.pi;

                      return Transform.scale(
                        scale: scale,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer glowing background glow
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF002663).withOpacity(0.3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyanAccent.withOpacity(0.25),
                                    blurRadius: 32,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            // Clockwise outer dash ring
                            Transform.rotate(
                              angle: rotation,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.cyanAccent.withOpacity(0.6),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            // Counter-clockwise inner ring
                            Transform.rotate(
                              angle: -rotation * 1.4,
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.blueAccent.withOpacity(0.8),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            // Central Lens Icon Card
                            Container(
                              width: 70,
                              height: 70,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFF002663), Color(0xFF0055D4)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_enhance_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 36),

                  // Main Title Text
                  Text(
                    isTagalog ? 'Inihahanda ang EasyLens Camera' : 'Initializing EasyLens Camera',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Animated Sub-Message
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      activeSubMessage,
                      key: ValueKey<String>(activeSubMessage),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.cyanAccent.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Shimmer Progress Indicator Bar
                  SizedBox(
                    width: 220,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 44),

                  // Helper Guidance Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Colors.amberAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isTagalog
                                ? 'Tip: Itapat nang maayos ang camera sa lakaran para sa mas tumpak na pagtukoy ng mga balakid.'
                                : 'Tip: Point camera forward towards your walking path for optimal hazard detection.',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top Pill Header
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.cyanAccent.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amberAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isTagalog ? 'INIIHANDA ANG VISION AI' : 'EASYLENS VISION AI • INITIALIZING',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
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
}

class _GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
