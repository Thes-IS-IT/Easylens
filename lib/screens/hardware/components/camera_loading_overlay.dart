import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../services/settings_service.dart';

/// Minimal, high-performance loading & initialization overlay shown while EasyLens camera warms up.
/// Features smooth 60fps looping GIF mascot (08_fetch.gif) with isolated render boundaries,
/// smooth fade-in/fade-out transitions, and theme synchronization.
class CameraLoadingOverlay extends StatefulWidget {
  final String? customMessage;
  final VoidCallback? onCompleted;
  final double? targetProgress; // Optional externally driven progress (0.0 to 1.0)

  const CameraLoadingOverlay({
    super.key,
    this.customMessage,
    this.onCompleted,
    this.targetProgress,
  });

  @override
  State<CameraLoadingOverlay> createState() => _CameraLoadingOverlayState();
}

class _CameraLoadingOverlayState extends State<CameraLoadingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isExiting = false;

  @override
  void initState() {
    super.initState();

    // 1. Smooth Fade In / Fade Out controller
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    // 2. Smooth working progress bar animation (progresses 0% to 100%)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    );

    _progressController.forward();

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isExiting) {
        _isExiting = true;
        // Smoothly fade out before concluding
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            _fadeController.reverse().then((_) {
              if (widget.onCompleted != null && mounted) {
                widget.onCompleted!();
              }
            });
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Warm up and decode the GIF immediately into memory to avoid first-frame drop
    precacheImage(const AssetImage('assets/mascots/08_fetch.gif'), context);
  }

  @override
  void didUpdateWidget(covariant CameraLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetProgress != null &&
        widget.targetProgress != oldWidget.targetProgress) {
      _progressController.animateTo(
        widget.targetProgress!.clamp(0.0, 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final isDark = SettingsService().isDarkMode;
        final theme = SettingsService().selectedContrastTheme;
        final isDefault = theme == 'Default';
        final lang = SettingsService().selectedLanguage.toLowerCase();
        final isTagalog = lang.contains('tagalog') || lang.contains('filipino');

        // Dynamic theme-synced colors
        final bg = isDefault
            ? (isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF))
            : AppColors.primaryBackground;
        final textColor = AppColors.primaryText;
        final primaryAccent = AppColors.primaryButton;
        final surfaceBg = AppColors.lightBackground;
        final mutedText = AppColors.textMuted;
        final borderColor = AppColors.cardBorder.withValues(alpha: isDefault ? 0.12 : 0.4);

        final stagesEn = [
          'Checking camera hardware...',
          'Warming up vision sensors...',
          'Configuring AI object detector...',
          'Establishing live camera feed...',
          'Vision AI ready!',
        ];

        final stagesFil = [
          'Sinisuri ang camera hardware...',
          'Inihahanda ang mga vision sensor...',
          'Kino-configure ang AI object detector...',
          'Inihahanda ang live camera feed...',
          'Handa na ang Vision AI!',
        ];

        final activeStages = isTagalog ? stagesFil : stagesEn;
        final activeStepLabels = ['Sensors', 'Hardware', 'AI Vision', 'Stream'];

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Frosted Glass Blurred Backdrop (Isolated raster layer)
              Positioned.fill(
                child: RepaintBoundary(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                    child: Container(
                      color: bg.withValues(alpha: isDark || !isDefault ? 0.92 : 0.88),
                    ),
                  ),
                ),
              ),

              // 2. Foreground Content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Top Status Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: surfaceBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: borderColor,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: primaryAccent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isTagalog ? 'EASYLENS CAMERA' : 'EASYLENS CAMERA',
                                  style: GoogleFonts.inter(
                                    color: textColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Mascot: 08_fetch.gif (Isolated in RepaintBoundary for stutter-free 60fps loop)
                          RepaintBoundary(
                            child: SizedBox(
                              width: 190,
                              height: 190,
                              child: Image.asset(
                                'assets/mascots/08_fetch.gif',
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.medium,
                                cacheWidth: 380,
                                cacheHeight: 410,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.camera_alt_rounded,
                                  size: 72,
                                  color: primaryAccent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Title Text (matching app typography)
                          Text(
                            isTagalog ? 'Inihahanda ang Camera' : 'Initializing EasyLens Camera',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: textColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Dynamic Phase Subtitle (clean muted text)
                          RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _progressAnimation,
                              builder: (context, _) {
                                final currentProgress = _progressAnimation.value;
                                int msgIdx = (currentProgress * 4).floor().clamp(0, 3);
                                if (currentProgress >= 0.98) {
                                  msgIdx = 4;
                                }
                                final stageText = widget.customMessage ?? activeStages[msgIdx];

                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Text(
                                    stageText,
                                    key: ValueKey<String>(stageText),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: mutedText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Minimal Working Progress Bar (Isolated in RepaintBoundary)
                          RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _progressAnimation,
                              builder: (context, _) {
                                final progressVal = _progressAnimation.value;
                                final percent = (progressVal * 100).toInt().clamp(0, 100);

                                return Column(
                                  children: [
                                    // Progress readout row
                                    SizedBox(
                                      width: 260,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            isTagalog ? 'Progreso' : 'Progress',
                                            style: GoogleFonts.inter(
                                              color: mutedText,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                          Text(
                                            '$percent%',
                                            style: GoogleFonts.inter(
                                              color: textColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Progress Bar Pill
                                    Container(
                                      width: 260,
                                      height: 8,
                                      padding: const EdgeInsets.all(1.5),
                                      decoration: BoxDecoration(
                                        color: surfaceBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: borderColor,
                                          width: 1,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: progressVal.clamp(0.02, 1.0),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(5),
                                                color: primaryAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Minimal Step Milestones (Sensors, Hardware, AI Vision, Stream)
                                    SizedBox(
                                      width: 260,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: List.generate(4, (index) {
                                          final stepThreshold = (index + 1) * 0.25;
                                          final isPassed = progressVal >= (stepThreshold - 0.05);

                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 5,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isPassed
                                                      ? primaryAccent
                                                      : mutedText.withValues(alpha: 0.3),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                activeStepLabels[index],
                                                style: GoogleFonts.inter(
                                                  color: isPassed ? textColor : mutedText.withValues(alpha: 0.5),
                                                  fontSize: 10,
                                                  fontWeight: isPassed ? FontWeight.w600 : FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          );
                                        }),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Helper Tip Card (Consistent with app card style)
                          Container(
                            constraints: const BoxConstraints(maxWidth: 320),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: surfaceBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: borderColor,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  color: const Color(0xFFF59E0B),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isTagalog
                                        ? 'Tip: Itapat nang maayos ang camera sa lakaran para sa mas tumpak na pagtukoy ng mga balakid.'
                                        : 'Tip: Point camera forward towards your walking path for optimal hazard detection.',
                                    style: GoogleFonts.inter(
                                      color: mutedText,
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
