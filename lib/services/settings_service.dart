import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();

  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal() {
    loadSettingsFromLocal();
  }

  bool voiceFeedback = true;
  bool hapticFeedback = true;
  bool companionSharing = false;

  String selectedContrastTheme = 'Default';
  String selectedLanguage = 'English (US)';
  String selectedVoicePersona = 'Aria (Calm)';
  String selectedUnit = 'Metric';
  String selectedMobilityAid = 'None (Hands-Free)';

  // New Appearance, Navigation and UI properties
  String appearanceTheme = 'Default';
  int accentColorIndex = 0;
  bool faceIdUnlock = false;
  bool shakeToUndo = true;
  double speechRate = 0.5;
  double speechPitch = 0.5;
  List<String> homeScreenCards = ['buddy', 'easylens', 'faces', 'text', 'objects', 'navigation', 'sos'];

  // Load preferences from local storage (public so TtsService can reload on demand)
  Future<void> loadSettingsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      voiceFeedback = prefs.getBool('voiceFeedback') ?? true;
      hapticFeedback = prefs.getBool('hapticFeedback') ?? true;
      companionSharing = prefs.getBool('companionSharing') ?? false;
      selectedContrastTheme = prefs.getString('selectedContrastTheme') ?? 'Default';
      selectedLanguage = prefs.getString('selectedLanguage') ?? 'English (US)';
      selectedVoicePersona = prefs.getString('selectedVoicePersona') ?? 'Aria (Calm)';
      selectedUnit = prefs.getString('selectedUnit') ?? 'Metric';
      selectedMobilityAid = prefs.getString('selectedMobilityAid') ?? 'None (Hands-Free)';

      appearanceTheme = prefs.getString('appearanceTheme') ?? 'Default';
      accentColorIndex = prefs.getInt('accentColorIndex') ?? 0;
      faceIdUnlock = prefs.getBool('faceIdUnlock') ?? false;
      shakeToUndo = prefs.getBool('shakeToUndo') ?? true;
      speechRate = prefs.getDouble('speechRate') ?? 0.5;
      speechPitch = prefs.getDouble('speechPitch') ?? 0.5;
      homeScreenCards = prefs.getStringList('homeScreenCards') ?? ['buddy', 'easylens', 'faces', 'text', 'objects', 'navigation', 'sos'];
      homeScreenCards.remove('journal');

      notifyListeners();
    } catch (e) {
      print('Error loading settings from local storage: $e');
    }
  }

  // Update and persist settings locally
  Future<void> updateSettings({
    bool? voiceFeedback,
    bool? hapticFeedback,
    bool? companionSharing,
    String? selectedContrastTheme,
    String? selectedLanguage,
    String? selectedVoicePersona,
    String? selectedUnit,
    String? selectedMobilityAid,
    String? appearanceTheme,
    int? accentColorIndex,
    bool? faceIdUnlock,
    bool? shakeToUndo,
    double? speechRate,
    double? speechPitch,
    List<String>? homeScreenCards,
  }) async {
    if (voiceFeedback != null) this.voiceFeedback = voiceFeedback;
    if (hapticFeedback != null) this.hapticFeedback = hapticFeedback;
    if (companionSharing != null) this.companionSharing = companionSharing;
    if (selectedContrastTheme != null) this.selectedContrastTheme = selectedContrastTheme;
    if (selectedLanguage != null) this.selectedLanguage = selectedLanguage;
    if (selectedVoicePersona != null) this.selectedVoicePersona = selectedVoicePersona;
    if (selectedUnit != null) this.selectedUnit = selectedUnit;
    if (selectedMobilityAid != null) this.selectedMobilityAid = selectedMobilityAid;

    if (appearanceTheme != null) this.appearanceTheme = appearanceTheme;
    if (accentColorIndex != null) this.accentColorIndex = accentColorIndex;
    if (faceIdUnlock != null) this.faceIdUnlock = faceIdUnlock;
    if (shakeToUndo != null) this.shakeToUndo = shakeToUndo;
    if (speechRate != null) this.speechRate = speechRate;
    if (speechPitch != null) this.speechPitch = speechPitch;
    if (homeScreenCards != null) this.homeScreenCards = homeScreenCards;
    
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (voiceFeedback != null) await prefs.setBool('voiceFeedback', voiceFeedback);
      if (hapticFeedback != null) await prefs.setBool('hapticFeedback', hapticFeedback);
      if (companionSharing != null) await prefs.setBool('companionSharing', companionSharing);
      if (selectedContrastTheme != null) await prefs.setString('selectedContrastTheme', selectedContrastTheme);
      if (selectedLanguage != null) await prefs.setString('selectedLanguage', selectedLanguage);
      if (selectedVoicePersona != null) await prefs.setString('selectedVoicePersona', selectedVoicePersona);
      if (selectedUnit != null) await prefs.setString('selectedUnit', selectedUnit);
      if (selectedMobilityAid != null) await prefs.setString('selectedMobilityAid', selectedMobilityAid);

      if (appearanceTheme != null) await prefs.setString('appearanceTheme', appearanceTheme);
      if (accentColorIndex != null) await prefs.setInt('accentColorIndex', accentColorIndex);
      if (faceIdUnlock != null) await prefs.setBool('faceIdUnlock', faceIdUnlock);
      if (shakeToUndo != null) await prefs.setBool('shakeToUndo', shakeToUndo);
      if (speechRate != null) await prefs.setDouble('speechRate', speechRate);
      if (speechPitch != null) await prefs.setDouble('speechPitch', speechPitch);
      if (homeScreenCards != null) await prefs.setStringList('homeScreenCards', homeScreenCards);
    } catch (e) {
      print('Error saving settings to local storage: $e');
    }
  }
}
