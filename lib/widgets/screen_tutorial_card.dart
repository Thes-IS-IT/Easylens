import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/colors.dart';
import '../services/settings_service.dart';
import '../services/translation_service.dart';

class ScreenTutorialCard extends StatelessWidget {
  const ScreenTutorialCard({
    super.key,
    required String tutorialKey,
    required String titleKey,
    required String descriptionKey,
    required String mascotAsset,
  });

  /// Returns a UID-scoped pref key, e.g. "seen_tutorial_abc123_home".
  /// Falls back to device-only key when no user is signed in.
  static String _prefKey(String tutorialKey) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      return 'seen_tutorial_${uid}_$tutorialKey';
    }
    return 'seen_tutorial_$tutorialKey';
  }

  /// All known tutorial keys — used when marking all as seen for existing users.
  static const List<String> _allTutorialKeys = [
    'home',
    'navigation',
    'easylens',
    'contacts',
    'emergency',
    'face_registration',
    'devices',
    'settings',
    'notifications',
    'image_labeling',
    'rag_assistant',
  ];

  /// Call this right after a NEW account is created so tutorials show for that user.
  /// For existing/returning users, call markAllSeen() to skip them.
  static Future<void> resetForNewUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in _allTutorialKeys) {
      await prefs.remove('seen_tutorial_${uid}_$key');
    }
  }

  /// Call this for returning users (not first-time) so they never see tutorials.
  static Future<void> markAllSeen() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in _allTutorialKeys) {
      await prefs.setBool('seen_tutorial_${uid}_$key', true);
    }
  }

  static Future<void> showIfNeeded(
    BuildContext context, {
    required String tutorialKey,
    required String titleKey,
    required String descriptionKey,
    required String mascotAsset,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(_prefKey(tutorialKey)) ?? false;
    if (hasSeen) return;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return _TutorialDialog(
          tutorialKey: tutorialKey,
          titleKey: titleKey,
          descriptionKey: descriptionKey,
          mascotAsset: mascotAsset,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _TutorialDialog extends StatefulWidget {
  final String tutorialKey;
  final String titleKey;
  final String descriptionKey;
  final String mascotAsset;

  const _TutorialDialog({
    required this.tutorialKey,
    required this.titleKey,
    required this.descriptionKey,
    required this.mascotAsset,
  });

  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog> {
  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(ScreenTutorialCard._prefKey(widget.tutorialKey), true);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final settings = SettingsService();
        final lang = settings.selectedLanguage;
        final isDefault = settings.selectedContrastTheme == 'Default';

        final titleText = TranslationService.translate(widget.titleKey, lang);
        final descText = TranslationService.translate(widget.descriptionKey, lang);
        final gotItText = TranslationService.translate('tutorial_got_it', lang);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: isDefault ? Colors.white : AppColors.primaryBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.cardBorder.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mascot container with padding to fit the GIF correctly S01
                      Container(
                        width: 96,
                        height: 96,
                        padding: const EdgeInsets.all(8), // Add padding so it doesn't crop the mascot
                        decoration: BoxDecoration(
                          color: isDefault ? const Color(0xFFF0F7FF) : Colors.black.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            widget.mascotAsset,
                            fit: BoxFit.contain, // Fit contain to avoid cropping
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.help_outline_rounded,
                              color: Colors.blueAccent,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        titleText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        descText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Dismiss Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _dismiss,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryButton,
                            foregroundColor: AppColors.primaryButtonText,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            gotItText,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Top-right close button
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted.withOpacity(0.6),
                      size: 24,
                    ),
                    onPressed: _dismiss,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
