import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import 'spotlight_tutorial_overlay.dart';

/// Full interactive walkthrough tutorial overlay with illuminated spotlights
/// over every single button across EasyLens (Dashboard cards, Navigation, EasyLens Camera, AppBar icons, Settings).
class InteractiveTutorialOverlay extends StatelessWidget {
  final VoidCallback onComplete;
  final ValueChanged<int>? onTabRequested;
  final ValueChanged<Widget>? onNavigateRequested;
  final VoidCallback? onPopRequested;

  final GlobalKey? buddyMascotKey;
  final GlobalKey? easylensScanKey;
  final GlobalKey? audioNavKey;
  final GlobalKey? sosEmergencyKey;
  final GlobalKey? settingsKey;
  final GlobalKey? notificationsKey;
  final GlobalKey? contactsKey;
  final GlobalKey? buddyCardKey;
  final GlobalKey? easylensCardKey;
  final GlobalKey? facesCardKey;
  final GlobalKey? textCardKey;
  final GlobalKey? navigationCardKey;
  final GlobalKey? sosCardKey;

  const InteractiveTutorialOverlay({
    super.key,
    required this.onComplete,
    this.onTabRequested,
    this.onNavigateRequested,
    this.onPopRequested,
    this.buddyMascotKey,
    this.easylensScanKey,
    this.audioNavKey,
    this.sosEmergencyKey,
    this.settingsKey,
    this.notificationsKey,
    this.contactsKey,
    this.buddyCardKey,
    this.easylensCardKey,
    this.facesCardKey,
    this.textCardKey,
    this.navigationCardKey,
    this.sosCardKey,
  });

  Future<void> _finishTutorial() async {
    TtsService().stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_tutorial', true);
    onPopRequested?.call();
    onComplete();
  }

  List<SpotlightStep> _buildSteps(bool isTagalog) {
    if (isTagalog) {
      return [
        SpotlightStep(
          targetKey: null,
          title: 'Maligayang Pagdating sa EasyLens!',
          description: 'Mag-tour tayo sa bawat button at tampok ng app na may illuminated spotlight at voice narration!',
          mascotAsset: 'assets/mascots/05_welcome.gif',
          actionText: 'Simulan ang Tour',
          targetTabIndex: 0,
        ),
        SpotlightStep(
          targetKey: buddyCardKey ?? buddyMascotKey,
          title: 'Kausapin si Buddy (AI Assistant)',
          description: 'I-tap para buksan ang iyong AI voice assistant! Magtanong ng kahit ano, humingi ng gabay sa daan, o mag-double tap ng mga card para sa instant na boses.',
          mascotAsset: 'assets/mascots/01_happy.gif',
          actionText: 'Susunod',
          targetPadding: const EdgeInsets.all(8),
          targetTabIndex: 0,
        ),
        SpotlightStep(
          targetKey: easylensCardKey ?? easylensScanKey,
          title: 'EasyLens: Real-Time Camera Scan',
          description: 'Ginagamit para sa real-time navigation sa mga harang, AI object detection sa paligid, paglalarawan ng tanawin (scenery), at face recognition!',
          mascotAsset: 'assets/mascots/03_loading.gif',
          actionText: 'Susunod',
          targetPadding: const EdgeInsets.all(8),
          targetTabIndex: 0,
        ),
        SpotlightStep(
          targetKey: facesCardKey,
          title: 'Magrehistro ng Mukha (Face ID)',
          description: 'Magrehistro ng mga mukha ng pamilya at kaibigan para makilala at maipahayag ni EasyLens ang kanilang mga pangalan sa real-time!',
          mascotAsset: 'assets/mascots/06_thinking.gif',
          actionText: 'Susunod',
          targetPadding: const EdgeInsets.all(8),
          targetTabIndex: 0,
        ),
        SpotlightStep(
          targetKey: textCardKey,
          title: 'Magbasa ng Teksto sa Paligid (OCR)',
          description: 'I-tapat ang camera sa mga sign board, dokumento, o sulat para awtomatikong basahin nang malakas ang teksto gamit ang OCR!',
          mascotAsset: 'assets/mascots/05_welcome.gif',
          actionText: 'Susunod',
          targetPadding: const EdgeInsets.all(8),
          targetTabIndex: 0,
        ),
        SpotlightStep(
          targetKey: audioNavKey ?? navigationCardKey,
          title: 'Boses na Nabigasyon sa Daan',
          description: 'Gamitin ang "Nav" tab para sa hands-free audio route guidance, paghahanap ng pupuntahan, at boses na direksyon habang naglalakad.',
          mascotAsset: 'assets/mascots/06_thinking.gif',
          actionText: 'Susunod',
          targetPadding: const EdgeInsets.all(8),
          targetTabIndex: 0,
        ),
        SpotlightStep(
          targetKey: sosCardKey ?? sosEmergencyKey,
          title: 'SOS Emergency: Mabilis na Saklolo',
          description: 'I-tap ang pulang SOS button para agad na magpadala ng alerto at lokasyon sa iyong mga emergency contact sa oras ng saklolo.',
          mascotAsset: 'assets/mascots/01_happy.gif',
          actionText: 'Susunod',
          targetPadding: const EdgeInsets.all(8),
          targetTabIndex: 0,
        ),
        SpotlightStep(
          targetKey: notificationsKey,
          title: 'Mga Alerto at Abiso sa Kaligtasan',
          description: 'Suriin ang mga babala sa masamang panahon, mga alerto sa panganib, at mga update sa system sa iyong notification icon.',
          mascotAsset: 'assets/mascots/05_welcome.gif',
          actionText: 'Susunod',
          targetPadding: const EdgeInsets.all(8),
          targetTabIndex: 0,
        ),
        SpotlightStep(
          targetKey: contactsKey,
          title: 'Mga Emergency Contact',
          description: 'Mag-imbak ng hanggang 3 pinagkakatiwalaang contact na makakatanggap ng iyong live na lokasyon tuwing mag-trigger ng SOS.',
          mascotAsset: 'assets/mascots/01_happy.gif',
          actionText: 'Susunod',
          targetPadding: const EdgeInsets.all(8),
          targetTabIndex: 0,
        ),
        SpotlightStep(
          targetKey: settingsKey,
          title: 'Mga Setting at Kontrol sa Boses',
          description: 'I-customize ang contrast theme, wika, boses na nabigasyon, at ulitin ang walkthrough na ito anumang oras sa Settings!',
          mascotAsset: 'assets/mascots/05_welcome.gif',
          actionText: 'Susunod',
          targetPadding: const EdgeInsets.all(8),
          targetTabIndex: 0,
        ),
        SpotlightStep(
          targetKey: null,
          title: 'Kumpleto na ang Iyong Walkthrough!',
          description: 'Nalaman mo na ang lahat ng gamit ng bawat button sa EasyLens! Handa ka nang maglakbay nang ligtas.',
          mascotAsset: 'assets/mascots/04_congratulations.gif',
          actionText: 'Tapusin ang Tour',
          targetTabIndex: 0,
        ),
      ];
    }

    return [
      SpotlightStep(
        targetKey: null,
        title: 'Welcome to EasyLens!',
        description: 'Let\'s take an interactive tour with illuminated spotlights over every single button and feature across your app!',
        mascotAsset: 'assets/mascots/05_welcome.gif',
        actionText: 'Start Tour',
        targetTabIndex: 0,
      ),
      SpotlightStep(
        targetKey: buddyCardKey ?? buddyMascotKey,
        title: 'Talk to Buddy (AI Assistant)',
        description: 'Tap to open your AI voice assistant! Ask Buddy anything, get navigation guidance, or double-tap cards for instant spoken feedback.',
        mascotAsset: 'assets/mascots/01_happy.gif',
        actionText: 'Next',
        targetPadding: const EdgeInsets.all(8),
        targetTabIndex: 0,
      ),
      SpotlightStep(
        targetKey: easylensCardKey ?? easylensScanKey,
        title: 'EasyLens: Real-Time Camera Scan',
        description: 'Used for real-time obstacle navigation, AI object detection, scenery description, and face recognition!',
        mascotAsset: 'assets/mascots/03_loading.gif',
        actionText: 'Next',
        targetPadding: const EdgeInsets.all(8),
        targetTabIndex: 0,
      ),
      SpotlightStep(
        targetKey: facesCardKey,
        title: 'Register Face ID & Recognition',
        description: 'Register faces of family, friends, and caregivers so EasyLens can recognize and announce them by name in real-time!',
        mascotAsset: 'assets/mascots/06_thinking.gif',
        actionText: 'Next',
        targetPadding: const EdgeInsets.all(8),
        targetTabIndex: 0,
      ),
      SpotlightStep(
        targetKey: textCardKey,
        title: 'Nearby Text (OCR Reader)',
        description: 'Point your camera at signboards, documents, or labels to read text out loud automatically with high-accuracy OCR!',
        mascotAsset: 'assets/mascots/05_welcome.gif',
        actionText: 'Next',
        targetPadding: const EdgeInsets.all(8),
        targetTabIndex: 0,
      ),
      SpotlightStep(
        targetKey: audioNavKey ?? navigationCardKey,
        title: 'Hands-Free Audio Navigation',
        description: 'Access the "Nav" tab for turn-by-turn voice route guidance, destination search, and real-time audio orientation while traveling.',
        mascotAsset: 'assets/mascots/06_thinking.gif',
        actionText: 'Next',
        targetPadding: const EdgeInsets.all(8),
        targetTabIndex: 0,
      ),
      SpotlightStep(
        targetKey: sosCardKey ?? sosEmergencyKey,
        title: 'SOS Emergency Rescue',
        description: 'Triggers immediate emergency SMS broadcasts and location coordinates to your designated contacts for rapid help!',
        mascotAsset: 'assets/mascots/01_happy.gif',
        actionText: 'Next',
        targetPadding: const EdgeInsets.all(8),
        targetTabIndex: 0,
      ),
      SpotlightStep(
        targetKey: notificationsKey,
        title: 'Notifications & Safety Alerts',
        description: 'Check unread hazard alerts, weather warnings, and system updates from your top bar notification icon.',
        mascotAsset: 'assets/mascots/05_welcome.gif',
        actionText: 'Next',
        targetPadding: const EdgeInsets.all(8),
        targetTabIndex: 0,
      ),
      SpotlightStep(
        targetKey: contactsKey,
        title: 'Emergency Contacts Manager',
        description: 'Manage up to 3 trusted emergency contacts who will receive your live GPS location during emergency SOS triggers.',
        mascotAsset: 'assets/mascots/01_happy.gif',
        actionText: 'Next',
        targetPadding: const EdgeInsets.all(8),
        targetTabIndex: 0,
      ),
      SpotlightStep(
        targetKey: settingsKey,
        title: 'Settings & Voice Controls',
        description: 'Customize high-contrast visual themes, Tagalog/English language, speech navigation, and replay this walkthrough anytime!',
        mascotAsset: 'assets/mascots/05_welcome.gif',
        actionText: 'Next',
        targetPadding: const EdgeInsets.all(8),
        targetTabIndex: 0,
      ),
      SpotlightStep(
        targetKey: null,
        title: 'You\'re All Set!',
        description: 'You\'ve learned every single button and feature across EasyLens! Enjoy your safe, AI-guided journeys.',
        mascotAsset: 'assets/mascots/04_congratulations.gif',
        actionText: 'Finish Tour',
        targetTabIndex: 0,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();
    final isTagalog = settings.selectedLanguage.toLowerCase().contains('tagalog') ||
        settings.selectedLanguage.toLowerCase().contains('filipino');
    final steps = _buildSteps(isTagalog);

    return SpotlightTutorialOverlay(
      steps: steps,
      onComplete: _finishTutorial,
      onTabRequested: onTabRequested,
    );
  }
}
