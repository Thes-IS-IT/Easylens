import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../services/firebase_service.dart';
import '../../services/settings_service.dart';
import '../../services/translation_service.dart';
import '../onboarding/onboarding_screen.dart';
import '../notifications/notifications_screen.dart';
import 'profile_details_screen.dart';
import 'help_guide_screen.dart';
import 'units_screen.dart';
import 'change_password_screen.dart';
import 'preferences_screen.dart';
import 'customize_home_screen.dart';
import '../../utils/app_route.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _firebaseService = FirebaseService();

  // Local interactive states linked to settings service
  String _selectedLanguage = 'English';
  bool _faceIdUnlock = false;
  String _selectedAppearance = 'Black';
  int _selectedAccentColorIndex = 0; // Index 0 represents Green S01
  bool _shakeToUndo = true;
  bool _speechNavigation = false;
  bool _useLocalAI = true;
  bool _showFloatingMascot = true;

  final List<Color> _accentColors = [
    const Color(0xFF10B981), // Green S01
    const Color(0xFFF59E0B), // Yellow/Orange S01
    const Color(0xFFFFFFFF), // White S01
    const Color(0xFF06B6D4), // Cyan S01
  ];

  @override
  void initState() {
    super.initState();
    final settings = SettingsService();
    _selectedLanguage = settings.selectedLanguage.toLowerCase().contains('tagalog') ? 'Filipino' : 'English';
    _faceIdUnlock = settings.faceIdUnlock;
    _selectedAppearance = settings.appearanceTheme;
    _selectedAccentColorIndex = settings.accentColorIndex;
    _shakeToUndo = settings.shakeToUndo;
    _speechNavigation = settings.speechNavigation;
    _useLocalAI = settings.useLocalAI;
    _showFloatingMascot = settings.showFloatingMascot;
  }

  void _saveSettings() {
    String theme = 'Default';
    if (_selectedAppearance == 'White') {
      theme = 'Black on White';
    } else if (_selectedAppearance == 'Black') {
      switch (_selectedAccentColorIndex) {
        case 0:
          theme = 'Green on Black';
          break;
        case 1:
          theme = 'Yellow on Black';
          break;
        case 2:
          theme = 'White on Black';
          break;
        case 3:
          theme = 'Cyan on Black';
          break;
      }
    }

    final languageString = _selectedLanguage == 'Filipino' ? 'Tagalog' : 'English (US)';

    SettingsService().updateSettings(
      selectedLanguage: languageString,
      selectedContrastTheme: theme,
      appearanceTheme: _selectedAppearance,
      accentColorIndex: _selectedAccentColorIndex,
      faceIdUnlock: _faceIdUnlock,
      shakeToUndo: _shakeToUndo,
      speechNavigation: _speechNavigation,
      useLocalAI: _useLocalAI,
      showFloatingMascot: _showFloatingMascot,
    );

    // Sync user preferences to Cloud
    final user = _firebaseService.currentUser;
    if (user != null) {
      _firebaseService.syncPreferencesToCloud(user.uid, {
        'selectedLanguage': languageString,
        'selectedContrastTheme': theme,
        'appearanceTheme': _selectedAppearance,
        'accentColorIndex': _selectedAccentColorIndex,
        'faceIdUnlock': _faceIdUnlock,
        'shakeToUndo': _shakeToUndo,
        'speechNavigation': _speechNavigation,
        'useLocalAI': _useLocalAI,
        'showFloatingMascot': _showFloatingMascot,
      });
    }
  }

  Future<void> _openURL(String urlString) async {
    try {
      final Uri uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Could not launch URL: $urlString");
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  Widget _buildSectionTitle(String title) {
    final settings = SettingsService();
    final isDefault = settings.selectedContrastTheme == 'Default';
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 24.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDefault ? const Color(0xFF64748B) : AppColors.primaryText,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    final settings = SettingsService();
    final isDefault = settings.selectedContrastTheme == 'Default';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(20.0),
        border: isDefault ? null : Border.all(color: AppColors.cardBorder, width: 1.5),
        boxShadow: isDefault ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
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
        final isDefault = settings.selectedContrastTheme == 'Default';
        final headerTextColor = isDefault ? const Color(0xFF002663) : AppColors.primaryText;
        final iconColor = isDefault ? const Color(0xFF002663) : AppColors.primaryText;
        final tileTextColor = isDefault ? Colors.black : AppColors.primaryText;

        final currentUnitText = settings.selectedUnit == 'Metric'
            ? TranslationService.translate('metric', lang)
            : TranslationService.translate('imperial', lang);

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Floating Pill Back Button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDefault ? Colors.white : AppColors.primaryBackground,
                        borderRadius: BorderRadius.circular(22),
                        border: isDefault ? null : Border.all(color: AppColors.cardBorder, width: 1.5),
                        boxShadow: isDefault ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ] : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // Wrap content tightly S01
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chevron_left, color: isDefault ? const Color(0xFF002663) : AppColors.primaryText, size: 24),
                          const SizedBox(width: 4),
                          Text(
                            TranslationService.translate('back', lang),
                            style: GoogleFonts.inter(
                              color: isDefault ? const Color(0xFF002663) : AppColors.primaryText,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 2. Settings Header
                  Text(
                    TranslationService.translate('settings', lang),
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: headerTextColor,
                    ),
                  ),

              // 3. PROFILE Section
              _buildSectionTitle(TranslationService.translate('profile', lang)),
              _buildCardContainer(
                children: [
                  ListTile(
                    leading: Icon(Icons.person_outline, color: iconColor),
                    title: Text(
                      TranslationService.translate('profile_details', lang),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoute.to(const ProfileDetailsScreen()),
                      ).then((_) => setState(() {}));
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(Icons.lock_outline, color: iconColor),
                    title: Text(
                      TranslationService.translate('change_password', lang),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoute.to(const ChangePasswordScreen()),
                      );
                    },
                  ),
                ],
              ),

              // 4. LANGUAGE Section
              _buildSectionTitle(TranslationService.translate('language', lang)),
              _buildCardContainer(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.chat_bubble_outline, color: iconColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                TranslationService.translate('language', lang),
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: tileTextColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                TranslationService.translate('language_subtitle', lang),
                                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedLanguage = 'English');
                                _saveSettings();
                              },
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _selectedLanguage == 'English' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: _selectedLanguage == 'English'
                                      ? Border.all(color: const Color(0xFF3B82F6), width: 1.5)
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'English',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: _selectedLanguage == 'English' ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedLanguage = 'Filipino');
                                _saveSettings();
                              },
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _selectedLanguage == 'Filipino' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: _selectedLanguage == 'Filipino'
                                      ? Border.all(color: const Color(0xFF3B82F6), width: 1.5)
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'Filipino',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: _selectedLanguage == 'Filipino' ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // 5. NOTIFICATIONS Section
              _buildSectionTitle(TranslationService.translate('notifications', lang)),
              _buildCardContainer(
                children: [
                  ListTile(
                    leading: Icon(Icons.notifications_none_outlined, color: iconColor),
                    title: Text(
                      TranslationService.translate('notifications', lang),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor),
                    ),
                    subtitle: Text(
                      TranslationService.translate('notifications_subtitle', lang),
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoute.to(const NotificationsScreen()),
                      );
                    },
                  ),
                ],
              ),

              // 6. PREFERENCES Section
              _buildSectionTitle(TranslationService.translate('preferences', lang)),
              _buildCardContainer(
                children: [
                  ListTile(
                    leading: Icon(Icons.tune_outlined, color: iconColor),
                    title: Text(
                      TranslationService.translate('preferences', lang),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor),
                    ),
                    subtitle: Text(
                      TranslationService.translate('preferences_subtitle', lang),
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoute.to(const PreferencesScreen()),
                      );
                    },
                  ),
                ],
              ),

              // 7. SECURITY Section
              _buildSectionTitle(TranslationService.translate('security', lang)),
              _buildCardContainer(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                TranslationService.translate('face_id', lang),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: tileTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                TranslationService.translate('face_id_subtitle', lang),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Switch(
                          value: _faceIdUnlock,
                          onChanged: (val) {
                            setState(() => _faceIdUnlock = val);
                            _saveSettings();
                          },
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF48BB78),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 8. APPEARANCE Section
              _buildSectionTitle(TranslationService.translate('appearance', lang)),
              _buildCardContainer(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TranslationService.translate('appearance', lang),
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: tileTextColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          TranslationService.translate('appearance_subtitle', lang),
                          style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedAppearance = 'Default');
                                _saveSettings();
                              },
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _selectedAppearance == 'Default' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: _selectedAppearance == 'Default'
                                      ? Border.all(color: const Color(0xFF3B82F6), width: 1.5)
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.phone_android_outlined,
                                        size: 16,
                                        color: _selectedAppearance == 'Default' ? const Color(0xFF3B82F6) : Colors.black),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Default',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _selectedAppearance == 'Default' ? const Color(0xFF3B82F6) : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedAppearance = 'White');
                                _saveSettings();
                              },
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _selectedAppearance == 'White' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: _selectedAppearance == 'White'
                                      ? Border.all(color: const Color(0xFF3B82F6), width: 1.5)
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.wb_sunny_outlined,
                                        size: 16,
                                        color: _selectedAppearance == 'White' ? const Color(0xFF3B82F6) : Colors.black),
                                    const SizedBox(width: 6),
                                    Text(
                                      'White',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _selectedAppearance == 'White' ? const Color(0xFF3B82F6) : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedAppearance = 'Black');
                                _saveSettings();
                              },
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _selectedAppearance == 'Black' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: _selectedAppearance == 'Black'
                                      ? Border.all(color: const Color(0xFF3B82F6), width: 1.5)
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.nightlight_round,
                                        size: 16,
                                        color: _selectedAppearance == 'Black' ? const Color(0xFF3B82F6) : Colors.black),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Black',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _selectedAppearance == 'Black' ? const Color(0xFF3B82F6) : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedAppearance == 'Black') ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(
                        TranslationService.translate('black_accent_colors', lang),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_accentColors.length, (idx) {
                          final isSelected = _selectedAccentColorIndex == idx;
                          final color = _accentColors[idx];
                          final ringColor = idx == 2 ? const Color(0xFF1B4332) : Colors.black;

                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedAccentColorIndex = idx);
                              _saveSettings();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.symmetric(horizontal: 12.0),
                              width: isSelected ? 40 : 36,
                              height: isSelected ? 40 : 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ringColor,
                                  width: 4.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isSelected ? 0.35 : 0.2),
                                    blurRadius: isSelected ? 8 : 4,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ],
              ),

              // 9. UNITS Section
              _buildSectionTitle(TranslationService.translate('units', lang)),
              _buildCardContainer(
                children: [
                  ListTile(
                    leading: Icon(Icons.straighten, color: iconColor),
                    title: Text(
                      TranslationService.translate('units', lang),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor),
                    ),
                    subtitle: Text(
                      currentUnitText,
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoute.to(const UnitsScreen()),
                      ).then((_) => setState(() {}));
                    },
                  ),
                ],
              ),

              // 10. QUICK ACTIONS Section
              _buildSectionTitle(TranslationService.translate('quick_actions', lang)),
              _buildCardContainer(
                children: [
                  ListTile(
                    leading: Icon(Icons.dns_outlined, color: iconColor),
                    title: Text(
                      TranslationService.translate('customize_home', lang),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor),
                    ),
                    subtitle: Text(
                      TranslationService.translate('customize_home_subtitle', lang),
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoute.to(const CustomizeHomeScreen()),
                      ).then((_) => setState(() {}));
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                TranslationService.translate('shake_to_undo', lang),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: tileTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                TranslationService.translate('shake_to_undo_subtitle', lang),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Switch(
                          value: _shakeToUndo,
                          onChanged: (val) {
                            setState(() => _shakeToUndo = val);
                            _saveSettings();
                          },
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF48BB78),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                TranslationService.translate('speech_navigation', lang),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: tileTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                TranslationService.translate('speech_navigation_subtitle', lang),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Switch(
                          value: _speechNavigation,
                          onChanged: (val) {
                            setState(() => _speechNavigation = val);
                            _saveSettings();
                          },
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF48BB78),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 11. AI & Mascot Controls Section
              _buildSectionTitle(TranslationService.translate('ai_mascot_settings', lang)),
              _buildCardContainer(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                TranslationService.translate('local_ai', lang),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: tileTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                TranslationService.translate('local_ai_subtitle', lang),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Switch(
                          value: _useLocalAI,
                          onChanged: (val) {
                            setState(() => _useLocalAI = val);
                            _saveSettings();
                          },
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF48BB78),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                TranslationService.translate('floating_mascot', lang),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: tileTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                TranslationService.translate('floating_mascot_subtitle', lang),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Switch(
                          value: _showFloatingMascot,
                          onChanged: (val) {
                            setState(() => _showFloatingMascot = val);
                            _saveSettings();
                          },
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF48BB78),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 12. HELP Section
              _buildSectionTitle(TranslationService.translate('help', lang)),
              _buildCardContainer(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                  Icons.info_outline,
                                  color: Color(0xFF0284C7),
                                  size: 24,
                                ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    TranslationService.translate('how_to_use', lang),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    TranslationService.translate('how_to_use_subtitle', lang),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 38,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(19),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                AppRoute.to(const HelpGuideScreen()),
                              );
                            },
                            icon: Text(
                              TranslationService.translate('open_help', lang),
                              style: GoogleFonts.inter(
                                color: const Color(0xFF3B82F6),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            label: const Icon(
                              Icons.arrow_forward,
                              color: Color(0xFF3B82F6),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 13. ABOUT Section
              _buildSectionTitle(TranslationService.translate('about', lang)),
              _buildCardContainer(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset(
                              'assets/Mascots/App Mascot.png',
                              width: 64,
                              height: 64,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Buddy',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'v.1.0.0',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF64748B),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    TranslationService.translate('about_desc', lang),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _openURL('https://easylense-website.vercel.app/'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.language, color: Color(0xFF2563EB), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'easylens.app',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF2563EB),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.open_in_new, color: Color(0xFF2563EB), size: 12),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => _openURL('https://github.com/Thes-IS-IT'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.people_outline, color: Color(0xFF2563EB), size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Contributors',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF2563EB),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.cloud_download_outlined, color: Color(0xFF3B82F6)),
                      title: Text(
                        TranslationService.translate('check_updates', lang),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                      ),
                      subtitle: Text(
                        TranslationService.translate('updates_subtitle', lang),
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      trailing: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
                      onTap: () {},
                    ),
                  ),
                  
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
                      title: Text(
                        TranslationService.translate('community', lang),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                      ),
                      subtitle: Text(
                        TranslationService.translate('community_subtitle', lang),
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      trailing: const Icon(Icons.open_in_new, color: Color(0xFF94A3B8), size: 16),
                      onTap: () => _openURL('https://www.facebook.com/profile.php?id=61566090583740'),
                    ),
                  ),
                  
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6)),
                      title: Text(
                        TranslationService.translate('send_feedback', lang),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                      ),
                      subtitle: Text(
                        TranslationService.translate('feedback_subtitle', lang),
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                      onTap: () => _openURL('https://forms.gle/DGSCAKTR2ai39K6VA'),
                    ),
                  ),
                  
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                TranslationService.translate('privacy_notice', lang),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF2563EB),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          TranslationService.translate('privacy_desc', lang),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
              
              const SizedBox(height: 32),

              // 13. Log Out Button S01
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE2E2),
                    foregroundColor: const Color(0xFF991B1B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.0),
                    ),
                  ),
                  onPressed: () async {
                    await _firebaseService.signOut();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        AppRoute.to(const OnboardingScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.exit_to_app, color: Color(0xFF991B1B)),
                  label: Text(
                    TranslationService.translate('log_out', lang),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // 14. Bottom descriptive bio text paragraph S01
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 8.0),
                child: Text(
                  TranslationService.translate('bottom_bio', lang),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }
}
