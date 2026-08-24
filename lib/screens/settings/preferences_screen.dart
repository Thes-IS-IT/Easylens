import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'voice_feedback_screen.dart';
import '../../services/settings_service.dart';
import '../../services/sound_service.dart';
import '../../services/firebase_service.dart';
import '../../services/translation_service.dart';
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
  bool _navigationHaptics = true;
  bool _buttonHaptics = true;
  bool _soundEffects = true;
  double _speechRate = 0.5;
  double _pitch = 0.5;
  String _selectedVoicePersona = 'Aria (Calm)';

  // Text size state
  String _selectedTextSize = 'Default';
  double _textSizeScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settings = SettingsService();
    setState(() {
      _voiceFeedback = settings.voiceFeedback;
      _navigationHaptics = settings.navigationHaptics;
      _buttonHaptics = settings.buttonHaptics;
      _soundEffects = settings.soundEffects;
      _selectedVoicePersona = settings.selectedVoicePersona;
      _speechRate = settings.speechRate;
      _pitch = settings.speechPitch;
      _selectedTextSize = settings.selectedTextSize;
      _textSizeScale = settings.textSizeScale;
    });
  }

  void _saveSettings({bool? voice, bool? navHaptics, bool? buttonHaptics, bool? sounds, double? rate, double? pitch}) {
    final settings = SettingsService();
    settings.updateSettings(
      voiceFeedback: voice,
      navigationHaptics: navHaptics,
      buttonHaptics: buttonHaptics,
      soundEffects: sounds,
      speechRate: rate,
      speechPitch: pitch,
    );

    // Sync preferences to cloud
    final user = FirebaseService().currentUser;
    if (user != null) {
      FirebaseService().syncPreferencesToCloud(user.uid, {
        'voiceFeedback': voice ?? _voiceFeedback,
        'navigationHaptics': navHaptics ?? _navigationHaptics,
        'buttonHaptics': buttonHaptics ?? _buttonHaptics,
        'hapticFeedback': buttonHaptics ?? _buttonHaptics,
        'soundEffects': sounds ?? _soundEffects,
        'speechRate': rate ?? _speechRate,
        'speechPitch': pitch ?? _pitch,
      });
    }
  }

  void _saveTextSize(String option, double scale) {
    final settings = SettingsService();
    settings.updateSettings(
      selectedTextSize: option,
      textSizeCustomScale: scale,
    );

    final user = FirebaseService().currentUser;
    if (user != null) {
      FirebaseService().syncPreferencesToCloud(user.uid, {
        'selectedTextSize': option,
        'textSizeScale': scale,
      });
    }
  }

  Widget _buildTextSizeSection({
    required String selectedOption,
    required double currentScale,
    required Color tileTextColor,
    required Color secondaryTextColor,
    required bool isDark,
    required bool isDefault,
    required String lang,
  }) {
    final titleText = TranslationService.translate('text_size', lang);
    final subtitleText = TranslationService.translate('text_size_subtitle', lang);
    final previewHeader = TranslationService.translate('text_size_preview', lang);
    final previewDesc = TranslationService.translate('text_size_preview_desc', lang);

    final options = [
      {'label': TranslationService.translate('small', lang), 'key': 'Small', 'scale': 0.85},
      {'label': TranslationService.translate('default_size', lang), 'key': 'Default', 'scale': 1.00},
      {'label': TranslationService.translate('large', lang), 'key': 'Large', 'scale': 1.15},
      {'label': TranslationService.translate('extra_large', lang), 'key': 'Extra Large', 'scale': 1.30},
    ];

    final percentLabel = '${(currentScale * 100).round()}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: AppColors.cardBorder.withOpacity(isDark ? 0.6 : (isDefault ? 0.0 : 1.0)),
          width: 1.5,
        ),
        boxShadow: isDefault
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.format_size_rounded,
                    color: AppColors.primaryButton,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    titleText,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: tileTextColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryButton.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  percentLabel,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.primaryButton,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitleText,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: secondaryTextColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),

          // Preset Option Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final scaleVal = opt['scale'] as double;
              final label = opt['label'] as String;
              final keyStr = opt['key'] as String;
              final isSelected = selectedOption == keyStr ||
                  (selectedOption == 'Custom' && (currentScale - scaleVal).abs() < 0.02);

              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  SoundService.playClick();
                  if (selected) {
                    setState(() {
                      _selectedTextSize = keyStr;
                      _textSizeScale = scaleVal;
                    });
                    _saveTextSize(keyStr, scaleVal);
                  }
                },
                selectedColor: AppColors.primaryButton,
                backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                labelStyle: GoogleFonts.inter(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                  color: isSelected
                      ? AppColors.primaryButtonText
                      : (isDark ? Colors.white : AppColors.primaryText),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected ? AppColors.primaryButton : Colors.transparent,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Fine-tuning Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryButton,
              inactiveTrackColor: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
              thumbColor: AppColors.primaryButton,
              overlayColor: AppColors.primaryButton.withOpacity(0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: currentScale.clamp(0.85, 1.35),
              min: 0.85,
              max: 1.35,
              divisions: 10,
              onChanged: (val) {
                final rounded = (val * 100).round() / 100.0;
                String matchedOption = 'Custom';
                if ((rounded - 0.85).abs() < 0.01) {
                  matchedOption = 'Small';
                } else if ((rounded - 1.00).abs() < 0.01) {
                  matchedOption = 'Default';
                } else if ((rounded - 1.15).abs() < 0.01) {
                  matchedOption = 'Large';
                } else if ((rounded - 1.30).abs() < 0.01) {
                  matchedOption = 'Extra Large';
                }

                setState(() {
                  _selectedTextSize = matchedOption;
                  _textSizeScale = rounded;
                });
                _saveTextSize(matchedOption, rounded);
              },
            ),
          ),

          const SizedBox(height: 12),

          // Live Text Sample Preview Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      color: AppColors.primaryButton,
                      size: 20 * currentScale,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        previewHeader,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14 * currentScale,
                          color: tileTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  previewDesc,
                  style: GoogleFonts.inter(
                    fontSize: 12 * currentScale,
                    color: secondaryTextColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? titleColor,
  }) {
    final settings = SettingsService();
    final isDark = settings.isDarkMode;
    final isDefault = settings.selectedContrastTheme == 'Default' && !isDark;
    final resolvedColor = titleColor ?? (isDark ? Colors.white : (isDefault ? Colors.black : AppColors.primaryText));
    final secondaryTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);

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
                      color: secondaryTextColor,
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
            onChanged: (val) {
              SoundService.playClick();
              onChanged(val);
            },
            activeColor: isDark ? AppColors.primaryButtonText : Colors.white,
            activeTrackColor: AppColors.primaryButton,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
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
    final settings = SettingsService();
    final isDark = settings.isDarkMode;
    final isDefault = settings.selectedContrastTheme == 'Default' && !isDark;
    final resolvedColor = titleColor ?? (isDark ? Colors.white : (isDefault ? Colors.black : AppColors.primaryText));
    final trackColor = AppColors.primaryButton;

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
              activeTrackColor: trackColor,
              inactiveTrackColor: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
              thumbColor: trackColor,
              overlayColor: trackColor.withOpacity(0.15),
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
        final settings = SettingsService();
        final isDark = settings.isDarkMode;
        final isDefault = settings.selectedContrastTheme == 'Default' && !isDark;
        final headerColor = AppColors.primaryText;
        final tileTextColor = isDark ? Colors.white : (isDefault ? Colors.black : AppColors.primaryText);
        final secondaryTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
        final cardColor = isDark ? const Color(0xFF141414) : AppColors.primaryBackground;
        final lang = settings.selectedLanguage;
        final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Sticky Header Bar (Back Button + Title)
                Container(
                  color: AppColors.lightBackground,
                  padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          SoundService.playClick();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : (isDefault ? Colors.white : AppColors.primaryBackground),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.cardBorder.withOpacity(isDark ? 0.6 : (isDefault ? 0.0 : 1.0)), width: 1.5),
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
                                TranslationService.translate('back', lang),
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
                      const SizedBox(height: 16),
                      Text(
                        TranslationService.translate('preferences', lang),
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: headerColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Scrollable Preferences List
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),

                        // Text Size Customization Section
                        _buildTextSizeSection(
                          selectedOption: _selectedTextSize,
                          currentScale: _textSizeScale,
                          tileTextColor: tileTextColor,
                          secondaryTextColor: secondaryTextColor,
                          isDark: isDark,
                          isDefault: isDefault,
                          lang: lang,
                        ),

                        const SizedBox(height: 20),

                        // Voice & Haptics Configurations Card Container
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(24.0),
                            border: Border.all(color: AppColors.cardBorder.withOpacity(isDark ? 0.6 : (isDefault ? 0.0 : 1.0)), width: 1.5),
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

                              Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0)),
                              _buildSwitchRow(
                                title: 'Navigation Voice Assistant',
                                subtitle: 'Keep speech enabled specifically for route navigation instructions.',
                                value: _navigationAssistant,
                                onChanged: (val) => setState(() => _navigationAssistant = val),
                                titleColor: tileTextColor,
                              ),
                              Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0)),
                              _buildSwitchRow(
                                title: isFilipino ? 'Haptics sa EasyLens Navigation' : 'EasyLens Navigation Haptics',
                                subtitle: isFilipino
                                    ? 'Vibration ng device para sa mga babala (2x pulse sa dilaw na babala, 5x pulse sa kritikal na pula).'
                                    : 'Vibrates device for hazard alerts (2x pulses for caution/yellow hazards, 5x pulses for critical/red hazards).',
                                value: _navigationHaptics,
                                onChanged: (val) {
                                  setState(() => _navigationHaptics = val);
                                  _saveSettings(navHaptics: val);
                                },
                                titleColor: tileTextColor,
                              ),
                              Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0)),
                              _buildSwitchRow(
                                title: isFilipino ? 'Panginginig sa Pindutan at Nabigasyon' : 'Button Navigation Haptics',
                                subtitle: isFilipino
                                    ? 'Panginginig ng haptics kapag pumipindot ng mga buton at tab ng nabigasyon.'
                                    : 'Feel physical tactile vibration when tapping buttons and navigation tabs.',
                                value: _buttonHaptics,
                                onChanged: (val) {
                                  setState(() => _buttonHaptics = val);
                                  _saveSettings(buttonHaptics: val);
                                  if (val) SoundService.playClick();
                                },
                                titleColor: tileTextColor,
                              ),
                              Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0)),
                              _buildSwitchRow(
                                title: isFilipino ? 'Tunog ng Click sa Pindutan' : 'Button Click Sounds',
                                subtitle: isFilipino
                                    ? 'Mabilis na tunog ng pag-click kapag pumipindot ng mga buton.'
                                    : 'Plays instant low-latency click sound effects on all button clicks.',
                                value: _soundEffects,
                                onChanged: (val) {
                                  setState(() => _soundEffects = val);
                                  SettingsService().updateSoundEffects(val);
                                  _saveSettings(sounds: val);
                                  if (val) SoundService.playClick();
                                },
                                titleColor: tileTextColor,
                              ),
                              Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0)),
                              _buildSliderRow(
                                title: 'Speech Rate',
                                value: _speechRate,
                                onChanged: (val) {
                                  setState(() => _speechRate = val);
                                  _saveSettings(rate: val);
                                },
                                titleColor: tileTextColor,
                              ),
                              Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0)),
                              _buildSliderRow(
                                title: 'Pitch',
                                value: _pitch,
                                onChanged: (val) {
                                  setState(() => _pitch = val);
                                  _saveSettings(pitch: val);
                                },
                                titleColor: tileTextColor,
                              ),
                              Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0)),
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
                                  style: GoogleFonts.inter(fontSize: 12, color: secondaryTextColor),
                                ),
                                trailing: Icon(Icons.chevron_right, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
                                onTap: () async {
                                  SoundService.playClick();
                                  await Navigator.of(context).push(
                                    AppRoute.to(const VoiceFeedbackScreen()),
                                  );
                                  _loadSettings();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
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
}
