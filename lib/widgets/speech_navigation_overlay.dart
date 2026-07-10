import 'dart:async';
import 'package:flutter/material.dart';
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

class SpeechNavigationNotifier {
  static final ValueNotifier<int?> tabChangeNotifier = ValueNotifier<int?>(null);
  
  static void changeTab(int index) {
    tabChangeNotifier.value = index;
    Future.delayed(const Duration(milliseconds: 50), () {
      tabChangeNotifier.value = null;
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

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted && _isLoopActive) {
      _runSpeechNavigationLoop();
    }
  }

  Future<String> _processCommand(String text) async {
    final cleanText = text.trim().toLowerCase();
    if (cleanText.isEmpty) return "";

    final lang = SettingsService().selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');

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
      navigatorKey.currentState?.push(AppRoute.to(const SettingsScreen()));
      return isFilipino ? "Binubuksan ang mga setting" : "Navigating to settings";
    }

    // 5. Notifications Screen
    if (cleanText.contains("go to notifications") || cleanText.contains("open notifications") || cleanText.contains("notifications") || cleanText.contains("mga abiso") || cleanText.contains("abiso")) {
      navigatorKey.currentState?.push(AppRoute.to(const NotificationsScreen()));
      return isFilipino ? "Binubuksan ang mga abiso" : "Navigating to notifications";
    }

    // 6. Contacts Screen
    if (cleanText.contains("go to contacts") || cleanText.contains("open contacts") || cleanText.contains("contacts") || cleanText.contains("mga kontak") || cleanText.contains("kontak")) {
      navigatorKey.currentState?.push(AppRoute.to(const ContactsScreen()));
      return isFilipino ? "Binubuksan ang mga contact" : "Navigating to contacts";
    }

    // 7. Emergency Screen
    if (cleanText.contains("go to emergency") || cleanText.contains("emergency") || cleanText.contains("sos") || cleanText.contains("saklolo")) {
      navigatorKey.currentState?.push(AppRoute.to(const EmergencyScreen()));
      return isFilipino ? "Binubuksan ang emergency" : "Navigating to emergency";
    }

    // 8. Go back / pop route
    if (cleanText.contains("go back") || cleanText.contains("back") || cleanText.contains("bumalik") || cleanText.contains("pabalik")) {
      navigatorKey.currentState?.pop();
      return isFilipino ? "Bumabalik" : "Going back";
    }

    // 9. Click commands mapping S01
    if (cleanText.startsWith("click ") || cleanText.startsWith("pindutin ")) {
      final target = cleanText.replaceAll("click ", "").replaceAll("pindutin ", "").trim();
      
      if (target.contains("help") || target.contains("guide") || target.contains("tulong")) {
        navigatorKey.currentState?.push(AppRoute.to(const HelpGuideScreen()));
        return isFilipino ? "Binubuksan ang gabay sa tulong" : "Opening help guide";
      }
      if (target.contains("password") || target.contains("palitan")) {
        navigatorKey.currentState?.push(AppRoute.to(const ChangePasswordScreen()));
        return isFilipino ? "Binubuksan ang palitan ng password" : "Opening change password";
      }
      if (target.contains("units") || target.contains("yunit")) {
        navigatorKey.currentState?.push(AppRoute.to(const UnitsScreen()));
        return isFilipino ? "Binubuksan ang mga unit" : "Opening units setting";
      }
      if (target.contains("customize") || target.contains("home screen")) {
        navigatorKey.currentState?.push(AppRoute.to(const CustomizeHomeScreen()));
        return isFilipino ? "Inaayos ang home screen" : "Opening home screen customizer";
      }
      if (target.contains("face") || target.contains("mukha") || target.contains("register")) {
        navigatorKey.currentState?.push(AppRoute.to(const FaceRegistrationScreen()));
        return isFilipino ? "Binubuksan ang pagrehistro ng mukha" : "Opening face registration";
      }
      if (target.contains("logout") || target.contains("log out") || target.contains("umalis")) {
        await FirebaseService().signOut();
        navigatorKey.currentState?.pushAndRemoveUntil(
          AppRoute.to(const OnboardingScreen()),
          (route) => false,
        );
        return isFilipino ? "Umaalipap" : "Logging out";
      }
      if (target.contains("profile") || target.contains("detalye")) {
        navigatorKey.currentState?.push(AppRoute.to(const ProfileDetailsScreen()));
        return isFilipino ? "Binubuksan ang profile" : "Opening profile details";
      }
    }

    return isFilipino ? "Hindi ko naintindihan ang utos" : "Command not recognized";
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final settings = SettingsService();
        final isEnabled = settings.speechNavigation;

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

            // Global Floating Microphone Button (Bottom Left) S01
            Positioned(
              left: 20,
              bottom: 24,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: _toggleSpeechNavigation,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isLoopActive ? const Color(0xFFE53935) : const Color(0xFF002663),
                      border: Border.all(
                        color: _isLoopActive ? Colors.white : const Color(0xFF4ADE80),
                        width: 3.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isLoopActive ? const Color(0xFFE53935) : const Color(0xFF002663)).withAlpha(102),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isLoopActive ? Icons.mic_off : Icons.keyboard_voice,
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
