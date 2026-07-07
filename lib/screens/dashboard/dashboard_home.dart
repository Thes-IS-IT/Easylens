import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../object_detection/object_detection_screen.dart';
import '../image_labeling/image_labeling_screen.dart';
import 'components/header_bar.dart';
import 'components/mascot_banner.dart';
import 'components/dashboard_button.dart';
import '../../utils/app_route.dart';

class DashboardHome extends StatelessWidget {
  final String displayName;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onSOSSelected;
  final VoidCallback onSettingsSelected;
  final VoidCallback onNotificationsSelected;
  final VoidCallback onContactsSelected;
  final VoidCallback onBuddyAssistantTap;

  const DashboardHome({
    super.key,
    required this.displayName,
    required this.onTabSelected,
    required this.onSOSSelected,
    required this.onSettingsSelected,
    required this.onNotificationsSelected,
    required this.onContactsSelected,
    required this.onBuddyAssistantTap,
  });

  String _getFormattedDate() {
    final now = DateTime.now();
    final weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    final standardMonths = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    
    final weekday = weekdays[now.weekday - 1];
    final month = standardMonths[now.month - 1];
    return '$weekday, $month ${now.day}';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning,';
    } else if (hour < 17) {
      return 'Good afternoon,';
    } else {
      return 'Good evening,';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                _getFormattedDate(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  text: _getGreeting(),
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    color: Colors.black,
                  ),
                  children: [
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: displayName,
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
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
        // Action buttons - wrapped in white container to cover mascot feet overflow
        Container(
          color: AppColors.lightBackground, // Matches page background to cover mascot feet
          padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 0.0),
          child: Column(
            children: [
              DashboardButton(
                title: 'Talk to Buddy (Local LLM)',
                icon: Icons.chat_bubble_outline,
                color: const Color(0xFF6B21A8),
                onTap: onBuddyAssistantTap,
              ),
              DashboardButton(
                title: 'EasyLens',
                icon: Icons.visibility,
                color: const Color(0xFF002663),
                onTap: () {
                  Navigator.of(context).push(
                    AppRoute.to(const ObjectDetectionScreen()),
                  );
                },
              ),
              DashboardButton(
                title: 'Nearby Text',
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
              DashboardButton(
                title: 'Nearby Objects',
                icon: Icons.zoom_in,
                color: const Color(0xFF238290),
                onTap: () {
                  Navigator.of(context).push(
                    AppRoute.to(const ObjectDetectionScreen()),
                  );
                },
              ),
              DashboardButton(
                title: 'Audio Navigation',
                icon: Icons.near_me,
                color: const Color(0xFF85581A),
                onTap: () => onTabSelected(1),
              ),
              DashboardButton(
                title: 'SOS Emergency',
                icon: Icons.phone_in_talk,
                color: const Color(0xFFC53030),
                onTap: onSOSSelected,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
