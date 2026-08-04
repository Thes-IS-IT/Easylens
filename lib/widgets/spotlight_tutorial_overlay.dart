import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../services/tts_service.dart';

/// Data model representing a single spotlight tutorial step.
class SpotlightStep {
  final GlobalKey? targetKey;
  final String title;
  final String description;
  final String mascotAsset;
  final String actionText;
  final EdgeInsets? targetPadding;
  final int? targetTabIndex;
  final VoidCallback? onStepAction;

  const SpotlightStep({
    this.targetKey,
    required this.title,
    required this.description,
    required this.mascotAsset,
    required this.actionText,
    this.targetPadding,
    this.targetTabIndex,
    this.onStepAction,
  });
}

/// Full-screen interactive spotlight overlay that highlights target UI buttons
/// with an illuminated cutout, glowing pulse ring, and responsive tutorial card.
class SpotlightTutorialOverlay extends StatefulWidget {
  final List<SpotlightStep> steps;
  final VoidCallback onComplete;
  final ValueChanged<int>? onTabRequested;

  const SpotlightTutorialOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    this.onTabRequested,
  });

  @override
  State<SpotlightTutorialOverlay> createState() => _SpotlightTutorialOverlayState();
}

class _SpotlightTutorialOverlayState extends State<SpotlightTutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStepIndex = 0;
  bool _spotlightVisible = false; // Hidden during scroll transitions
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakCurrentStep();
    });
  }

  @override
  void dispose() {
    TtsService().stop();
    _pulseController.dispose();
    super.dispose();
  }

  Rect? _getTargetRect(GlobalKey? key, EdgeInsets? padding) {
    if (key == null || key.currentContext == null) return null;
    final renderBox = key.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return null;

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    final p = padding ?? const EdgeInsets.all(8.0);

    return Rect.fromLTRB(
      position.dx - p.left,
      position.dy - p.top,
      position.dx + size.width + p.right,
      position.dy + size.height + p.bottom,
    );
  }

  void _speakCurrentStep() {
    final currentStep = widget.steps[_currentStepIndex];
    if (currentStep.onStepAction != null) {
      currentStep.onStepAction!();
    }
    if (currentStep.targetTabIndex != null) {
      widget.onTabRequested?.call(currentStep.targetTabIndex!);
    }

    if (SettingsService().voiceFeedback) {
      TtsService().speak('${currentStep.title}. ${currentStep.description}');
    }

    // Snap spotlight immediately visible — only hide briefly if scroll is truly needed
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (currentStep.targetKey != null && currentStep.targetKey!.currentContext != null) {
        try {
          // Check if target is already fully visible before bothering to scroll
          final renderBox = currentStep.targetKey!.currentContext!.findRenderObject() as RenderBox?;
          if (renderBox != null && renderBox.attached) {
            final pos = renderBox.localToGlobal(Offset.zero);
            final screenH = MediaQuery.of(context).size.height;
            final needsScroll = pos.dy < 80 || pos.dy + renderBox.size.height > screenH - 120;

            if (needsScroll) {
              // Hide temporarily only when scroll is actually needed
              if (mounted) setState(() => _spotlightVisible = false);

              await Scrollable.ensureVisible(
                currentStep.targetKey!.currentContext!,
                duration: Duration.zero, // Instant jump — no animation lag
                alignment: 0.35,
              );
              // Single frame settle — enough for localToGlobal to update
              await Future.delayed(const Duration(milliseconds: 30));
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _spotlightVisible = true;
        });
      }
    });
  }

  void _nextStep() {
    SoundService.playPop();
    if (_currentStepIndex < widget.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      _speakCurrentStep();
    } else {
      TtsService().stop();
      widget.onComplete();
    }
  }

  void _prevStep() {
    SoundService.playTab();
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
      _speakCurrentStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final settings = SettingsService();
    final isDefault = settings.selectedContrastTheme == 'Default';
    final currentStep = widget.steps[_currentStepIndex];

    // Only compute target rect after scroll has settled to avoid stale positions
    final targetRect = _spotlightVisible
        ? _getTargetRect(currentStep.targetKey, currentStep.targetPadding)
        : null;

    // Determine vertical placement of tutorial card to prevent clipping
    bool placeAboveTarget = false;
    if (targetRect != null) {
      placeAboveTarget = targetRect.center.dy > (screenSize.height / 2);
    }


    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── 1. Cutout Mask Overlay with Pulse Ring ──
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: screenSize,
                painter: SpotlightOverlayPainter(
                  targetRect: targetRect,
                  pulseScale: _pulseAnimation.value,
                  accentColor: isDefault ? const Color(0xFF38BDF8) : AppColors.primaryButton,
                ),
              );
            },
          ),

          // ── 2. Tap Anywhere Overlay / Dismiss Barrier ──
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // Advance tutorial on tap outside card
              },
            ),
          ),

          // ── 3. Top Header Bar (Skip Tour) ──
          Positioned(
            top: targetRect != null && targetRect.top < 120 && targetRect.right > screenSize.width - 160 ? 16 : 68,
            left: targetRect != null && targetRect.top < 120 && targetRect.right > screenSize.width - 160 ? 16 : null,
            right: targetRect != null && targetRect.top < 120 && targetRect.right > screenSize.width - 160 ? null : 16,
            child: SafeArea(
              top: targetRect != null && targetRect.top < 120 && targetRect.right > screenSize.width - 160,
              child: Material(
                color: Colors.transparent,
                child: TextButton.icon(
                  onPressed: () {
                    TtsService().stop();
                    SoundService.playClick();
                    widget.onComplete();
                  },
                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'Skip Tour',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xCC0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    elevation: 4,
                    shadowColor: Colors.black38,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.white.withOpacity(0.25), width: 1.2),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── 4. Responsive Floating Tutorial Card ──
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Compute top/bottom positioning for card
                double? topPos;
                double? bottomPos;

                if (targetRect == null) {
                  // Fallback: Center card in viewport
                  topPos = (constraints.maxHeight - 340) / 2;
                } else if (placeAboveTarget) {
                  // Position card above target button with comfortable 28px spacing
                  bottomPos = constraints.maxHeight - targetRect.top + 28;
                  if (bottomPos < 24) bottomPos = 24;
                } else {
                  // Position card below target button with comfortable 28px spacing
                  topPos = targetRect.bottom + 28;
                  if (topPos > constraints.maxHeight - 280) {
                    topPos = constraints.maxHeight - 280;
                  }
                }

                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      left: 20,
                      right: 20,
                      top: topPos,
                      bottom: bottomPos,
                      child: Material(
                        color: Colors.transparent,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.94, end: 1.0).animate(
                                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            key: ValueKey<int>(_currentStepIndex),
                            constraints: BoxConstraints(
                              maxHeight: constraints.maxHeight * 0.55,
                            ),
                            decoration: BoxDecoration(
                              color: isDefault ? Colors.white : AppColors.primaryBackground,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDefault
                                    ? const Color(0xFF38BDF8).withOpacity(0.4)
                                    : AppColors.cardBorder,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Buddy Avatar + Step Counter Header
                                  Row(
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFEFF6FF),
                                          border: Border.all(
                                            color: const Color(0xFF3B82F6),
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: Image.asset(
                                            currentStep.mascotAsset,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => Image.asset(
                                              'assets/Mascots/01 Happy.gif',
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Buddy Guide',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF2563EB),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              currentStep.title,
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isDefault
                                                    ? const Color(0xFF002663)
                                                    : AppColors.primaryText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // TTS Speaker Icon Button
                                      IconButton(
                                        icon: const Icon(
                                          Icons.volume_up_rounded,
                                          color: Color(0xFF2563EB),
                                          size: 22,
                                        ),
                                        tooltip: 'Listen to instruction',
                                        onPressed: () {
                                          TtsService().speak('${currentStep.title}. ${currentStep.description}');
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDefault
                                              ? const Color(0xFFEFF6FF)
                                              : Colors.white.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_currentStepIndex + 1}/${widget.steps.length}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDefault
                                                ? const Color(0xFF2563EB)
                                                : AppColors.primaryText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),

                                  // Description Text
                                  Text(
                                    currentStep.description,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDefault
                                          ? const Color(0xFF475569)
                                          : AppColors.primaryText.withOpacity(0.85),
                                      height: 1.45,
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  // Stepper Navigation Buttons (Back + Next)
                                  Row(
                                    children: [
                                      if (_currentStepIndex > 0) ...[
                                        Expanded(
                                          flex: 2,
                                          child: OutlinedButton(
                                            onPressed: _prevStep,
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                color: AppColors.cardBorder.withOpacity(0.5),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            child: Text(
                                              'Back',
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: AppColors.primaryText,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Expanded(
                                        flex: 3,
                                        child: ElevatedButton(
                                          onPressed: _nextStep,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primaryButton,
                                            foregroundColor: AppColors.primaryButtonText,
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                          child: Text(
                                            currentStep.actionText,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
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
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter that renders a dark semi-transparent overlay with a punch cutout window
/// around the target rect, featuring a glowing pulse aura ring.
class SpotlightOverlayPainter extends CustomPainter {
  final Rect? targetRect;
  final double pulseScale;
  final Color accentColor;

  SpotlightOverlayPainter({
    required this.targetRect,
    required this.pulseScale,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (targetRect == null) {
      // Paint full dark background when no target is highlighted
      final bgPaint = Paint()..color = Colors.black.withOpacity(0.78);
      canvas.drawPath(backgroundPath, bgPaint);
      return;
    }

    final cutoutRRect = RRect.fromRectAndRadius(
      targetRect!,
      const Radius.circular(16),
    );

    final cutoutPath = Path()..addRRect(cutoutRRect);

    // 1. Combine background with cutout hole
    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.78);
    canvas.drawPath(overlayPath, overlayPaint);

    // 2. Draw glowing pulse aura ring around target button
    final pulseRadius = 16.0 * pulseScale;
    final pulseRRect = RRect.fromRectAndRadius(
      targetRect!.inflate((pulseScale - 1.0) * 8.0),
      Radius.circular(pulseRadius),
    );

    final pulsePaint = Paint()
      ..color = accentColor.withOpacity(0.45 * (1.15 - (pulseScale - 1.0)))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRRect(pulseRRect, pulsePaint);

    // 3. Crisp inner border
    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(cutoutRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant SpotlightOverlayPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseScale != pulseScale ||
        oldDelegate.accentColor != accentColor;
  }
}
