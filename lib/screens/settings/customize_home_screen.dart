import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../services/settings_service.dart';
import '../../services/translation_service.dart';
import '../../services/firebase_service.dart';
import '../../services/sound_service.dart';

class CustomizeHomeScreen extends StatefulWidget {
  const CustomizeHomeScreen({super.key});

  @override
  State<CustomizeHomeScreen> createState() => _CustomizeHomeScreenState();
}

class _CustomizeHomeScreenState extends State<CustomizeHomeScreen> {
  final _settingsService = SettingsService();
  final _firebaseService = FirebaseService();

  late List<String> _cardsOrder;
  late Set<String> _enabledCards;

  final Map<String, String> _cardNames = {
    'buddy': 'Talk to Buddy (Local LLM)',
    'easylens': 'EasyLens Sensor',
    'faces': 'Register Face',
    'text': 'Nearby Text',
    'objects': 'Nearby Objects',
    'navigation': 'Audio Navigation',
    'sos': 'SOS Emergency',
  };

  final Map<String, IconData> _cardIcons = {
    'buddy': Icons.chat_bubble_outline,
    'easylens': Icons.visibility,
    'faces': Icons.face_retouching_natural,
    'text': Icons.notes,
    'objects': Icons.zoom_in,
    'navigation': Icons.near_me,
    'sos': Icons.phone_in_talk,
  };

  @override
  void initState() {
    super.initState();
    // Fetch current state
    _cardsOrder = List.from(_settingsService.homeScreenCards);
    _enabledCards = Set.from(_settingsService.homeScreenCards);

    // Make sure all possible cards are represented in the list
    for (var key in _cardNames.keys) {
      if (!_cardsOrder.contains(key)) {
        _cardsOrder.add(key);
      }
    }
  }

  void _saveSettings() {
    // Collect enabled cards preserving order
    final updatedList = _cardsOrder.where((key) => _enabledCards.contains(key)).toList();
    _settingsService.updateSettings(homeScreenCards: updatedList);

    // Sync user preferences to Cloud
    final user = _firebaseService.currentUser;
    if (user != null) {
      _firebaseService.syncPreferencesToCloud(user.uid, {
        'homeScreenCards': updatedList,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = _settingsService.selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('filipino') || lang.toLowerCase().contains('tagalog');
    final isDark = _settingsService.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Back button
              GestureDetector(
                onTap: () {
                  SoundService.playClick();
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 95,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: isDark ? Border.all(color: const Color(0xFF333333)) : null,
                    boxShadow: isDark ? null : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chevron_left, color: AppColors.primaryText, size: 24),
                      const SizedBox(width: 4),
                      Text(
                        TranslationService.translate('back', lang),
                        style: GoogleFonts.inter(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Header
              Text(
                isFilipino ? 'I-customize ang Home' : 'Customize Home Screen',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                isFilipino 
                    ? 'I-drag para ayusin ang pagkakasunod-sunod. I-toggle para i-hide o ipakita ang mga dashboard card.'
                    : 'Drag cards to reorder them. Toggle switches to show or hide dashboard card options.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.45,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Reorderable list
              Expanded(
                child: ReorderableListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _cardsOrder.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final item = _cardsOrder.removeAt(oldIndex);
                      _cardsOrder.insert(newIndex, item);
                    });
                    _saveSettings();
                  },
                  itemBuilder: (context, index) {
                    final key = _cardsOrder[index];
                    final isEnabled = _enabledCards.contains(key);
                    final name = TranslationService.translate(key, lang);
                    final icon = _cardIcons[key] ?? Icons.help_outline;

                    return Container(
                      key: ValueKey(key),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
                        boxShadow: isDark ? null : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(Icons.drag_indicator, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            CircleAvatar(
                              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                              child: Icon(icon, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                        title: Text(
                          name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.primaryText,
                          ),
                        ),
                        trailing: Switch(
                          value: isEnabled,
                          activeColor: isDark ? AppColors.primaryButtonText : Colors.white,
                          activeTrackColor: AppColors.primaryButton,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          onChanged: (val) {
                            setState(() {
                              if (val) {
                                _enabledCards.add(key);
                              } else {
                                // Ensure at least one card is active
                                if (_enabledCards.length > 1) {
                                  _enabledCards.remove(key);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isFilipino 
                                            ? 'Kailangang may kahit isang card na nakabukas.'
                                            : 'At least one card must remain enabled.',
                                      ),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                }
                              }
                            });
                            _saveSettings();
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
