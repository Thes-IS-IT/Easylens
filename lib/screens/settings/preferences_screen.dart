import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'voice_feedback_screen.dart';
import '../../services/settings_service.dart';
import '../../services/firebase_service.dart';
import '../../constants/colors.dart';
import '../../utils/app_route.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  // Local state toggles
  bool _voiceFeedback = true;
  bool _navigationAssistant = true;
  bool _hapticFeedback = true;
  double _speechRate = 0.5;
  double _pitch = 0.5;
  String _selectedVoicePersona = 'Aria (Calm)';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settings = SettingsService();
    setState(() {
      _voiceFeedback = settings.voiceFeedback;
      _hapticFeedback = settings.hapticFeedback;
      _selectedVoicePersona = settings.selectedVoicePersona;
      _speechRate = settings.speechRate;
      _pitch = settings.speechPitch;
    });
  }

  void _saveSettings({bool? voice, bool? haptics, double? rate, double? pitch}) {
    final settings = SettingsService();
    settings.updateSettings(
      voiceFeedback: voice,
      hapticFeedback: haptics,
      speechRate: rate,
      speechPitch: pitch,
    );

    // Sync preferences to cloud
    final user = FirebaseService().currentUser;
    if (user != null) {
      FirebaseService().syncPreferencesToCloud(user.uid, {
        'voiceFeedback': voice ?? _voiceFeedback,
        'hapticFeedback': haptics ?? _hapticFeedback,
        'speechRate': rate ?? _speechRate,
        'speechPitch': pitch ?? _pitch,
      });
    }
  }

  Widget _buildSwitchRow({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? titleColor,
  }) {
    final isDefault = SettingsService().selectedContrastTheme == 'Default';
    final resolvedColor = titleColor ?? (isDefault ? Colors.black : AppColors.primaryText);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: resolvedColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF48BB78),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFCBD5E1),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
    Color? titleColor,
  }) {
    final isDefault = SettingsService().selectedContrastTheme == 'Default';
    final resolvedColor = titleColor ?? (isDefault ? Colors.black : AppColors.primaryText);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: resolvedColor,
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF3B82F6),
              inactiveTrackColor: const Color(0xFFE2E8F0),
              thumbColor: const Color(0xFF3B82F6),
              overlayColor: const Color(0xFF3B82F6).withOpacity(0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              onChanged: onChanged,
            ),
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
        final isDefault = SettingsService().selectedContrastTheme == 'Default';
        final headerColor = isDefault ? const Color(0xFF002663) : AppColors.primaryText;
        final tileTextColor = isDefault ? Colors.black : AppColors.primaryText;
        final cardColor = AppColors.primaryBackground;
        final isFilipino = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') ||
            SettingsService().selectedLanguage.toLowerCase().contains('filipino');

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
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chevron_left, color: headerColor, size: 24),
                          const SizedBox(width: 4),
                          Text(
                            'Back',
                            style: GoogleFonts.inter(
                              color: headerColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 2. Title Header
                  Text(
                    'Preferences',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: headerColor,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Configurations Card Container
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24.0),
                      border: isDefault ? null : Border.all(color: AppColors.cardBorder, width: 1.5),
                      boxShadow: isDefault ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ] : null,
                    ),
                    child: Column(
                      children: [
                        _buildSwitchRow(
                          title: 'Voice Feedback',
                          subtitle: 'Enable speech feedback and safety announcements.',
                          value: _voiceFeedback,
                          onChanged: (val) {
                            setState(() => _voiceFeedback = val);
                            _saveSettings(voice: val);
                          },
                          titleColor: tileTextColor,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildSwitchRow(
                          title: 'Navigation Voice Assistant',
                          subtitle: 'Keep speech enabled specifically for route navigation instructions.',
                          value: _navigationAssistant,
                          onChanged: (val) => setState(() => _navigationAssistant = val),
                          titleColor: tileTextColor,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildSwitchRow(
                          title: 'Haptic Feedback',
                          subtitle: isFilipino
                              ? 'Vibration ng device para sa babala (2x pulse sa dilaw na babala, 5x pulse sa kritikal na pula).'
                              : 'Vibrates device for hazard alerts (2x pulses for caution/yellow hazards, 5x pulses for critical/red hazards).',
                          value: _hapticFeedback,
                          onChanged: (val) {
                            setState(() => _hapticFeedback = val);
                            _saveSettings(haptics: val);
                          },
                          titleColor: tileTextColor,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildSliderRow(
                          title: 'Speech Rate',
                          value: _speechRate,
                          onChanged: (val) {
                            setState(() => _speechRate = val);
                            _saveSettings(rate: val);
                          },
                          titleColor: tileTextColor,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildSliderRow(
                          title: 'Pitch',
                          value: _pitch,
                          onChanged: (val) {
                            setState(() => _pitch = val);
                            _saveSettings(pitch: val);
                          },
                          titleColor: tileTextColor,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            ),
                          ),
                          title: Text(
                            'Voice Feedback',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tileTextColor, fontSize: 15),
                          ),
                          subtitle: Text(
                            _selectedVoicePersona,
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                          onTap: () async {
                            await Navigator.of(context).push(
                              AppRoute.to(const VoiceFeedbackScreen()),
                            );
                            _loadSettings();
                          },
                        ),
                      ],
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
