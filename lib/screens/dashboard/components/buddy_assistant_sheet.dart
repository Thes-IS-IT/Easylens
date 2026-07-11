import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../services/tts_service.dart';
import '../../../services/stt_service.dart';
import '../../../services/rag_service.dart';
import '../../../services/firebase_service.dart';
import '../../../services/settings_service.dart';

class BuddyAssistantSheet extends StatefulWidget {
  final Function(String) onNavigate;

  const BuddyAssistantSheet({super.key, required this.onNavigate});

  static void show(BuildContext context, {required Function(String) onNavigate}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BuddyAssistantSheet(onNavigate: onNavigate),
    );
  }

  @override
  State<BuddyAssistantSheet> createState() => _BuddyAssistantSheetState();
}

class _BuddyAssistantSheetState extends State<BuddyAssistantSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  
  bool _isListening = false;
  bool _isThinking = false;
  bool _isSpeaking = false;
  bool _isAutoPilotEnabled = true;
  String _buddyState = 'idle'; // 'idle', 'thinking', 'speaking', 'error'

  @override
  void initState() {
    super.initState();
    // Add initial welcome message
    final user = FirebaseService().currentUser;
    final name = user?.displayName ?? "friend";
    final isFilipino = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') ||
        SettingsService().selectedLanguage.toLowerCase().contains('filipino');

    final welcomeMsg = isFilipino
        ? "Aw! Kumusta $name! Ako si Buddy, ang iyong lokal na AI katulong. Sabihin mo sa akin kung ano ang gusto mong ipaliwanag o kung saan mo gustong pumunta!"
        : "Woof! Hi $name! I'm Buddy, your local on-device LLM helper. Tell me what to explain or where to navigate!";

    _messages.add({
      'text': welcomeMsg,
      'isUser': false,
    });

    // Read welcome message aloud and auto-listen S01
    _initializeAssistant();
  }

  Future<void> _initializeAssistant() async {
    await _speakText(_messages.first['text']);
    // Wait briefly and start listening hands-free
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted && !_isListening) {
      _toggleListening();
    }
  }

  @override
  void dispose() {
    RagService().clearGemmaSession();
    TtsService().stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _speakText(String text) async {
    // Strip the navigation tag before speaking to the user S01
    final cleanText = text.replaceAll(RegExp(r'\[NAVIGATE:.*?\]'), '').trim();
    setState(() {
      _isSpeaking = true;
      _buddyState = 'speaking';
    });
    await TtsService().speak(cleanText);
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _buddyState = 'idle';
      });

      // Auto-Pilot hands-free listening loop
      if (_isAutoPilotEnabled && !_isListening && !_isThinking) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && !_isListening && !_isThinking && !_isSpeaking) {
            _toggleListening();
          }
        });
      }
    }
  }

  Future<void> _handleSendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'isUser': true});
      _isThinking = true;
      _buddyState = 'thinking';
    });
    _textController.clear();
    _scrollToBottom();

    await TtsService().stop();

    final user = FirebaseService().currentUser;
    final name = user?.displayName ?? "User";
    final aid = SettingsService().selectedMobilityAid;
    final lang = SettingsService().selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') ||
        lang.toLowerCase().contains('filipino');

    final prompt = """
You are Buddy, the friendly visual assistant dog.
User Info: Name is '$name', using mobility aid '$aid'.
Be enthusiastic. Keep answers under 3 sentences.

MCP Navigation (append exactly one tag to open a screen):
- Home: [NAVIGATE: home]
- Audio Nav: [NAVIGATE: nav]
- EasyLens Camera: [NAVIGATE: hardware]
- Text Scanner: [NAVIGATE: text]
- Object Detector: [NAVIGATE: objects]
- SOS Screen: [NAVIGATE: emergency]
- Settings: [NAVIGATE: settings]
- Notifications: [NAVIGATE: notifications]
- Contacts: [NAVIGATE: contacts]
- Journal: [NAVIGATE: journal]

Question: $text
Buddy:
""";

    String response;
    if (isFilipino) {
      // Force Online Gemini for Filipino/Tagalog language S01
      response = await RagService().askBuddyGemini(text, name, aid);
    } else {
      // Force local Gemma for English language S01
      response = await RagService().askBuddy(prompt);
    }

    if (mounted) {
      // Detect dynamic navigation target
      final matchedKey = _detectNavigationTarget(text, response);

      if (matchedKey != null && matchedKey.isNotEmpty) {
        final isFilipino = lang.toLowerCase().contains('tagalog') ||
            lang.toLowerCase().contains('filipino');
            
        final screenNames = {
          'home': isFilipino ? 'Home screen' : 'Home screen',
          'nav': isFilipino ? 'Audio Navigation screen' : 'Audio Navigation screen',
          'hardware': isFilipino ? 'EasyLens Camera' : 'EasyLens Camera',
          'text': isFilipino ? 'Text Scanner' : 'Text Scanner',
          'objects': isFilipino ? 'Object Detector' : 'Object Detector',
          'emergency': isFilipino ? 'SOS Emergency screen' : 'SOS Emergency screen',
          'settings': isFilipino ? 'Settings screen' : 'Settings screen',
          'notifications': isFilipino ? 'Notifications screen' : 'Notifications screen',
          'contacts': isFilipino ? 'Contacts screen' : 'Contacts screen',
          'journal': isFilipino ? 'Talaarawan ni Buddy' : "Buddy's Journal",
        };
        final screenName = screenNames[matchedKey] ?? matchedKey;
        response = isFilipino 
            ? "Aw! Nandito na tayo sa $screenName!" 
            : "Woof! We're here on the $screenName now!";
      }

      if (matchedKey != null && matchedKey.isNotEmpty) {
        setState(() {
          _messages.add({'text': response, 'isUser': false});
          _isThinking = false;
        });
        _scrollToBottom();
      } else {
        _animateResponse(response);
      }

      // Speak response concurrently (do not await so navigation is instantaneous)
      _speakText(response);

      if (matchedKey != null && matchedKey.isNotEmpty && mounted) {
        // Trigger haptic vibration for successful auto-pilot action S01
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.of(context).pop();
            widget.onNavigate(matchedKey);
          }
        });
      }
    }
  }

  void _animateResponse(String response) {
    if (!mounted) return;
    
    setState(() {
      _isThinking = false;
      _messages.add({'text': '', 'isUser': false});
    });

    final int targetIndex = _messages.length - 1;
    int index = 0;
    
    const int step = 3;
    Timer.periodic(const Duration(milliseconds: 15), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      index += step;
      if (index >= response.length) {
        setState(() {
          _messages[targetIndex]['text'] = response;
        });
        timer.cancel();
        _scrollToBottom();
      } else {
        setState(() {
          _messages[targetIndex]['text'] = response.substring(0, index);
        });
        _scrollToBottom();
      }
    });
  }

  String? _detectNavigationTarget(String userQuery, String llmResponse) {
    // 1. First check if LLM response has explicit NAVIGATE tag
    final navMatch = RegExp(r'\[NAVIGATE:\s*([^\]]+)\]', caseSensitive: false).firstMatch(llmResponse);
    if (navMatch != null) {
      final target = navMatch.group(1)?.trim().toLowerCase() ?? '';
      return _mapTargetToKey(target);
    }

    final query = userQuery.toLowerCase();
    final response = llmResponse.toLowerCase();

    // 2. Perform direct regex/sub-string heuristics based on User query
    final containsGoAction = query.contains('go to') || 
                             query.contains('open') || 
                             query.contains('launch') || 
                             query.contains('start') || 
                             query.contains('take me to') || 
                             query.contains('navigate') || 
                             query.contains('show') || 
                             query.contains('switch to') || 
                             query.contains('move to') ||
                             query.contains('pumunta') || // Tagalog
                             query.contains('buksan');    // Tagalog

    if (containsGoAction) {
      if (query.contains('setting')) return 'settings';
      if (query.contains('notification') || query.contains('alert')) return 'notifications';
      if (query.contains('contact') || query.contains('phonebook') || query.contains('directory') || query.contains('tawagan') || query.contains('contacts')) return 'contacts';
      if (query.contains('emergency') || query.contains('sos') || query.contains('saklolo') || query.contains('tulong')) return 'emergency';
      if (query.contains('home') || query.contains('dashboard') || query.contains('welcome') || query.contains('umpisa')) return 'home';
      if (query.contains('navig') || query.contains('gps') || query.contains('map') || query.contains('direction') || query.contains('audio nav')) return 'nav';
      if (query.contains('hardware') || query.contains('sensor') || query.contains('camera') || query.contains('cam') || query.contains('lens')) return 'hardware';
      if (query.contains('text') || query.contains('ocr') || query.contains('scan text') || query.contains('basa')) return 'text';
      if (query.contains('object') || query.contains('detect') || query.contains('scan object') || query.contains('bagay')) return 'objects';
      if (query.contains('journal') || query.contains('diary') || query.contains('logs') || query.contains('insights') || query.contains('memory') || query.contains('talaarawan')) return 'journal';
    }

    // 3. Fall back to scanning the LLM response context for screen keywords combined with navigation advice
    if (response.contains('settings tab') || response.contains('settings screen') || response.contains('tap "settings"') || response.contains('go to the settings') || response.contains('go to settings')) {
      return 'settings';
    }
    if (response.contains('notification') || response.contains('alerts')) {
      if (response.contains('open') || response.contains('go to') || response.contains('check')) {
        return 'notifications';
      }
    }
    if (response.contains('contact') || response.contains('phonebook') || response.contains('contacts')) {
      if (response.contains('open') || response.contains('go to') || response.contains('call') || response.contains('tap')) {
        return 'contacts';
      }
    }
    if (response.contains('emergency') || response.contains('sos')) {
      if (response.contains('open') || response.contains('go to') || response.contains('trigger') || response.contains('call')) {
        return 'emergency';
      }
    }
    if (response.contains('home tab') || response.contains('dashboard') || response.contains('main screen')) {
      return 'home';
    }
    if (response.contains('audio navigation') || response.contains('nav tab') || response.contains('gps')) {
      return 'nav';
    }
    if (response.contains('sensor') || response.contains('camera tab') || response.contains('hardware')) {
      return 'hardware';
    }
    if (response.contains('text scanner') || response.contains('scan text') || response.contains('ocr')) {
      return 'text';
    }
    if (response.contains('object detector') || response.contains('detect objects') || response.contains('object detection')) {
      return 'objects';
    }
    if (response.contains('journal') || response.contains('diary') || response.contains('logs') || response.contains('insights')) {
      return 'journal';
    }

    return null;
  }

  String? _mapTargetToKey(String target) {
    if (target.contains('home')) return 'home';
    if (target.contains('nav')) return 'nav';
    if (target.contains('hardware') || target.contains('sens') || target.contains('camera')) return 'hardware';
    if (target.contains('text') || target.contains('ocr') || target.contains('scan')) return 'text';
    if (target.contains('object') || target.contains('detect')) return 'objects';
    if (target.contains('emergency') || target.contains('sos') || target.contains('phone')) return 'emergency';
    if (target.contains('setting')) return 'settings';
    if (target.contains('notification')) return 'notifications';
    if (target.contains('contact')) return 'contacts';
    if (target.contains('journal')) return 'journal';
    return null;
  }

  void _toggleListening() async {
    HapticFeedback.lightImpact();
    if (_isListening) {
      await SttService().stopListening((listening) {
        setState(() => _isListening = listening);
      });
    } else {
      await TtsService().stop();
      bool messageSent = false;
      await SttService().startListening(
        onResult: (text, isFinal) {
          setState(() {
            _textController.text = text;
          });
          if (isFinal && text.trim().isNotEmpty && !messageSent) {
            messageSent = true;
            _handleSendMessage(text);
          }
        },
        onListeningStateChanged: (listening) {
          if (mounted) {
            HapticFeedback.lightImpact();
            setState(() {
              _isListening = listening;
              if (listening) {
                _buddyState = 'speaking';
                messageSent = false;
              } else {
                _buddyState = 'idle';
                if (_textController.text.isNotEmpty && !messageSent) {
                  messageSent = true;
                  _handleSendMessage(_textController.text);
                }
              }
            });
          }
        },
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getMascotAsset() {
    switch (_buddyState) {
      case 'thinking':
        return 'assets/Mascots/06 Thinking.gif';
      case 'speaking':
        return 'assets/Mascots/01 Happy.gif';
      case 'error':
        return 'assets/Mascots/02 Error.gif';
      case 'idle':
      default:
        return 'assets/Mascots/05 Welcome.gif';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = SettingsService().selectedContrastTheme;
    final isDefault = theme == 'Default';

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: AppColors.unselectedBorder, width: 1.5),
      ),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          // ── Handler bar ────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 45,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.unselectedBorder,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          
          // Auto-Pilot Mode Status & Toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isAutoPilotEnabled ? Icons.bolt : Icons.power_settings_new_rounded,
                      color: _isAutoPilotEnabled ? const Color(0xFF10B981) : Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isAutoPilotEnabled ? 'AUTO-PILOT ACTIVE' : 'AUTO-PILOT INACTIVE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _isAutoPilotEnabled ? const Color(0xFF10B981) : Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _isAutoPilotEnabled = !_isAutoPilotEnabled;
                      // If enabled and not listening, start listening automatically
                      if (_isAutoPilotEnabled && !_isListening && !_isThinking && !_isSpeaking) {
                        _toggleListening();
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isAutoPilotEnabled
                          ? const Color(0xFF10B981).withOpacity(0.12)
                          : Colors.grey.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isAutoPilotEnabled
                            ? const Color(0xFF10B981)
                            : Colors.grey,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      _isAutoPilotEnabled ? 'Hands-Free' : 'Tap to Talk',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _isAutoPilotEnabled ? const Color(0xFF10B981) : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Image.asset(
                  _getMascotAsset(),
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 72,
                    height: 72,
                    color: AppColors.primaryButton,
                    child: Icon(Icons.pets, color: AppColors.primaryButtonText),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Builder(builder: (context) {
                    final isFilipino = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') ||
                        SettingsService().selectedLanguage.toLowerCase().contains('filipino');
                    final thinkingText = isFilipino ? 'Nag-iisip si Buddy…' : 'Buddy is thinking…';
                    final listeningText = isFilipino ? 'Nakikinig si Buddy…' : 'Buddy is listening…';
                    final readyText = isFilipino ? 'Handa si Buddy na tumulong' : 'Buddy is ready to help';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFilipino ? 'Buddy Lokal AI' : 'Buddy Local AI',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isThinking
                              ? thinkingText
                              : _isListening
                                  ? listeningText
                                  : readyText,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _isListening ? Colors.red : AppColors.textMuted,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.primaryText),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          
          Divider(height: 1, color: AppColors.unselectedBorder),

          // ── Messages List ──────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] == true;
                
                // Clean navigate tags from UI bubble S01
                final cleanText = msg['text'].replaceAll(RegExp(r'\[NAVIGATE:.*?\]'), '').trim();

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser 
                          ? AppColors.primaryButton 
                          : isDefault 
                              ? const Color(0xFFF1F5F9) 
                              : AppColors.unselectedBorder,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Text(
                      cleanText,
                      style: GoogleFonts.inter(
                        color: isUser 
                            ? AppColors.primaryButtonText 
                            : AppColors.primaryText,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: isUser ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isThinking)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryButton),
                  ),
                ),
              ),
            ),

          Divider(height: 1, color: AppColors.unselectedBorder),

          // ── Text/Voice Input Panel ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDefault ? const Color(0xFFF1F5F9) : AppColors.primaryBackground,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.unselectedBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _textController,
                      style: GoogleFonts.inter(color: AppColors.primaryText),
                      decoration: InputDecoration(
                        hintText: (() {
                          final isFilipino = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') ||
                              SettingsService().selectedLanguage.toLowerCase().contains('filipino');
                          if (_isListening) return isFilipino ? 'Magsalita na…' : 'Speak now…';
                          return isFilipino ? 'Tanungin si Buddy ng kahit ano…' : 'Ask Buddy anything…';
                        })(),
                        hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                        border: InputBorder.none,
                      ),
                      onSubmitted: _handleSendMessage,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _toggleListening,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red : AppColors.primaryButton,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: AppColors.primaryButton),
                  onPressed: () => _handleSendMessage(_textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
