import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../services/settings_service.dart';

class LocalAiInstructionsDialog extends StatelessWidget {
  const LocalAiInstructionsDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => const LocalAiInstructionsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final settings = SettingsService();
        final lang = settings.selectedLanguage;
        final isTagalog = lang.toLowerCase().contains('tagalog') ||
            lang.toLowerCase().contains('filipino');
        final isDefault = settings.selectedContrastTheme == 'Default';

        final bgColor = isDefault ? Colors.white : AppColors.primaryBackground;
        final textColor = AppColors.primaryText;
        final cardBg = isDefault ? const Color(0xFFF8FAFC) : AppColors.lightBackground;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDefault
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                    : AppColors.cardBorder,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Mascot Avatar & Title
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        border: Border.all(
                          color: const Color(0xFF8B5CF6),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/Mascots/01 Happy.gif',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'LOCAL AI',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.offline_bolt_rounded,
                                  size: 16, color: Color(0xFF8B5CF6)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isTagalog
                                ? 'Mga Pwedeng Itanong Kay Buddy'
                                : 'What You Can Ask Buddy',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: AppColors.unselectedBorder),
                const SizedBox(height: 16),

                // Subtitle description
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isTagalog
                        ? 'Gamitin ang boses (STT) para magtanong! Basahin o pakinggan (TTS) ang mga sagot ng Local AI:'
                        : 'Use your voice (STT) to ask! Hear responses read aloud (TTS) by Local AI:',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Example Prompts List
                _buildPromptItem(
                  icon: Icons.visibility_rounded,
                  iconColor: const Color(0xFF2563EB),
                  title: isTagalog
                      ? '"Ano ang nasa harap ko?"'
                      : '"What\'s in front of me?"',
                  subtitle: isTagalog
                      ? 'Inilalarawan lamang ang mga nakikitang bagay sa harap.'
                      : 'Describes only the objects currently visible in camera view.',
                  cardBg: cardBg,
                  textColor: textColor,
                ),
                const SizedBox(height: 10),
                _buildPromptItem(
                  icon: Icons.filter_hdr_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: isTagalog
                      ? '"Ilarawan ang paligid"'
                      : '"Describe my surroundings"',
                  subtitle: isTagalog
                      ? 'Nagbibigay ng mabilis na buod ng kasalukuyang tanawin.'
                      : 'Provides a quick summary of the active scene context.',
                  cardBg: cardBg,
                  textColor: textColor,
                ),
                const SizedBox(height: 10),
                _buildPromptItem(
                  icon: Icons.directions_walk_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: isTagalog
                      ? '"Ligtas ba ang daan ko?"'
                      : '"Is my path clear?"',
                  subtitle: isTagalog
                      ? 'Sinusuri kung may mga harang sa iyong dadaanan.'
                      : 'Checks for nearby obstacles or hazard warnings in path.',
                  cardBg: cardBg,
                  textColor: textColor,
                ),
                const SizedBox(height: 10),
                _buildPromptItem(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: isTagalog
                      ? '"Lumipat sa Gemini mode"'
                      : '"Switch to Gemini mode"',
                  subtitle: isTagalog
                      ? 'Para sa mga malalalim at kumplikadong katanungan.'
                      : 'Suggested automatically for complex queries & deep answers.',
                  cardBg: cardBg,
                  textColor: textColor,
                ),

                const SizedBox(height: 20),

                // Got It Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      isTagalog ? 'Naintindihan Ko!' : 'Got It!',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPromptItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color cardBg,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
