import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../services/settings_service.dart';
import '../../services/tts_service.dart';
import '../../services/firebase_service.dart';

class VoicePersona {
  final String id;
  final String name;
  final String description;

  VoicePersona({
    required this.id,
    required this.name,
    required this.description,
  });
}

class VoiceFeedbackScreen extends StatefulWidget {
  const VoiceFeedbackScreen({super.key});

  @override
  State<VoiceFeedbackScreen> createState() => _VoiceFeedbackScreenState();
}

class _VoiceFeedbackScreenState extends State<VoiceFeedbackScreen> {
  String _selectedPersonaId = 'aria';
  String? _currentlyPlayingId; 

  final List<VoicePersona> _personas = [
    VoicePersona(id: 'aria', name: 'Aria (Calm)', description: 'Warm and reassuring voice'),
    VoicePersona(id: 'max', name: 'Max (Bold)', description: 'Confident and clear voice'),
    VoicePersona(id: 'nova', name: 'Nova (Bright)', description: 'Energetic and upbeat voice'),
    VoicePersona(id: 'echo', name: 'Echo (Deep)', description: 'Deep and authoritative voice'),
    VoicePersona(id: 'bella', name: 'Bella (Gentle)', description: 'Soft and soothing voice'),
  ];

  @override
  void initState() {
    super.initState();
    final name = SettingsService().selectedVoicePersona;
    final persona = _personas.firstWhere(
      (p) => p.name == name,
      orElse: () => _personas.first,
    );
    _selectedPersonaId = persona.id;
  }

  void _selectPersona(VoicePersona vp) {
    setState(() {
      _selectedPersonaId = vp.id;
    });
    
    // Save to SettingsService
    SettingsService().updateSettings(selectedVoicePersona: vp.name);
    
    // Save to Firestore (only if logged in)
    final user = FirebaseService().currentUser;
    if (user != null) {
      FirebaseService().syncPreferencesToCloud(user.uid, {
        'selectedVoicePersona': vp.name,
      });
    }
  }

  void _togglePlay(String id) {
    final persona = _personas.firstWhere((p) => p.id == id);
    
    // Temporarily apply persona style to play preview
    SettingsService().updateSettings(selectedVoicePersona: persona.name);
    TtsService().speak("This is a preview of the ${persona.name} voice persona.");
    
    setState(() {
      if (_currentlyPlayingId == id) {
        _currentlyPlayingId = null;
        TtsService().stop();
      } else {
        _currentlyPlayingId = id;
      }
    });
  }

  Widget _buildPersonaCard(VoicePersona vp) {
    final isSelected = _selectedPersonaId == vp.id;
    final isPlaying = _currentlyPlayingId == vp.id;
    final cardColor = isSelected ? AppColors.primaryButton : AppColors.lightBackground;
    final titleColor = isSelected ? AppColors.primaryButtonText : AppColors.primaryText;
    final subtitleColor = isSelected ? AppColors.primaryButtonText.withOpacity(0.8) : AppColors.textMuted;
    final borderColor = isSelected ? Colors.transparent : AppColors.cardBorder.withOpacity(0.3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16.0),
        border: isSelected ? null : Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: GestureDetector(
          onTap: () => _togglePlay(vp.id),
          child: Icon(
            isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
            color: isSelected ? AppColors.primaryButtonText : AppColors.primaryText,
            size: 32,
          ),
        ),
        title: Text(
          vp.name,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: titleColor,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          vp.description,
          style: GoogleFonts.inter(
            color: subtitleColor,
            fontSize: 12,
          ),
        ),
        trailing: GestureDetector(
          onTap: () => _selectPersona(vp),
          child: Icon(
            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isSelected ? AppColors.primaryButtonText : AppColors.primaryText,
            size: 24,
          ),
        ),
        onTap: () => _selectPersona(vp),
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
                    'Voice Feedback',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: headerColor,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Top Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24.0),
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
                      children: [
                        Image.asset(
                          'assets/Mascots/App Mascot.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Voice Persona',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: tileTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Choose Buddy\'s voice personality for safety alerts, route distractions, and settings.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Section Title
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
                    child: Text(
                      'CHOOSE A PERSONALITY',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  // 5. Selectable list cards
                  ..._personas.map(_buildPersonaCard),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
