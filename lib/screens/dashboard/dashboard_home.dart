import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../object_detection/object_detection_screen.dart';
import '../image_labeling/image_labeling_screen.dart';
import '../face_registration/face_registration_screen.dart';
import 'components/header_bar.dart';
import 'components/mascot_banner.dart';
import 'components/dashboard_button.dart';
import '../../utils/app_route.dart';
import '../../services/settings_service.dart';
import '../../services/translation_service.dart';

class DashboardHome extends StatelessWidget {
  final String displayName;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onSOSSelected;
  final VoidCallback onSettingsSelected;
  final VoidCallback onNotificationsSelected;
  final VoidCallback onContactsSelected;
  final VoidCallback onBuddyAssistantTap;
  final VoidCallback onFaceRegistrationSelected;

  const DashboardHome({
    super.key,
    required this.displayName,
    required this.onTabSelected,
    required this.onSOSSelected,
    required this.onSettingsSelected,
    required this.onNotificationsSelected,
    required this.onContactsSelected,
    required this.onBuddyAssistantTap,
    required this.onFaceRegistrationSelected,
  });

  String _getFormattedDateText(String language) {
    final now = DateTime.now();
    final isFilipino = language.toLowerCase().contains('filipino') || language.toLowerCase().contains('tagalog');
    if (isFilipino) {
      final weekdays = ['LUNES', 'MARTES', 'MIYERKULES', 'HUWEBES', 'BIYERNES', 'SABADO', 'DOMINGO'];
      final months = ['ENERO', 'PEBRERO', 'MARSO', 'ABRIL', 'MAYO', 'HUNYO', 'HULYO', 'AGOSTO', 'SETYEMBRE', 'OKTUBRE', 'NOBYEMBRE', 'DISYEMBRE'];
      return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
    } else {
      final weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
      final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
      return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
    }
  }

  String _getGreetingText(String language) {
    final isFilipino = language.toLowerCase().contains('filipino') || language.toLowerCase().contains('tagalog');
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return isFilipino ? 'Magandang umaga,' : 'Good morning,';
    } else if (hour < 17) {
      return isFilipino ? 'Magandang hapon,' : 'Good afternoon,';
    } else {
      return isFilipino ? 'Magandang gabi,' : 'Good evening,';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final settings = SettingsService();
        final lang = settings.selectedLanguage;
        final enabledCards = settings.homeScreenCards;

        final Map<String, Widget> cardWidgets = {
          'buddy': DashboardButton(
            title: TranslationService.translate('talk_to_buddy', lang),
            icon: Icons.chat_bubble_outline,
            color: const Color(0xFF6B21A8),
            onTap: onBuddyAssistantTap,
          ),
          'easylens': DashboardButton(
            title: TranslationService.translate('easylens', lang),
            icon: Icons.visibility,
            color: const Color(0xFF002663),
            onTap: () => onTabSelected(2),
          ),
          'faces': DashboardButton(
            title: 'Register Face',
            icon: Icons.face_retouching_natural,
            color: const Color(0xFF7C3AED),
            onTap: onFaceRegistrationSelected,
          ),
          'text': DashboardButton(
            title: TranslationService.translate('nearby_text', lang),
            icon: Icons.notes,
            color: const Color(0xFF3F83F8),
            onTap: () {
              Navigator.of(context).push(
                AppRoute.to(ImageLabelingScreen(
                  onTabSelected: (index) {
                    Navigator.of(context).pop();
                    onTabSelected(index);
                  },
                )),
              );
            },
          ),
          'objects': DashboardButton(
            title: TranslationService.translate('nearby_objects', lang),
            icon: Icons.zoom_in,
            color: const Color(0xFF238290),
            onTap: () {
              Navigator.of(context).push(
                AppRoute.to(const ObjectDetectionScreen()),
              );
            },
          ),
          'navigation': DashboardButton(
            title: TranslationService.translate('audio_navigation', lang),
            icon: Icons.near_me,
            color: const Color(0xFF85581A),
            onTap: () => onTabSelected(1),
          ),
          'sos': DashboardButton(
            title: TranslationService.translate('sos_emergency', lang),
            icon: Icons.phone_in_talk,
            color: const Color(0xFFC53030),
            onTap: onSOSSelected,
          ),
        };

        final List<Widget> cardList = [];
        for (var cardKey in enabledCards) {
          if (cardWidgets.containsKey(cardKey)) {
            cardList.add(cardWidgets[cardKey]!);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Row - padded S01
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: HeaderBar(
                onSOSSelected: onSOSSelected,
                onSettingsSelected: onSettingsSelected,
                onNotificationsSelected: onNotificationsSelected,
                onContactsSelected: onContactsSelected,
              ),
            ),

            const SizedBox(height: 32),

            // Date and Greeting - padded S01
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getFormattedDateText(lang),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryText,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      text: _getGreetingText(lang),
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        color: AppColors.primaryText,
                      ),
                      children: [
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: displayName,
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const TextSpan(text: '!'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Mascot Banner - stretches full-bleed (no padding) S01
            const MascotBanner(),
            // Action buttons - wrapped in container to cover mascot feet overflow
            Container(
              color: AppColors.lightBackground,
              padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 0.0),
              child: Column(
                children: cardList,
              ),
            ),
          ],
        );
      },
    );
  }
}
