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
  bool speechNavigation = false;
  bool get voiceNavigationEnabled => speechNavigation;
  double speechRate = 0.5;
  double speechPitch = 0.5;
  List<String> homeScreenCards = ['buddy', 'easylens', 'faces', 'text', 'navigation', 'sos'];

  // Local AI and Floating Mascot control
  bool useLocalAI = true;
  bool showFloatingMascot = true;

  // Custom Gemini API Key
  String geminiApiKey = '';
  String userDisplayName = '';

  Future<void> updateDisplayName(String name) async {
    if (userDisplayName == name) return;
    userDisplayName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userDisplayName', name);
    notifyListeners();
  }

  // Load preferences from local storage (public so TtsService can reload on demand)
  Future<void> loadSettingsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      voiceFeedback = prefs.getBool('voiceFeedback') ?? true;
      hapticFeedback = prefs.getBool('hapticFeedback') ?? true;
      companionSharing = prefs.getBool('companionSharing') ?? false;
      selectedContrastTheme = prefs.getString('selectedContrastTheme') ?? 'Default';
      appearanceTheme = prefs.getString('appearanceTheme') ?? 'Default';
      accentColorIndex = prefs.getInt('accentColorIndex') ?? 0;

      _syncThemeState(
        contrastTheme: selectedContrastTheme != 'Default' ? selectedContrastTheme : null,
        appearance: appearanceTheme != 'Default' ? appearanceTheme : null,
        accentIdx: accentColorIndex,
      );

      selectedLanguage = prefs.getString('selectedLanguage') ?? 'English (US)';
      selectedVoicePersona = prefs.getString('selectedVoicePersona') ?? 'Aria (Calm)';
      selectedUnit = prefs.getString('selectedUnit') ?? 'Metric';
      selectedMobilityAid = prefs.getString('selectedMobilityAid') ?? 'None (Hands-Free)';

      faceIdUnlock = prefs.getBool('faceIdUnlock') ?? false;
      shakeToUndo = prefs.getBool('shakeToUndo') ?? true;
      speechNavigation = prefs.getBool('speechNavigation') ?? false;
      speechRate = prefs.getDouble('speechRate') ?? 0.5;
      speechPitch = prefs.getDouble('speechPitch') ?? 0.5;
      homeScreenCards = prefs.getStringList('homeScreenCards') ?? ['buddy', 'easylens', 'faces', 'text', 'navigation', 'sos'];
      homeScreenCards.remove('journal');
      homeScreenCards.remove('objects');

      useLocalAI = prefs.getBool('useLocalAI') ?? true;
      showFloatingMascot = prefs.getBool('showFloatingMascot') ?? true;
      geminiApiKey = prefs.getString('geminiApiKey') ?? '';
      userDisplayName = prefs.getString('userDisplayName') ?? '';

      notifyListeners();
    } catch (e) {
      print('Error loading settings from local storage: $e');
    }
  }

  void _syncThemeState({String? contrastTheme, String? appearance, int? accentIdx}) {
    if (contrastTheme != null) {
      selectedContrastTheme = contrastTheme;
      if (contrastTheme == 'Black on White') {
        appearanceTheme = 'White';
        accentColorIndex = 0;
      } else if (contrastTheme == 'Green on Black') {
        appearanceTheme = 'Black';
        accentColorIndex = 0;
      } else if (contrastTheme == 'Yellow on Black') {
        appearanceTheme = 'Black';
        accentColorIndex = 1;
      } else if (contrastTheme == 'White on Black') {
        appearanceTheme = 'Black';
        accentColorIndex = 2;
      } else if (contrastTheme == 'Cyan on Black') {
        appearanceTheme = 'Black';
        accentColorIndex = 3;
      } else {
        appearanceTheme = 'Default';
        accentColorIndex = 0;
      }
    } else if (appearance != null || accentIdx != null) {
      if (appearance != null) appearanceTheme = appearance;
      if (accentIdx != null) accentColorIndex = accentIdx;

      if (appearanceTheme == 'Default') {
        selectedContrastTheme = 'Default';
      } else if (appearanceTheme == 'White') {
        selectedContrastTheme = 'Black on White';
      } else if (appearanceTheme == 'Black') {
        switch (accentColorIndex) {
          case 0:
            selectedContrastTheme = 'Green on Black';
            break;
          case 1:
            selectedContrastTheme = 'Yellow on Black';
            break;
          case 2:
            selectedContrastTheme = 'White on Black';
            break;
          case 3:
            selectedContrastTheme = 'Cyan on Black';
            break;
          default:
            selectedContrastTheme = 'White on Black';
            break;
        }
      }
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
    bool? speechNavigation,
    double? speechRate,
    double? speechPitch,
    List<String>? homeScreenCards,
    bool? useLocalAI,
    bool? showFloatingMascot,
    String? geminiApiKey,
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

    _syncThemeState(
      contrastTheme: this.selectedContrastTheme,
      appearance: this.appearanceTheme,
      accentIdx: this.accentColorIndex,
    );

    if (faceIdUnlock != null) this.faceIdUnlock = faceIdUnlock;
    if (shakeToUndo != null) this.shakeToUndo = shakeToUndo;
    if (speechNavigation != null) this.speechNavigation = speechNavigation;
    if (speechRate != null) this.speechRate = speechRate;
    if (speechPitch != null) this.speechPitch = speechPitch;
    if (homeScreenCards != null) this.homeScreenCards = homeScreenCards;
    
    if (useLocalAI != null) this.useLocalAI = useLocalAI;
    if (showFloatingMascot != null) this.showFloatingMascot = showFloatingMascot;
    if (geminiApiKey != null) this.geminiApiKey = geminiApiKey;
    
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (voiceFeedback != null) await prefs.setBool('voiceFeedback', voiceFeedback);
      if (hapticFeedback != null) await prefs.setBool('hapticFeedback', hapticFeedback);
      if (companionSharing != null) await prefs.setBool('companionSharing', companionSharing);
      await prefs.setString('selectedContrastTheme', this.selectedContrastTheme);
      await prefs.setString('appearanceTheme', this.appearanceTheme);
      await prefs.setInt('accentColorIndex', this.accentColorIndex);
      if (selectedLanguage != null) await prefs.setString('selectedLanguage', selectedLanguage);
      if (selectedVoicePersona != null) await prefs.setString('selectedVoicePersona', selectedVoicePersona);
      if (selectedUnit != null) await prefs.setString('selectedUnit', selectedUnit);
      if (selectedMobilityAid != null) await prefs.setString('selectedMobilityAid', selectedMobilityAid);
      if (faceIdUnlock != null) await prefs.setBool('faceIdUnlock', faceIdUnlock);
      if (shakeToUndo != null) await prefs.setBool('shakeToUndo', shakeToUndo);
      if (speechNavigation != null) await prefs.setBool('speechNavigation', speechNavigation);
      if (speechRate != null) await prefs.setDouble('speechRate', speechRate);
      if (speechPitch != null) await prefs.setDouble('speechPitch', speechPitch);
      if (homeScreenCards != null) await prefs.setStringList('homeScreenCards', homeScreenCards);
      
      if (useLocalAI != null) await prefs.setBool('useLocalAI', useLocalAI);
      if (showFloatingMascot != null) await prefs.setBool('showFloatingMascot', showFloatingMascot);
      if (geminiApiKey != null) await prefs.setString('geminiApiKey', geminiApiKey);
    } catch (e) {
      print('Error saving settings to local storage: $e');
    }
  }

  /// Reset preferences to defaults (called upon sign-out / new account setup)
  Future<void> resetToDefaults() async {
    voiceFeedback = true;
    hapticFeedback = true;
    companionSharing = false;
    selectedContrastTheme = 'Default';
    selectedLanguage = 'English (US)';
    selectedVoicePersona = 'Aria (Calm)';
    selectedUnit = 'Metric';
    selectedMobilityAid = 'None (Hands-Free)';
    appearanceTheme = 'Default';
    accentColorIndex = 0;
    faceIdUnlock = false;
    shakeToUndo = true;
    speechNavigation = false;
    speechRate = 0.5;
    speechPitch = 0.5;
    homeScreenCards = ['buddy', 'easylens', 'faces', 'text', 'navigation', 'sos'];
    useLocalAI = true;
    showFloatingMascot = true;
    geminiApiKey = '';
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      print('Error clearing SharedPreferences: $e');
    }
  }
}
