import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../hardware/hardware_screen.dart';
import '../image_labeling/image_labeling_screen.dart';
import 'components/header_bar.dart';
import 'components/mascot_banner.dart';
import 'components/dashboard_button.dart';
import '../../utils/app_route.dart';
import '../../services/settings_service.dart';
import '../../services/translation_service.dart';
import '../../services/weather_service.dart';
import '../../widgets/screen_tutorial_card.dart';

class DashboardHome extends StatefulWidget {
  final String displayName;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onSOSSelected;
  final VoidCallback onSettingsSelected;
  final VoidCallback onNotificationsSelected;
  final VoidCallback onContactsSelected;
  final VoidCallback onBuddyAssistantTap;
  final VoidCallback onFaceRegistrationSelected;

  final bool showStickyHeader;

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
    this.showStickyHeader = true,
  });

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  @override
  void initState() {
    super.initState();
    _loadWeather();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScreenTutorialCard.showIfNeeded(
        context,
        tutorialKey: 'home',
        titleKey: 'tutorial_home_title',
        descriptionKey: 'tutorial_home_desc',
        mascotAsset: 'assets/Mascots/05 Welcome.gif',
      );
    });
  }

  Future<void> _loadWeather() async {
    await WeatherService().fetchWeather();
    if (mounted) {
      setState(() {});
    }
  }

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

  Widget _buildWeatherWidget(String lang) {
    final weather = WeatherService();
    if (weather.currentTemp == null) {
      return const SizedBox.shrink();
    }

    final tempStr = "${weather.currentTemp!.toStringAsFixed(1)}°C";
    final desc = weather.weatherDescription ?? 'Clear';

    IconData weatherIcon = Icons.wb_sunny;
    Color iconColor = Colors.orangeAccent;
    if (desc.toLowerCase().contains('cloud')) {
      weatherIcon = Icons.cloud;
      iconColor = Colors.blueGrey;
    } else if (desc.toLowerCase().contains('rain') || desc.toLowerCase().contains('drizzle')) {
      weatherIcon = Icons.umbrella;
      iconColor = Colors.blue;
    } else if (desc.toLowerCase().contains('fog') || desc.toLowerCase().contains('mist')) {
      weatherIcon = Icons.blur_on;
      iconColor = Colors.grey;
    } else if (desc.toLowerCase().contains('snow')) {
      weatherIcon = Icons.ac_unit;
      iconColor = Colors.lightBlueAccent;
    } else if (desc.toLowerCase().contains('thunderstorm')) {
      weatherIcon = Icons.flash_on;
      iconColor = Colors.amber;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryText.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.unselectedBorder.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(weatherIcon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              "$tempStr • $desc",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStormyWarningCard(String lang) {
    final weather = WeatherService();
    if (!weather.isStormy || weather.hasDismissedStormWarning) {
      return const SizedBox.shrink();
    }

    final isFilipino = lang.toLowerCase().contains('filipino') || lang.toLowerCase().contains('tagalog');
    final warningTitle = isFilipino ? "Babala sa Panahon" : "Weather Warning";
    final warningText = isFilipino 
        ? "Mukhang mapanganib sa labas dahil sa masamang panahon."
        : "It seems outside is dangerous due to stormy conditions.";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2), // Light red background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFCA5A5), // Red border
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFDC2626), // Danger red
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warningTitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  warningText,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF7F1D1D),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF991B1B), size: 20),
            onPressed: () async {
              await weather.dismissWarningForToday();
              setState(() {});
            },
          ),
        ],
      ),
    );
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
            onTap: widget.onBuddyAssistantTap,
          ),
          'easylens': DashboardButton(
            title: TranslationService.translate('easylens', lang),
            icon: Icons.visibility,
            color: const Color(0xFF002663),
            onTap: () => widget.onTabSelected(2),
          ),
          'faces': DashboardButton(
            title: TranslationService.translate('register_face', lang),
            icon: Icons.face_retouching_natural,
            color: const Color(0xFF7C3AED),
            onTap: widget.onFaceRegistrationSelected,
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
                    widget.onTabSelected(index);
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
                AppRoute.to(const HardwareScreen(initialStep: 4)),
              );
            },
          ),
          'navigation': DashboardButton(
            title: TranslationService.translate('audio_navigation', lang),
            icon: Icons.near_me,
            color: const Color(0xFF85581A),
            onTap: () => widget.onTabSelected(1),
          ),
          'sos': DashboardButton(
            title: TranslationService.translate('sos_emergency', lang),
            icon: Icons.phone_in_talk,
            color: const Color(0xFFC53030),
            onTap: widget.onSOSSelected,
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
            if (widget.showStickyHeader)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: HeaderBar(
                  onSOSSelected: widget.onSOSSelected,
                  onSettingsSelected: widget.onSettingsSelected,
                  onNotificationsSelected: widget.onNotificationsSelected,
                  onContactsSelected: widget.onContactsSelected,
                ),
              ),

            const SizedBox(height: 32),

            // Date and Greeting - padded S01
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStormyWarningCard(lang),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                    text: settings.userDisplayName.isNotEmpty ? settings.userDisplayName : widget.displayName,
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
                            _buildWeatherWidget(lang),
                          ],
                        ),
                      ),
                    ],
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
