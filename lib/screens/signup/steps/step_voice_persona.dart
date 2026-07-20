import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../l10n/signup_strings.dart';
import '../../../services/settings_service.dart';
import '../../../services/tts_service.dart';
import 'step_helpers.dart';

// STEP 7: Voice Persona Selector with Live Voice Playback Preview
class StepVoicePersona extends StatefulWidget {
  final String selectedPersona;
  final String language;
  final ValueChanged<String> onChanged;

  const StepVoicePersona({
    super.key,
    required this.selectedPersona,
    required this.language,
    required this.onChanged,
  });

  @override
  State<StepVoicePersona> createState() => _StepVoicePersonaState();
}

class _StepVoicePersonaState extends State<StepVoicePersona> {
  String? _currentlyPlayingPersona;

  List<Map<String, String>> _buildPersonas(String lang) => [
    {'name': 'Aria (Calm)', 'desc': SignupL10n.t('voice_aria_desc', lang)},
    {'name': 'Max (Bold)', 'desc': SignupL10n.t('voice_max_desc', lang)},
    {'name': 'Nova (Bright)', 'desc': SignupL10n.t('voice_nova_desc', lang)},
    {'name': 'Echo (Deep)', 'desc': SignupL10n.t('voice_echo_desc', lang)},
    {'name': 'Bella (Gentle)', 'desc': SignupL10n.t('voice_bella_desc', lang)},
    {'name': 'Leo (Child)', 'desc': SignupL10n.t('voice_leo_desc', lang)},
  ];

  Future<void> _playVoicePreview(String personaName) async {
    final isTagalog = widget.language.toLowerCase().contains('filipino') ||
        widget.language.toLowerCase().contains('tagalog');

    setState(() {
      _currentlyPlayingPersona = personaName;
    });

    // Save persona to settings so TtsService applies pitch, rate & gender immediately
    await SettingsService().updateSettings(selectedVoicePersona: personaName);
    
    // Stop any ongoing TTS playback
    await TtsService().stop();

    String sampleText;
    switch (personaName) {
      case 'Aria (Calm)':
        sampleText = isTagalog
            ? "Ako si Aria. Sasamahan kita sa isang mahinahong boses."
            : "Hello! I'm Aria. I'll guide you with a soft and calm voice.";
        break;
      case 'Max (Bold)':
        sampleText = isTagalog
            ? "Ako si Max. Tutulungan kita sa malinaw at matatag na boses."
            : "Hello! I'm Max. I'll assist you with a clear and confident voice.";
        break;
      case 'Nova (Bright)':
        sampleText = isTagalog
            ? "Ako si Nova! Handa kitang gabayan nang may sigla!"
            : "Hello! I'm Nova! Ready to help you with bright energy!";
        break;
      case 'Echo (Deep)':
        sampleText = isTagalog
            ? "Ako si Echo. Tutulungan kita sa malalim at malinaw na boses."
            : "Hello, I'm Echo. I'll assist you with a deep and clear voice.";
        break;
      case 'Bella (Gentle)':
        sampleText = isTagalog
            ? "Ako si Bella. Tutulungan kita nang dahan-dahan at mahinahon."
            : "Hello, I'm Bella. I will help you gently at your own pace.";
        break;
      case 'Leo (Child)':
        sampleText = isTagalog
            ? "Hi! Ako si Leo! Sabay tayong mag-explore!"
            : "Hi! I'm Leo! Let's explore together!";
        break;
      default:
        sampleText = isTagalog
            ? "Magandang araw! Ito ang halimbawa ng aking boses."
            : "Hello! This is a preview of my voice.";
    }

    await TtsService().speak(sampleText);

    if (mounted) {
      setState(() {
        _currentlyPlayingPersona = null;
      });
    }
  }

  void _onSelectPersona(String personaName) {
    widget.onChanged(personaName);
    _playVoicePreview(personaName);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: SignupL10n.t('voice_persona_title', widget.language),
          subtitle: SignupL10n.t('voice_persona_subtitle', widget.language),
        ),
        const SizedBox(height: 24),
        Column(
          children: _buildPersonas(widget.language).map((p) {
            final name = p['name']!;
            final desc = p['desc']!;
            final isSelected = widget.selectedPersona == name;
            final isPlayingThis = _currentlyPlayingPersona == name;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: GestureDetector(
                onTap: () => _onSelectPersona(name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryButton : AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryButton : AppColors.cardBorder.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Speaker / Play sample button
                      GestureDetector(
                        onTap: () => _playVoicePreview(name),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: isSelected
                              ? AppColors.primaryButtonText.withOpacity(0.2)
                              : AppColors.primaryButton.withOpacity(0.1),
                          child: Icon(
                            isPlayingThis ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                            color: isSelected ? AppColors.primaryButtonText : AppColors.primaryButton,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isSelected ? AppColors.primaryButtonText : AppColors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isSelected
                                    ? AppColors.primaryButtonText.withOpacity(0.85)
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                          border: Border.all(
                            color: isSelected ? AppColors.primaryButtonText : AppColors.primaryText,
                            width: 2.0,
                          ),
                        ),
                        child: isSelected
                            ? Icon(Icons.check, size: 16, color: AppColors.primaryButtonText)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
