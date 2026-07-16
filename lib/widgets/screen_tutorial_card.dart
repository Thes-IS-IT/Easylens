import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../services/settings_service.dart';

class ScreenTutorialCard extends StatefulWidget {
  final String tutorialKey;
  final String title;
  final String description;
  final String mascotAsset;
  final VoidCallback? onDismissed;

  const ScreenTutorialCard({
    super.key,
    required this.tutorialKey,
    required this.title,
    required this.description,
    required this.mascotAsset,
    this.onDismissed,
  });

  @override
  State<ScreenTutorialCard> createState() => _ScreenTutorialCardState();
}

class _ScreenTutorialCardState extends State<ScreenTutorialCard> {
  bool _isVisible = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _checkTutorialStatus();
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('seen_tutorial_${widget.tutorialKey}') ?? false;
    if (mounted) {
      setState(() {
        _isVisible = !hasSeen;
        _isLoaded = true;
      });
    }
  }

  Future<void> _dismissTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_tutorial_${widget.tutorialKey}', true);
    if (mounted) {
      setState(() {
        _isVisible = false;
      });
    }
    if (widget.onDismissed != null) {
      widget.onDismissed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || !_isVisible) {
      return const SizedBox.shrink();
    }

    final settings = SettingsService();
    final isDefault = settings.selectedContrastTheme == 'Default';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDefault ? Colors.white : AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.cardBorder.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mascot GIF on the left
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: isDefault ? const Color(0xFFF0F7FF) : Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      widget.mascotAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.help_outline_rounded,
                        color: Colors.blueAccent,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 24.0), // make space for close button
                        child: Text(
                          widget.title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.description,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Dismiss Button
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: _dismissTutorial,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryButton,
                            foregroundColor: AppColors.primaryButtonText,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Text(
                            "Got it!",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Top-right close button
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: AppColors.textMuted.withOpacity(0.6),
                size: 20,
              ),
              onPressed: _dismissTutorial,
            ),
          ),
        ],
      ),
    );
  }
}
