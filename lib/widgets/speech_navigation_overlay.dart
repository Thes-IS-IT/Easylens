import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../services/settings_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/firebase_service.dart';
import '../utils/app_route.dart';
import '../main.dart'; // access navigatorKey S01

// Screen routes S01
import '../screens/settings/settings_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/contacts/contacts_screen.dart';
import '../screens/emergency/emergency_screen.dart';
import '../screens/settings/help_guide_screen.dart';
import '../screens/settings/change_password_screen.dart';
import '../screens/settings/units_screen.dart';
import '../screens/settings/customize_home_screen.dart';
import '../screens/face_registration/face_registration_screen.dart';
import '../screens/settings/profile_details_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/image_labeling/image_labeling_screen.dart';
import '../screens/hardware/hardware_screen.dart';
import '../screens/devices/devices_screen.dart';
import '../services/rag_service.dart';
import '../services/active_navigation_service.dart';

class SpeechNavigationNotifier {
  static final ValueNotifier<int?> tabChangeNotifier = ValueNotifier<int?>(null);
  static final ValueNotifier<String?> searchPlaceNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<int?> selectResultNotifier = ValueNotifier<int?>(null);
  static final ValueNotifier<Map<String, dynamic>?> confirmPlaceNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  static final ValueNotifier<bool?> stopRouteNotifier = ValueNotifier<bool?>(null);
  static final ValueNotifier<bool?> openBuddyNotifier = ValueNotifier<bool?>(null);
  static final ValueNotifier<String?> hardwareControlNotifier = ValueNotifier<String?>(null);
  static List<Map<String, dynamic>> activeSearchResults = [];

  static void stopRouteNavigation() {
    stopRouteNotifier.value = true;
    Future.delayed(const Duration(milliseconds: 50), () {
      stopRouteNotifier.value = null;
    });
  }
  
  static void changeTab(int index) {
    tabChangeNotifier.value = index;
    Future.delayed(const Duration(milliseconds: 50), () {
      tabChangeNotifier.value = null;
    });
  }

  static void searchPlace(String query) {
    searchPlaceNotifier.value = query;
    Future.delayed(const Duration(milliseconds: 50), () {
      searchPlaceNotifier.value = null;
    });
  }

  static void selectResult(int index) {
    selectResultNotifier.value = index;
    Future.delayed(const Duration(milliseconds: 50), () {
      selectResultNotifier.value = null;
    });
  }

  static void confirmAndStartNavigation(Map<String, dynamic> place) {
    confirmPlaceNotifier.value = place;
    Future.delayed(const Duration(milliseconds: 50), () {
      confirmPlaceNotifier.value = null;
    });
  }

  static void triggerHardwareControl(String control) {
    hardwareControlNotifier.value = control;
    Future.delayed(const Duration(milliseconds: 50), () {
      hardwareControlNotifier.value = null;
    });
  }
}

class SpeechNavigationOverlay extends StatefulWidget {
  final Widget child;

  const SpeechNavigationOverlay({super.key, required this.child});

  @override
  State<SpeechNavigationOverlay> createState() => _SpeechNavigationOverlayState();
}

class _SpeechNavigationOverlayState extends State<SpeechNavigationOverlay> {
  bool _isListening = false;
  String _lastRecognized = "";
  Timer? _clearBannerTimer;

  bool _isLoopActive = false;
  Timer? _silenceTimer;
  double? _btnLeft;
  double? _btnTop;
  bool _isDragging = false;
  int _pendingSearchFlow = 0;
  Map<String, dynamic>? _pendingPlaceToConfirm;

  bool _isInitialGreeting = false;

  @override
  void initState() {
    super.initState();
    TtsService().isSpeakingNotifier.addListener(_onTtsSpeakingChanged);
  }

  void _onTtsSpeakingChanged() {
    if (!mounted || !_isLoopActive) return;

    if (TtsService().isSpeaking) {
      // TTS announcement started - pause STT immediately so mic doesn't pick up speaker output
      if (_isListening) {
        SttService().stopListening((_) {});
        setState(() {
          _isListening = false;
        });
      }
    } else {
      // TTS announcement completed & acoustic decay period passed
      // Resume STT loop if speech navigation is active and not currently processing
      if (mounted && _isLoopActive && !_isProcessing) {
        _runSpeechNavigationLoop();
      }
    }
  }

  Future<void> _pushAndRecord(Widget screen, String description) async {
    final prev = RagService.currentScreen;
    RagService.recordNavigation(description, actionDescription: "Speech command navigated to $description");
    await navigatorKey.currentState?.push(AppRoute.to(screen));
    RagService.recordNavigation(prev, actionDescription: "Returned from $description via speech back action");
  }

  @override
  void dispose() {
    TtsService().isSpeakingNotifier.removeListener(_onTtsSpeakingChanged);
    _silenceTimer?.cancel();
    _clearBannerTimer?.cancel();
    super.dispose();
  }

  void _toggleSpeechNavigation() {
    if (_isLoopActive) {
      _stopLoop();
    } else {
      _startLoop();
    }
  }

  bool _isProcessing = false;

  bool _isSelfEcho(String text) {
    if (TtsService().isSpeaking) return true;
    if (TtsService().isSelfEcho(text)) return true;

    final clean = text.toLowerCase().trim();
    if (clean.isEmpty) return true;
    final selfPhrases = [
      "speech navigation",
      "naka-enable",
      "where would you like to navigate",
      "saan mo gustong pumunta",
      "say 1 to search",
      "sabihin ang 1",
      "executing command",
      "isinasagawa ang utos",
      "listening for command",
      "nakinig para sa utos",
      "navigating to",
      "papunta sa",
      "opening",
      "binubuksan"
    ];
    for (final phrase in selfPhrases) {
      if (clean.contains(phrase)) return true;
    }
    return false;
  }

  void _startLoop() async {
    // Explicitly mute/stop mic while initial greeting prompt is spoken S01
    await SttService().stopListening((_) {});
    setState(() {
      _isLoopActive = true;
      _isListening = false;
      _lastRecognized = "";
      _isInitialGreeting = true;
      _isProcessing = false;
    });

    final lang = SettingsService().selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    final startPrompt = isFilipino 
        ? "Naka-enable ang Speech Navigation. Saan mo gustong pumunta o kung anong i-navigate?" 
        : "Speech Navigation enabled. Where would you like to navigate?";
    
    setState(() {
      _lastRecognized = startPrompt;
    });

    await TtsService().speakAwait(startPrompt);

    // Mute decay delay (500ms) to ensure speaker sound drops completely before mic unmutes
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted && _isLoopActive) {
      setState(() {
        _isInitialGreeting = false;
        _lastRecognized = "";
      });
      _runSpeechNavigationLoop();
    }
  }

  void _stopLoop() async {
    _silenceTimer?.cancel();
    await SttService().stopListening((_) {});
    setState(() {
      _isLoopActive = false;
      _isListening = false;
      _lastRecognized = "";
      _isProcessing = false;
    });
  }

  void _runSpeechNavigationLoop() async {
    if (!mounted || !_isLoopActive || _isProcessing || TtsService().isSpeaking) return;

    try {
      // Guarantee previous listening handlers are stopped before restarting mic
      await SttService().stopListening((_) {});
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted || !_isLoopActive || _isProcessing || TtsService().isSpeaking) return;

      setState(() {
        _isListening = true;
        _lastRecognized = "";
      });

      await SttService().startListening(
        onListeningStateChanged: (listening) {
          if (mounted && _isLoopActive) {
            setState(() {
              _isListening = listening;
            });
          }
        },
        onResult: (text, isFinal) {
          if (mounted && _isLoopActive && !_isProcessing && !TtsService().isSpeaking) {
            if (_isSelfEcho(text)) return;

            setState(() {
              _lastRecognized = text;
            });

            // Reset silence timer on every recognized word chunk S01
            _silenceTimer?.cancel();
            _silenceTimer = Timer(const Duration(milliseconds: 1500), () {
              _processAndSpeakCurrentText();
            });
          }
        },
      );
    } catch (e) {
      print("STT restart error: $e");
    }
  }

  void _processAndSpeakCurrentText() async {
    _silenceTimer?.cancel();
    if (!mounted || !_isLoopActive || _isProcessing) return;

    _isProcessing = true;

    // Dynamically mute microphone completely so TTS audio playback is not registered by STT
    await SttService().stopListening((_) {});
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }

    final text = _lastRecognized.trim();
    if (text.isEmpty || _isSelfEcho(text)) {
      _isProcessing = false;
      _lastRecognized = "";
      // Quietly restart microphone listening on silence without repeating audio prompts
      if (mounted && _isLoopActive) {
        _runSpeechNavigationLoop();
      }
      return;
    }

    // Filter background/registered noise (ignore speech that lacks core command keywords)
    if (!_containsAnyKeyword(text)) {
      _isProcessing = false;
      setState(() {
        _lastRecognized = "";
      });
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted && _isLoopActive) {
        _runSpeechNavigationLoop();
      }
      return;
    }

    // Process the command and get response text
    final response = await _processCommand(text);

    if (mounted && _isLoopActive && response.isNotEmpty) {
      // Mute STT completely while assistant reads instruction
      await SttService().stopListening((_) {});

      // Speak direct concise confirmation
      await TtsService().speakAwait(response);

      // Pause 1000ms after TTS finishes to allow speaker echo to decay before unmuting mic for user turn
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    if (mounted) {
      setState(() {
        _lastRecognized = "";
      });
    }
    _isProcessing = false;

    if (mounted && _isLoopActive) {
      if (!TtsService().isSpeaking) {
        _runSpeechNavigationLoop();
      }
    }
  }

  Future<String> _processCommand(String text) async {
    final cleanText = text.trim().toLowerCase();
    if (cleanText.isEmpty) return "";

    final lang = SettingsService().selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');

    // Active Route Guidance Stop Command (Stops destination route guidance, NOT Speech Navigation overlay)
    final isRouteActive = ActiveNavigationService().isNavigating ||
        _pendingSearchFlow != 0 ||
        _pendingPlaceToConfirm != null;

    final routeStopKeywords = [
      "stop navigation", "stop route", "cancel navigation", "stop guidance", "stop walking",
      "hinto ang nabigasyon", "hinto ang ruta", "kanselahin ang nabigasyon", "tumigil sa paglalakad"
    ];

    if (isRouteActive) {
      if (routeStopKeywords.any((k) => cleanText.contains(k)) ||
          cleanText == "stop" ||
          cleanText == "hinto" ||
          cleanText == "cancel" ||
          cleanText == "kanselahin") {
        ActiveNavigationService().stopNavigation();
        SpeechNavigationNotifier.stopRouteNavigation();
        setState(() {
          _pendingSearchFlow = 0;
          _pendingPlaceToConfirm = null;
        });
        return isFilipino 
            ? "Nakahinto ang gabay sa ruta. Saan mo gustong pumunta?" 
            : "Route guidance stopped. Where would you like to navigate?";
      }
    }

    // Voice Overlay Pause / Stop Command (Only if explicitly asking to turn off speech overlay)
    if (cleanText.contains("stop listening") ||
        cleanText.contains("stop speech") ||
        cleanText.contains("turn off voice") ||
        cleanText.contains("tumahimik") ||
        cleanText.contains("pause voice")) {
      _stopLoop();
      return isFilipino ? "Naka-pause ang Speech Navigation." : "Speech Navigation paused.";
    }

    // ── STEP 3: AWAITING SEARCH QUERY ──
    if (_pendingSearchFlow == 3) {
      if (cleanText.contains("cancel") || cleanText.contains("hinto") || cleanText.contains("stop") || cleanText.contains("hindi") || cleanText.contains("no") || cleanText.contains("ayaw")) {
        setState(() {
          _pendingSearchFlow = 0;
        });
        return isFilipino ? "Kinansela ang paghahanap." : "Search cancelled.";
      }

      final searchQuery = cleanText;
      SpeechNavigationNotifier.changeTab(1);
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      SpeechNavigationNotifier.searchPlace(searchQuery);

      await Future.delayed(const Duration(milliseconds: 1000));
      final results = SpeechNavigationNotifier.activeSearchResults;

      if (results.isEmpty) {
        setState(() {
          _pendingSearchFlow = 0;
        });
        return isFilipino 
            ? "Paumanhin, walang nahanap na lugar para sa '$searchQuery'." 
            : "Sorry, no places found for '$searchQuery'.";
      }

      if (results.length == 1) {
        final place = results[0];
        setState(() {
          _pendingSearchFlow = 2;
          _pendingPlaceToConfirm = place;
        });
        SpeechNavigationNotifier.selectResult(0);
        final placeName = place['name'];
        return isFilipino 
            ? "Nahanap ang $placeName. Sabihin ang 'Oo', 'Kumpirmahin', o 'Sige' para simulan ang ruta, o 'Hindi' para kanselahin." 
            : "Found $placeName. Say 'Yes', 'Confirm', or 'Search' to start route guidance, or 'No' to cancel.";
      }

      setState(() {
        _pendingSearchFlow = 1;
      });

      final count = results.length > 5 ? 5 : results.length;
      final sb = StringBuffer();
      sb.write(isFilipino 
          ? "Aling lokasyon ang pipiliin mo? " 
          : "Which location will you choose? ");
      for (int i = 0; i < count; i++) {
        final distStr = results[i]['dist'] ?? '';
        sb.write(isFilipino
            ? "Numero ${i + 1}: ${results[i]['name']}${distStr.isNotEmpty ? ', may layong $distStr' : ''}. "
            : "Number ${i + 1}: ${results[i]['name']}${distStr.isNotEmpty ? ', $distStr away' : ''}. ");
      }
      sb.write(isFilipino 
          ? "Mangyaring pumili ng numero mula 1 hanggang $count o sabihin ang 'Kanselahin'." 
          : "Kindly pick a number from 1 to $count or say 'Cancel'.");
      return sb.toString();
    }

    // ── SEARCH RESULTS SELECTION FLOW S01 ──
    if (_pendingSearchFlow == 1) {
      final results = SpeechNavigationNotifier.activeSearchResults;
      
      // Check for cancel command
      if (cleanText.contains("cancel") || cleanText.contains("i-cancel") || cleanText.contains("hinto") || cleanText.contains("stop") || cleanText.contains("hindi") || cleanText.contains("no")) {
        setState(() {
          _pendingSearchFlow = 0;
          _pendingPlaceToConfirm = null;
        });
        return isFilipino ? "Kinansela ang paghahanap" : "Search cancelled";
      }

      int selectedIndex = -1;
      
      // Check word number matches S01 (Supports up to 10)
      if (cleanText.contains("1") || cleanText.contains("one") || cleanText.contains("first") || cleanText.contains("una")) {
        selectedIndex = 0;
      } else if (cleanText.contains("2") || cleanText.contains("two") || cleanText.contains("second") || cleanText.contains("pangalawa")) {
        selectedIndex = 1;
      } else if (cleanText.contains("3") || cleanText.contains("three") || cleanText.contains("third") || cleanText.contains("pangatlo")) {
        selectedIndex = 2;
      } else if (cleanText.contains("4") || cleanText.contains("four") || cleanText.contains("fourth") || cleanText.contains("pang-apat")) {
        selectedIndex = 3;
      } else if (cleanText.contains("5") || cleanText.contains("five") || cleanText.contains("fifth") || cleanText.contains("panlima")) {
        selectedIndex = 4;
      } else if (cleanText.contains("6") || cleanText.contains("six") || cleanText.contains("sixth") || cleanText.contains("pang-anim")) {
        selectedIndex = 5;
      } else if (cleanText.contains("7") || cleanText.contains("seven") || cleanText.contains("seventh") || cleanText.contains("pampito")) {
        selectedIndex = 6;
      } else if (cleanText.contains("8") || cleanText.contains("eight") || cleanText.contains("eighth") || cleanText.contains("pangwalo")) {
        selectedIndex = 7;
      } else if (cleanText.contains("9") || cleanText.contains("nine") || cleanText.contains("ninth") || cleanText.contains("pangsiyam")) {
        selectedIndex = 8;
      } else if (cleanText.contains("10") || cleanText.contains("ten") || cleanText.contains("tenth") || cleanText.contains("pangsampu")) {
        selectedIndex = 9;
      } else {
        // Match specific place name
        for (int i = 0; i < results.length && i < 10; i++) {
          final name = (results[i]['name'] as String).toLowerCase();
          if (cleanText.contains(name) || name.contains(cleanText)) {
            selectedIndex = i;
            break;
          }
        }
      }
      
      if (selectedIndex >= 0 && selectedIndex < results.length) {
        final place = results[selectedIndex];
        setState(() {
          _pendingSearchFlow = 2; // Move to confirmation step
          _pendingPlaceToConfirm = place;
        });
        SpeechNavigationNotifier.selectResult(selectedIndex);
        final placeName = place['name'];
        return isFilipino 
            ? "Nahanap ang $placeName. Sabihin ang 'Oo', 'Kumpirmahin', o 'Sige' para simulan ang ruta, o 'Hindi' para kanselahin." 
            : "Found $placeName. Say 'Yes', 'Confirm', or 'Search' to start route guidance, or 'No' to cancel.";
      } else {
        return isFilipino 
            ? "Hindi nakuha ang numero o lugar. Mangyaring sabihin ang numero o kanselahin." 
            : "I didn't catch that number or place. Please say the number or cancel.";
      }
    }

    // ── STEP 2: NAVIGATION CONFIRMATION STEP ──
    if (_pendingSearchFlow == 2 && _pendingPlaceToConfirm != null) {
      final confirmKeywords = [
        'yes', 'confirm', 'search', 'find me', 'take me', 'go', 'start', 'proceed',
        'oo', 'opopo', 'opo', 'kumpirmahin', 'sige', 'pumunta', 'ituloy'
      ];
      final cancelKeywords = [
        'no', 'cancel', 'stop', 'different', 'change', 'hindi', 'kanselahin', 'ayaw', 'baguhin'
      ];

      if (confirmKeywords.any((k) => cleanText.contains(k))) {
        final place = _pendingPlaceToConfirm!;
        setState(() {
          _pendingSearchFlow = 0;
          _pendingPlaceToConfirm = null;
        });
        SpeechNavigationNotifier.confirmAndStartNavigation(place);
        final name = place['name'];
        return isFilipino 
            ? "Sinisimulan ang ruta patungo sa $name. Mag-ingat sa paglalakad." 
            : "Starting route guidance to $name. Have a safe walk.";
      } else if (cancelKeywords.any((k) => cleanText.contains(k))) {
        setState(() {
          _pendingSearchFlow = 0;
          _pendingPlaceToConfirm = null;
        });
        return isFilipino 
            ? "Kinansela ang nabigasyon. Anong lugar ang nais mong hanapin?" 
            : "Navigation cancelled. What destination would you like to find?";
      } else {
        return isFilipino 
            ? "Sabihin ang 'Oo' o 'Kumpirmahin' para mag-navigate sa ${_pendingPlaceToConfirm!['name']}, o 'Hindi' para kanselahin." 
            : "Say 'Yes' or 'Confirm' to navigate to ${_pendingPlaceToConfirm!['name']}, or 'No' to cancel.";
      }
    }

    // ── INTERACTIVE VOICE MENU OPTIONS 1-5 ──
    if (cleanText == "1" || cleanText.startsWith("1 ") || cleanText.contains("say 1") || cleanText.contains("option 1") || cleanText.contains("numero 1") || cleanText == "one" || cleanText == "una" || cleanText == "search" || cleanText == "maghanap" || cleanText == "hanap") {
      setState(() {
        _pendingSearchFlow = 3;
      });
      return isFilipino
          ? "Anong lugar ang nais mong hanapin?"
          : "What destination would you like to search for?";
    }

    if (cleanText == "2" || cleanText.startsWith("2 ") || cleanText.contains("say 2") || cleanText.contains("option 2") || cleanText.contains("numero 2") || cleanText == "two" || cleanText == "pangalawa") {
      SpeechNavigationNotifier.changeTab(0);
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      return isFilipino ? "Papunta sa Home" : "Navigating to Home";
    }

    if (cleanText == "3" || cleanText.startsWith("3 ") || cleanText.contains("say 3") || cleanText.contains("option 3") || cleanText.contains("numero 3") || cleanText == "three" || cleanText == "pangatlo") {
      SpeechNavigationNotifier.changeTab(2);
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      return isFilipino ? "Papunta sa EasyLens Camera" : "Navigating to EasyLens Camera";
    }

    if (cleanText == "4" || cleanText.startsWith("4 ") || cleanText.contains("say 4") || cleanText.contains("option 4") || cleanText.contains("numero 4") || cleanText == "four" || cleanText == "pang-apat") {
      _pushAndRecord(const SettingsScreen(), "Settings");
      return isFilipino ? "Binubuksan ang Settings" : "Opening Settings";
    }

    if (cleanText == "5" || cleanText.startsWith("5 ") || cleanText.contains("say 5") || cleanText.contains("option 5") || cleanText.contains("numero 5") || cleanText == "five" || cleanText == "panlima" || cleanText.contains("stop") || cleanText.contains("hinto") || cleanText.contains("tumahimik")) {
      _stopLoop();
      return isFilipino ? "Nakahinto ang Speech Navigation." : "Speech Navigation stopped.";
    }

    // ── 5. DIRECT APP SCREEN NAVIGATION COMMANDS (CHECKED FIRST BEFORE MAP SEARCH) ──

    // 1. Card 1: Talk to Buddy (Local AI)
    if (cleanText.contains("talk to buddy") ||
        cleanText.contains("talk to buddy local ai") ||
        cleanText.contains("kausapin si buddy") ||
        cleanText.contains("kausap si buddy") ||
        cleanText.contains("makausap si buddy") ||
        cleanText.contains("mag-chat kay buddy") ||
        cleanText.contains("usap kay buddy") ||
        cleanText.contains("buddy") ||
        cleanText.contains("chat") ||
        cleanText.contains("kausap")) {
      SpeechNavigationNotifier.openBuddyNotifier.value = true;
      Future.delayed(const Duration(milliseconds: 50), () {
        SpeechNavigationNotifier.openBuddyNotifier.value = null;
      });
      return isFilipino ? "Binubuksan ang chatbot ni Buddy" : "Opening Buddy chatbot";
    }

    // 2. Card 2: EasyLens Camera
    if (cleanText.contains("easylens") ||
        cleanText.contains("easy lens") ||
        cleanText.contains("camera") ||
        cleanText.contains("kamera") ||
        cleanText.contains("kamara") ||
        cleanText.contains("kumuha ng larawan")) {
      SpeechNavigationNotifier.changeTab(2);
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      return isFilipino ? "Binubuksan ang camera" : "Navigating to EasyLens camera";
    }

    // 3. Card 3: Register Face
    if (cleanText.contains("register face") ||
        cleanText.contains("face registration") ||
        cleanText.contains("registered faces") ||
        cleanText.contains("magrehistro ng mukha") ||
        cleanText.contains("rehistro ng mukha") ||
        cleanText.contains("iparehistro ang mukha") ||
        cleanText.contains("pagrehistro ng mukha") ||
        cleanText.contains("magparehistro ng mukha") ||
        cleanText.contains("mga mukha") ||
        cleanText.contains("mukha")) {
      _pushAndRecord(const FaceRegistrationScreen(), "Face Registration");
      return isFilipino ? "Binubuksan ang pagrehistro ng mukha" : "Opening face registration";
    }

    // 4. Card 4: Nearby Text (OCR / Text Scanner)
    if (cleanText.contains("nearby text") ||
        cleanText.contains("kalapit na teksto") ||
        cleanText.contains("magbasa ng teksto") ||
        cleanText.contains("magbasa ng sulat") ||
        cleanText.contains("basahin ang teksto") ||
        cleanText.contains("basahin ang sulat") ||
        cleanText.contains("basa ng teksto") ||
        cleanText.contains("text scanner") ||
        cleanText.contains("text") ||
        cleanText.contains("teksto") ||
        cleanText.contains("ocr") ||
        cleanText.contains("read text") ||
        cleanText.contains("basa")) {
      _pushAndRecord(ImageLabelingScreen(
        onTabSelected: (index) {
          navigatorKey.currentState?.pop();
          SpeechNavigationNotifier.changeTab(index);
        },
      ), "Text Scanner");
      return isFilipino ? "Binubuksan ang text scanner" : "Opening text scanner";
    }

    // 5. Card 5: Audio Navigation (Maps / GPS)
    if (cleanText.contains("audio navigation") ||
        cleanText.contains("audio na nabigasyon") ||
        cleanText.contains("nabigasyon sa boses") ||
        cleanText.contains("mapa ng nabigasyon") ||
        cleanText.contains("pumunta sa mapa") ||
        cleanText.contains("mag-navigate") ||
        cleanText.contains("navigation") ||
        cleanText.contains("map") ||
        cleanText.contains("maps") ||
        cleanText.contains("mapa") ||
        cleanText.contains("nabigasyon") ||
        RegExp(r'\b(nav|nab)\b').hasMatch(cleanText)) {
      SpeechNavigationNotifier.changeTab(1);
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      return isFilipino ? "Papunta sa mapa" : "Navigating to map";
    }

    // 6. Card 6: SOS Emergency
    if (cleanText.contains("sos emergency") ||
        cleanText.contains("tulong emergency") ||
        cleanText.contains("tawag emergency") ||
        cleanText.contains("emergency") ||
        cleanText.contains("sos") ||
        cleanText.contains("saklolo")) {
      _pushAndRecord(const EmergencyScreen(), "Emergency SOS");
      return isFilipino ? "Binubuksan ang emergency" : "Navigating to emergency";
    }

    // 7. Settings & Preferences
    if (cleanText.contains("settings") ||
        cleanText.contains("setting") ||
        cleanText.contains("preference") ||
        cleanText.contains("preferensya") ||
        cleanText.contains("mga setting") ||
        cleanText.contains("mga kaayusan") ||
        cleanText.contains("buksan ang setting")) {
      _pushAndRecord(const SettingsScreen(), "Settings");
      return isFilipino ? "Binubuksan ang mga setting" : "Navigating to settings";
    }

    // 8. Devices & Glasses / Hardware Settings
    if (cleanText.contains("device") ||
        cleanText.contains("devices") ||
        cleanText.contains("glasses") ||
        cleanText.contains("mga aparato") ||
        cleanText.contains("aparato") ||
        cleanText.contains("salamin") ||
        cleanText.contains("mga salamin") ||
        cleanText.contains("hardware screen")) {
      _pushAndRecord(const DevicesScreen(), "Glasses Settings");
      return isFilipino ? "Binubuksan ang screen ng salamin" : "Navigating to devices screen";
    }

    // 9. Profile Details
    if (cleanText.contains("profile") ||
        cleanText.contains("account details") ||
        cleanText.contains("detalye ng aking profile") ||
        cleanText.contains("detalye ng profile") ||
        cleanText.contains("aking profile")) {
      _pushAndRecord(const ProfileDetailsScreen(), "Profile Details");
      return isFilipino ? "Binubuksan ang profile" : "Opening profile details";
    }

    // 10. Change Password & Security
    if (cleanText.contains("password") ||
        cleanText.contains("change password") ||
        cleanText.contains("palitan ang password") ||
        cleanText.contains("baguhin ang password") ||
        cleanText.contains("lihim na salita") ||
        cleanText.contains("security")) {
      _pushAndRecord(const ChangePasswordScreen(), "Change Password");
      return isFilipino ? "Binubuksan ang palitan ng password" : "Opening change password";
    }

    // 11. Units / Measurement
    if (cleanText.contains("units") ||
        cleanText.contains("unit") ||
        cleanText.contains("mga yunit") ||
        cleanText.contains("yunit ng pagsukat") ||
        cleanText.contains("yunit") ||
        cleanText.contains("measurement")) {
      _pushAndRecord(const UnitsScreen(), "Units Settings");
      return isFilipino ? "Binubuksan ang mga yunit" : "Opening units setting";
    }

    // 12. Customize Home Screen
    if (cleanText.contains("customize home") ||
        cleanText.contains("customize") ||
        cleanText.contains("isaayos ang home screen") ||
        cleanText.contains("i-customize ang home") ||
        cleanText.contains("kaayusan ng home") ||
        cleanText.contains("home customizer") ||
        cleanText.contains("isaayos ang home")) {
      _pushAndRecord(const CustomizeHomeScreen(), "Customize Home Screen");
      return isFilipino ? "Inaayos ang home screen" : "Opening home screen customizer";
    }

    // 13. Help & User Guide
    if (cleanText.contains("help guide") ||
        cleanText.contains("help") ||
        cleanText.contains("user guide") ||
        cleanText.contains("gabay sa tulong") ||
        cleanText.contains("paano gamitin") ||
        cleanText.contains("gabay") ||
        cleanText.contains("tulong")) {
      _pushAndRecord(const HelpGuideScreen(), "Help Guide");
      return isFilipino ? "Binubuksan ang gabay sa tulong" : "Opening help guide";
    }

    // 14. Notifications
    if (cleanText.contains("notifications") ||
        cleanText.contains("notification") ||
        cleanText.contains("mga abiso") ||
        cleanText.contains("abiso") ||
        cleanText.contains("patalastas")) {
      _pushAndRecord(const NotificationsScreen(), "Notifications");
      return isFilipino ? "Binubuksan ang mga abiso" : "Navigating to notifications";
    }

    // 15. Contacts
    if (cleanText.contains("contacts") ||
        cleanText.contains("contact") ||
        cleanText.contains("mga kontak") ||
        cleanText.contains("kontak")) {
      _pushAndRecord(const ContactsScreen(), "Contacts");
      return isFilipino ? "Binubuksan ang mga contact" : "Navigating to contacts";
    }

    // 16. Dashboard / Home Tab
    if (cleanText.contains("home") ||
        cleanText.contains("dashboard") ||
        cleanText.contains("bahay") ||
        cleanText.contains("umpisa") ||
        cleanText.contains("simula")) {
      SpeechNavigationNotifier.changeTab(0);
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      return isFilipino ? "Papunta sa dashboard" : "Navigating to dashboard";
    }

    // 17. Object Detector
    if (cleanText.contains("object detector") ||
        cleanText.contains("object detection") ||
        cleanText.contains("pang-amoy ng bagay") ||
        cleanText.contains("mga bagay") ||
        cleanText.contains("bagay")) {
      _pushAndRecord(const HardwareScreen(initialStep: 4), "Object Detector");
      return isFilipino ? "Binubuksan ang object detector" : "Opening object detector";
    }

    // 18. Go Back
    if (cleanText.contains("go back") ||
        cleanText.contains("back") ||
        cleanText.contains("bumalik sa nakaraan") ||
        cleanText.contains("bumalik") ||
        cleanText.contains("pabalik") ||
        cleanText.contains("balik")) {
      navigatorKey.currentState?.pop();
      return isFilipino ? "Bumabalik" : "Going back";
    }

    // 19. Logout
    if (cleanText.contains("logout") ||
        cleanText.contains("log out") ||
        cleanText.contains("umalis sa account") ||
        cleanText.contains("mag-logout") ||
        cleanText.contains("umalis")) {
      await FirebaseService().signOut();
      navigatorKey.currentState?.pushAndRemoveUntil(
        AppRoute.to(const OnboardingScreen()),
        (route) => false,
      );
      return isFilipino ? "Umalis sa account" : "Logging out";
    }

    // 20. Hardware Controls (click scenery, faces, bluetooth, audio, wifi, etc.)
    final hasClickPrefix = cleanText.startsWith("click ") || cleanText.startsWith("pindutin ");
    final target = hasClickPrefix 
        ? cleanText.replaceAll("click ", "").replaceAll("pindutin ", "").trim() 
        : cleanText;
    
    if (target.contains("scenery") || target.contains("tanawin")) {
      SpeechNavigationNotifier.triggerHardwareControl("scenery");
      return isFilipino ? "Binubuksan ang scenery mode" : "Switching to scenery mode";
    }
    if (target.contains("face recognition") || target.contains("pagkilala sa mukha")) {
      SpeechNavigationNotifier.triggerHardwareControl("faces");
      return isFilipino ? "Binubuksan ang face recognition" : "Switching to face recognition mode";
    }
    if (target.contains("navigation mode") || target.contains("warnings") || target.contains("babala")) {
      SpeechNavigationNotifier.triggerHardwareControl("navigation");
      return isFilipino ? "Binubuksan ang mga babala sa nabigasyon" : "Switching to navigation mode";
    }
    if (target.contains("bluetooth") || target.contains("koneksyon")) {
      SpeechNavigationNotifier.triggerHardwareControl("bluetooth");
      return isFilipino ? "Binabago ang koneksyon ng bluetooth" : "Toggling bluetooth connection";
    }
    if (target.contains("gemini") || target.contains("online ai")) {
      SpeechNavigationNotifier.triggerHardwareControl("gemini");
      return isFilipino ? "Binabago ang katayuan ng Gemini AI" : "Toggling Gemini AI";
    }
    if (target.contains("offline ai")) {
      SpeechNavigationNotifier.triggerHardwareControl("local_ai");
      return isFilipino ? "Binabago ang katayuan ng Local AI" : "Toggling Local AI";
    }
    if (target.contains("speaker")) {
      SpeechNavigationNotifier.triggerHardwareControl("audio");
      return isFilipino ? "Binabago ang audio output" : "Toggling audio output";
    }
    if (target.contains("network") || target.contains("wifi")) {
      SpeechNavigationNotifier.triggerHardwareControl("network");
      return isFilipino ? "Binabago ang katayuan ng internet" : "Toggling network connection";
    }
    if (target.contains("lock mode") || target.contains("screen lock") || target.contains("i-lock")) {
      SpeechNavigationNotifier.triggerHardwareControl("lock");
      return isFilipino ? "Binabago ang lock mode" : "Toggling lock mode";
    }

    // ── 6. EXPANDED GPS MAP PLACE SEARCH (FALLBACK FOR EXTERNAL LOCATIONS LIKE "STARBUCKS", "MALL") ──
    String? searchQuery;
    final searchPrefixes = [
      "search for ", "search place ", "search ", "find me ", "find ",
      "navigate to ", "take me to ", "go to ", "look for ",
      "pumunta sa ", "hanapin ang ", "hanapin sa ", "dalhin ako sa ",
      "hanapin mo ", "hanapin "
    ];

    for (final prefix in searchPrefixes) {
      if (cleanText.startsWith(prefix)) {
        searchQuery = cleanText.substring(prefix.length).trim();
        break;
      }
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      if (searchQuery == "nav" ||
          searchQuery == "nab" ||
          searchQuery == "map" ||
          searchQuery == "maps" ||
          searchQuery == "mapa" ||
          searchQuery == "navigation" ||
          searchQuery == "nabigasyon") {
        SpeechNavigationNotifier.changeTab(1);
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
        return isFilipino ? "Papunta sa mapa" : "Navigating to map";
      }

      SpeechNavigationNotifier.changeTab(1);
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      SpeechNavigationNotifier.searchPlace(searchQuery);

      // Await database/Google Places fetch
      await Future.delayed(const Duration(milliseconds: 1000));

      final results = SpeechNavigationNotifier.activeSearchResults;
      if (results.isEmpty) {
        return isFilipino 
            ? "Paumanhin, walang nahanap na lugar para sa '$searchQuery'" 
            : "Sorry, no results found for '$searchQuery'";
      }

      if (results.length == 1) {
        final place = results[0];
        setState(() {
          _pendingSearchFlow = 2;
          _pendingPlaceToConfirm = place;
        });
        SpeechNavigationNotifier.selectResult(0);
        final placeName = place['name'];
        return isFilipino 
            ? "Nahanap ang $placeName. Sabihin ang 'Oo', 'Kumpirmahin', o 'Sige' para simulan ang ruta, o 'Hindi' para kanselahin." 
            : "Found $placeName. Say 'Yes', 'Confirm', or 'Search' to start route guidance, or 'No' to cancel.";
      }

      setState(() {
        _pendingSearchFlow = 1;
      });

      final count = results.length > 5 ? 5 : results.length;
      final sb = StringBuffer();
      sb.write(isFilipino 
          ? "Aling lokasyon ang pipiliin mo? " 
          : "Which location will you choose? ");
      for (int i = 0; i < count; i++) {
        final distStr = results[i]['dist'] ?? '';
        sb.write(isFilipino
            ? "Numero ${i + 1}: ${results[i]['name']}${distStr.isNotEmpty ? ', may layong $distStr' : ''}. "
            : "Number ${i + 1}: ${results[i]['name']}${distStr.isNotEmpty ? ', $distStr away' : ''}. ");
      }
      sb.write(isFilipino 
          ? "Mangyaring pumili ng numero mula 1 hanggang $count." 
          : "Kindly pick a number from 1 to $count.");
      return sb.toString();
    }

    return isFilipino ? "Hindi ko naintindihan ang utos" : "Command not recognized";
  }

  bool _containsAnyKeyword(String text) {
    if (_pendingSearchFlow == 1 || _pendingSearchFlow == 2 || _pendingSearchFlow == 3) return true;
    final words = [
      "1", "2", "3", "4", "5", "one", "two", "three", "four", "five",
      "una", "pangalawa", "pangatlo", "pang-apat", "panlima",
      "search for", "search", "find", "hanapin", "maghanap", "hanap", "pumunta", "dalhin",
      "got to", "go to", "get to", "gu to", "open", "take me",
      "home", "dashboard", "umpisa", "simula", "bahay",
      "map", "maps", "navigation", "mapa", "nabigasyon", "boses", "nav", "nab",
      "camera", "easylens", "easy lens", "kamera", "kamara", "larawan",
      "settings", "setting", "seting", "mga setting", "buksan ang setting", "preferensya", "kaayusan",
      "notifications", "notification", "abiso", "mga abiso", "patalastas",
      "contacts", "contact", "kontak", "mga kontak",
      "emergency", "sos", "saklolo", "tulong",
      "back", "bumalik", "balik", "pabalik",
      "click", "pindutin", "pindot",
      "help", "guide", "tulong", "gabay", "paano",
      "password", "palitan", "lihim", "salita",
      "units", "yunit", "pagsukat",
      "customize", "isaayos",
      "face", "mukha", "register", "rehistro", "iparehistro", "pagrehistro",
      "logout", "log out", "umalis",
      "profile", "detalye", "aking profile",
      "devices", "glasses", "salamin", "device", "aparato", "mga aparato",
      "scenery", "tanawin", "faces", "face recognition", "pagkilala sa mukha",
      "bluetooth", "koneksyon", "gemini", "online ai", "local ai", "offline ai",
      "audio", "speaker", "network", "wifi", "lock mode", "screen lock", "i-lock",
      "teksto", "sulat", "basahin", "magbasa", "basa", "kausapin", "kausap", "usap", "buddy",
      "stop listening", "stop speech", "tumahimik", "hinto", "pause voice", "stop"
    ];
    
    final clean = text.toLowerCase();
    for (final word in words) {
      if (clean.contains(word)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final settings = SettingsService();
        final isEnabled = settings.speechNavigation;
        final lang = settings.selectedLanguage;
        final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');

        if (_btnLeft == null || _btnTop == null) {
          final size = MediaQuery.of(context).size;
          _btnLeft = 20.0;
          _btnTop = size.height - 106.0;
        }

        if (!isEnabled) {
          return widget.child;
        }

        return Stack(
          children: [
            widget.child,

            // Global Top Floating Banner for Feedback S01
            if (_isListening || _lastRecognized.isNotEmpty)
              Positioned(
                top: 50,
                left: 20,
                right: 20,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isListening ? const Color(0xFF10B981) : AppColors.primaryButton,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isListening ? Icons.hearing : Icons.check_circle,
                          color: _isListening ? const Color(0xFF10B981) : AppColors.primaryButton,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isInitialGreeting
                                    ? (isFilipino ? "Aktibo ang Speech Navigation" : "Speech Navigation Active")
                                    : (_isListening
                                        ? (isFilipino ? "Nakinig para sa utos..." : "Listening for command...")
                                        : (isFilipino ? "Isinasagawa ang utos" : "Executing command")),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryText,
                                ),
                              ),
                              if (_lastRecognized.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '"$_lastRecognized"',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Global Floating Microphone Button (Bottom Left & Draggable) S01
            Positioned(
              left: _btnLeft,
              top: _btnTop,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onPanStart: (_) {
                    _isDragging = false;
                  },
                  onPanUpdate: (details) {
                    if (details.delta.dx.abs() > 1 || details.delta.dy.abs() > 1) {
                      _isDragging = true;
                    }
                    setState(() {
                      final size = MediaQuery.of(context).size;
                      _btnTop = (_btnTop! + details.delta.dy).clamp(
                        50.0,
                        size.height - 100.0,
                      );
                      _btnLeft = (_btnLeft! + details.delta.dx).clamp(
                        10.0,
                        size.width - 90.0,
                      );
                    });
                  },
                  onPanEnd: (_) {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (mounted) {
                        _isDragging = false;
                      }
                    });
                  },
                  onTap: () {
                    if (!_isDragging) {
                      HapticFeedback.mediumImpact();
                      _toggleSpeechNavigation();
                    }
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isLoopActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                      border: Border.all(
                        color: _isLoopActive ? Colors.white : const Color(0xFFFCA5A5),
                        width: 3.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isLoopActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444)).withAlpha(102),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isLoopActive ? Icons.keyboard_voice : Icons.mic_off,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
