import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../services/rag_service.dart';

class SpeechNavigationNotifier {
  static final ValueNotifier<int?> tabChangeNotifier = ValueNotifier<int?>(null);
  static final ValueNotifier<String?> searchPlaceNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<int?> selectResultNotifier = ValueNotifier<int?>(null);
  static final ValueNotifier<bool?> openBuddyNotifier = ValueNotifier<bool?>(null);
  static List<Map<String, dynamic>> activeSearchResults = [];
  
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

  Future<void> _pushAndRecord(Widget screen, String description) async {
    final prev = RagService.currentScreen;
    RagService.recordNavigation(description, actionDescription: "Speech command navigated to $description");
    await navigatorKey.currentState?.push(AppRoute.to(screen));
    RagService.recordNavigation(prev, actionDescription: "Returned from $description via speech back action");
  }

  @override
  void dispose() {
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

  void _startLoop() async {
    setState(() {
      _isLoopActive = true;
      _lastRecognized = "";
    });

    final lang = SettingsService().selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    final startPrompt = isFilipino 
        ? "Naka-enable ang Speech Navigation. Saan mo gustong pumunta o pindutin?" 
        : "Speech Navigation enabled. Where would you like to navigate or click?";
    
    setState(() {
      _lastRecognized = startPrompt;
    });

    await TtsService().speakAwait(startPrompt);
    _runSpeechNavigationLoop();
  }

  void _stopLoop() async {
    _silenceTimer?.cancel();
    await SttService().stopListening((_) {});
    setState(() {
      _isLoopActive = false;
      _isListening = false;
      _lastRecognized = "";
    });
  }

  void _runSpeechNavigationLoop() async {
    if (!mounted || !_isLoopActive) return;

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
        if (mounted && _isLoopActive) {
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
  }

  void _processAndSpeakCurrentText() async {
    _silenceTimer?.cancel();
    if (!mounted || !_isLoopActive) return;

    // Stop listening so TTS can speak S01
    await SttService().stopListening((_) {});
    setState(() {
      _isListening = false;
    });

    final text = _lastRecognized.trim();
    if (text.isEmpty) {
      // Prompt again if they didn't speak anything S01
      final lang = SettingsService().selectedLanguage;
      final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
      final prompt = isFilipino 
          ? "Saan mo gustong pumunta o pindutin susunod?" 
          : "Where would you like to navigate next or click?";
      
      setState(() {
        _lastRecognized = prompt;
      });
      await TtsService().speakAwait(prompt);
      
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted && _isLoopActive) {
        _runSpeechNavigationLoop();
      }
      return;
    }

    // Filter background/registered noise (ignore speech that lacks core command keywords)
    if (!_containsAnyKeyword(text)) {
      setState(() {
        _lastRecognized = "";
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && _isLoopActive) {
        _runSpeechNavigationLoop();
      }
      return;
    }

    // Process the command and get response text S01
    final response = await _processCommand(text);

    if (mounted && _isLoopActive) {
      final lang = SettingsService().selectedLanguage;
      final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
      
      final fullResponse = isFilipino 
          ? "$response. Saan mo gustong pumunta o pindutin susunod?" 
          : "$response. Where would you like to navigate next or click?";

      setState(() {
        _lastRecognized = fullResponse;
      });

      await TtsService().speakAwait(fullResponse);
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted && _isLoopActive) {
      _runSpeechNavigationLoop();
    }
  }

  Future<String> _processCommand(String text) async {
    final cleanText = text.trim().toLowerCase();
    if (cleanText.isEmpty) return "";

    final lang = SettingsService().selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');

    // ── SEARCH RESULTS SELECTION FLOW S01 ──
    if (_pendingSearchFlow == 1) {
      final results = SpeechNavigationNotifier.activeSearchResults;
      
      // Check for cancel command
      if (cleanText.contains("cancel") || cleanText.contains("i-cancel") || cleanText.contains("hinto") || cleanText.contains("stop")) {
        setState(() {
          _pendingSearchFlow = 0;
        });
        return isFilipino ? "Kinansela ang paghahanap" : "Search cancelled";
      }

      int selectedIndex = -1;
      
      // Check word number matches S01
      if (cleanText.contains("1") || cleanText.contains("one") || cleanText.contains("first") || cleanText.contains("una")) {
        selectedIndex = 0;
      } else if (cleanText.contains("2") || cleanText.contains("two") || cleanText.contains("second") || cleanText.contains("pangalawa")) {
        selectedIndex = 1;
      } else if (cleanText.contains("3") || cleanText.contains("three") || cleanText.contains("third") || cleanText.contains("pangatlo")) {
        selectedIndex = 2;
      } else {
        // Match specific place name
        for (int i = 0; i < results.length && i < 3; i++) {
          final name = (results[i]['name'] as String).toLowerCase();
          if (cleanText.contains(name) || name.contains(cleanText)) {
            selectedIndex = i;
            break;
          }
        }
      }
      
      if (selectedIndex >= 0 && selectedIndex < results.length) {
        setState(() {
          _pendingSearchFlow = 0;
        });
        SpeechNavigationNotifier.selectResult(selectedIndex);
        final placeName = results[selectedIndex]['name'];
        return isFilipino 
            ? "Papunta sa $placeName" 
            : "Starting navigation to $placeName";
      } else {
        return isFilipino 
            ? "Hindi nakuha ang numero. Mangyaring sabihin ang numero o kanselahin." 
            : "I didn't catch that number. Please say the number or cancel.";
      }
    }

    // ── TRIGGER SEARCH PLACE COMMAND S01 ──
    String? searchQuery;
    if (cleanText.startsWith("search for ")) {
      searchQuery = cleanText.substring("search for ".length).trim();
    } else if (cleanText.startsWith("find ")) {
      searchQuery = cleanText.substring("find ".length).trim();
    } else if (cleanText.startsWith("hanapin ang ")) {
      searchQuery = cleanText.substring("hanapin ang ".length).trim();
    } else if (cleanText.startsWith("hanapin ")) {
      searchQuery = cleanText.substring("hanapin ".length).trim();
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
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

      setState(() {
        _pendingSearchFlow = 1;
      });

      final sb = StringBuffer();
      sb.write(isFilipino 
          ? "May nahanap akong ${results.length > 3 ? 3 : results.length} na lugar. " 
          : "I found ${results.length > 3 ? 3 : results.length} places. ");
      for (int i = 0; i < results.length && i < 3; i++) {
        sb.write("${i + 1}: ${results[i]['name']}. ");
      }
      sb.write(isFilipino 
          ? "Sabihin ang numero upang mag-navigate." 
          : "Please say the number to navigate.");
      return sb.toString();
    }

    // 1. Dashboard/Home tab navigation
    if (cleanText.contains("go to home") || cleanText.contains("open home") || cleanText.contains("go to dashboard") || cleanText.contains("open dashboard") || cleanText.contains("dashboard") || cleanText.contains("pumunta sa dashboard") || cleanText.contains("umpisa")) {
      SpeechNavigationNotifier.changeTab(0);
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      return isFilipino ? "Papunta sa dashboard" : "Navigating to dashboard";
    }

    // 2. Navigation/Map tab navigation
    if (cleanText.contains("go to map") || cleanText.contains("open map") || cleanText.contains("go to navigation") || cleanText.contains("navigation") || cleanText.contains("map") || cleanText.contains("pumunta sa mapa") || cleanText.contains("nabigasyon")) {
      SpeechNavigationNotifier.changeTab(1);
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      return isFilipino ? "Papunta sa mapa" : "Navigating to map";
    }

    // 3. EasyLens camera tab navigation
    if (cleanText.contains("go to camera") || cleanText.contains("open camera") || cleanText.contains("go to easylens") || cleanText.contains("easylens") || cleanText.contains("go to easy lens") || cleanText.contains("easy lens") || cleanText.contains("camera") || cleanText.contains("pumunta sa camera")) {
      SpeechNavigationNotifier.changeTab(2);
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      return isFilipino ? "Binubuksan ang camera" : "Navigating to EasyLens camera";
    }

    // 4. Settings Screen
    if (cleanText.contains("go to settings") || cleanText.contains("open settings") || cleanText.contains("settings") || cleanText.contains("mga setting") || cleanText.contains("buksan ang setting")) {
      _pushAndRecord(const SettingsScreen(), "Settings");
      return isFilipino ? "Binubuksan ang mga setting" : "Navigating to settings";
    }

    // 5. Notifications Screen
    if (cleanText.contains("go to notifications") || cleanText.contains("open notifications") || cleanText.contains("notifications") || cleanText.contains("mga abiso") || cleanText.contains("abiso")) {
      _pushAndRecord(const NotificationsScreen(), "Notifications");
      return isFilipino ? "Binubuksan ang mga abiso" : "Navigating to notifications";
    }

    // 6. Contacts Screen
    if (cleanText.contains("go to contacts") || cleanText.contains("open contacts") || cleanText.contains("contacts") || cleanText.contains("mga kontak") || cleanText.contains("kontak")) {
      _pushAndRecord(const ContactsScreen(), "Contacts");
      return isFilipino ? "Binubuksan ang mga contact" : "Navigating to contacts";
    }

    // 7. Emergency Screen
    if (cleanText.contains("go to emergency") || cleanText.contains("emergency") || cleanText.contains("sos") || cleanText.contains("saklolo")) {
      _pushAndRecord(const EmergencyScreen(), "Emergency SOS");
      return isFilipino ? "Binubuksan ang emergency" : "Navigating to emergency";
    }

    // 8. Go back / pop route
    if (cleanText.contains("go back") || cleanText.contains("back") || cleanText.contains("bumalik") || cleanText.contains("pabalik") || cleanText.contains("balik")) {
      navigatorKey.currentState?.pop();
      return isFilipino ? "Bumabalik" : "Going back";
    }

    // 9. Click commands mapping S01 (prefixes optional for accessibility)
    final hasClickPrefix = cleanText.startsWith("click ") || cleanText.startsWith("pindutin ");
    final target = hasClickPrefix 
        ? cleanText.replaceAll("click ", "").replaceAll("pindutin ", "").trim() 
        : cleanText;
    
    if (target.contains("buddy") || target.contains("chat") || target.contains("kausap")) {
      SpeechNavigationNotifier.openBuddyNotifier.value = true;
      Future.delayed(const Duration(milliseconds: 50), () {
        SpeechNavigationNotifier.openBuddyNotifier.value = null;
      });
      return isFilipino ? "Binubuksan ang chatbot ni Buddy" : "Opening Buddy chatbot";
    }
    if (target.contains("text") || target.contains("ocr") || target.contains("basa")) {
      _pushAndRecord(ImageLabelingScreen(
        onTabSelected: (index) {
          navigatorKey.currentState?.pop();
          SpeechNavigationNotifier.changeTab(index);
        },
      ), "Text Scanner");
      return isFilipino ? "Binubuksan ang text scanner" : "Opening text scanner";
    }
    if (target.contains("object") || target.contains("bagay") || target.contains("detector") || target.contains("sensor")) {
      _pushAndRecord(const HardwareScreen(initialStep: 4), "Object Detector");
      return isFilipino ? "Binubuksan ang object detector" : "Opening object detector";
    }
    if (target.contains("help") || target.contains("guide") || target.contains("tulong")) {
      _pushAndRecord(const HelpGuideScreen(), "Help Guide");
      return isFilipino ? "Binubuksan ang gabay sa tulong" : "Opening help guide";
    }
    if (target.contains("password") || target.contains("palitan")) {
      _pushAndRecord(const ChangePasswordScreen(), "Change Password");
      return isFilipino ? "Binubuksan ang palitan ng password" : "Opening change password";
    }
    if (target.contains("units") || target.contains("yunit")) {
      _pushAndRecord(const UnitsScreen(), "Units Settings");
      return isFilipino ? "Binubuksan ang mga unit" : "Opening units setting";
    }
    if (target.contains("customize") || target.contains("home screen")) {
      _pushAndRecord(const CustomizeHomeScreen(), "Customize Home Screen");
      return isFilipino ? "Inaayos ang home screen" : "Opening home screen customizer";
    }
    if (target.contains("face") || target.contains("mukha") || target.contains("register")) {
      _pushAndRecord(const FaceRegistrationScreen(), "Face Registration");
      return isFilipino ? "Binubuksan ang pagrehistro ng mukha" : "Opening face registration";
    }
    if (target.contains("logout") || target.contains("log out") || target.contains("umalis")) {
      await FirebaseService().signOut();
      navigatorKey.currentState?.pushAndRemoveUntil(
        AppRoute.to(const OnboardingScreen()),
        (route) => false,
      );
      return isFilipino ? "Umalis sa account" : "Logging out";
    }
    if (target.contains("profile") || target.contains("detalye")) {
      _pushAndRecord(const ProfileDetailsScreen(), "Profile Details");
      return isFilipino ? "Binubuksan ang profile" : "Opening profile details";
    }

    return isFilipino ? "Hindi ko naintindihan ang utos" : "Command not recognized";
  }

  bool _containsAnyKeyword(String text) {
    if (_pendingSearchFlow == 1) return true;
    final words = [
      "search for", "find", "hanapin",
      "home", "dashboard", "umpisa",
      "map", "navigation", "mapa", "nabigasyon",
      "camera", "easylens", "easy lens",
      "settings", "setting", "seting", "mga setting", "buksan ang setting",
      "notifications", "notification", "abiso",
      "contacts", "contact", "kontak",
      "emergency", "sos", "saklolo",
      "back", "bumalik", "balik", "pabalik",
      "click", "pindutin", "pindot",
      "help", "guide", "tulong", "gabay",
      "password", "palitan",
      "units", "yunit",
      "customize", "isaayos",
      "face", "mukha", "register",
      "logout", "log out", "umalis",
      "profile", "detalye"
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
                      color: _isListening ? const Color(0xFFE8F5E9) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isListening ? const Color(0xFF4CAF50) : const Color(0xFF0284C7),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isListening ? Icons.hearing : Icons.check_circle,
                          color: _isListening ? const Color(0xFF2E7D32) : const Color(0xFF0369A1),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isListening ? "Listening for command..." : "Executing command",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isListening ? const Color(0xFF1B5E20) : const Color(0xFF075985),
                                ),
                              ),
                              if (_lastRecognized.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '"$_lastRecognized"',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
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
