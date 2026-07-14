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

  static final ValueNotifier<bool> isVisible = ValueNotifier<bool>(false);

  @override
  State<BuddyAssistantSheet> createState() => _BuddyAssistantSheetState();
}

class _BuddyAssistantSheetState extends State<BuddyAssistantSheet> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  
  bool _isListening = false;
  bool _isThinking = false;
  bool _isSpeaking = false;
  bool _isStreaming = false; // true while local Gemma is generating tokens
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
        ? "Aw! Kumusta $name! Ako si Buddy, ang iyong lokal na AI katulong. Maaari mong paganahin ang advanced na Gemini o baguhin sa Local AI sa settings. Sabihin mo sa akin kung ano ang gusto mong ipaliwanag o kung saan mo gustong pumunta!"
        : "Woof! Hi $name! I'm Buddy, your local on-device LLM helper. You can enable advanced Gemini or switch to Local AI in settings. Tell me what to explain or where to navigate!";

    _messages.add({
      'text': welcomeMsg,
      'isUser': false,
    });

    BuddyAssistantSheet.isVisible.value = true;
    // Read welcome message aloud and auto-listen S01
    _initializeAssistant();
  }

  Future<void> _initializeAssistant() async {
    // Read welcome message aloud only — mic must be tapped manually by the user S01
    await _speakText(_messages.first['text']);
  }

  @override
  void dispose() {
    BuddyAssistantSheet.isVisible.value = false;
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

      // Mic stays idle after speaking — user must tap to start listening S01
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
    final lang = SettingsService().selectedLanguage;
    final isFilipino = lang.toLowerCase().contains('tagalog') ||
        lang.toLowerCase().contains('filipino');

    // Unify all languages to use online streaming Gemini with api key fallback S01
    // Build a history slice of the last 3 turns (6 messages) for multi-turn context S01
    // Exclude the current user message (just added) — that is the new query
    final historySlice = _messages.length > 1
        ? _messages
            .sublist(0, _messages.length - 1) // all except the last (current user msg)
            .where((m) => (m['text'] as String? ?? '').trim().isNotEmpty)
            .toList()
            .reversed
            .take(6) // 3 back-and-forth turns
            .toList()
            .reversed
            .toList()
        : <Map<String, dynamic>>[];

    int assistantMsgIndex = -1;
    setState(() {
      _messages.add({'text': '', 'isUser': false});
      _isThinking = false;
      _isStreaming = true;
      assistantMsgIndex = _messages.length - 1;
    });

    String accumulatedText = '';
    bool errorDetected = false;
    DateTime lastUpdate = DateTime.now();

    await for (final token in RagService().askBuddyStream(
      text,
      userName: name,
      history: historySlice,
    )) {
      if (!mounted) break;

      // Detect if an error occurred and the fallback response is starting S01
      final combined = accumulatedText + token;
      final isModelError = combined.toLowerCase().contains('no gemini api key') ||
          combined.toLowerCase().contains('connection error') ||
          combined.toLowerCase().contains('failed to') ||
          combined.toLowerCase().contains('error with key');
      if (isModelError && !errorDetected) {
        // Reset bubble — fallback will be the next meaningful yield
        errorDetected = true;
        accumulatedText = '';
        continue;
      }
      if (errorDetected) {
        // We are now accumulating the clean fallback text
        accumulatedText = token;
        errorDetected = false;
      } else {
        accumulatedText += token;
      }

      final now = DateTime.now();
      if (now.difference(lastUpdate) > const Duration(milliseconds: 80)) {
        setState(() {
          _messages[assistantMsgIndex]['text'] = accumulatedText;
        });
        _scrollToBottom();
        lastUpdate = now;
      }
    }

    if (mounted) {
      setState(() {
        _messages[assistantMsgIndex]['text'] = accumulatedText;
        _isStreaming = false;
      });
      _scrollToBottom();
      _handleResponseOutput(accumulatedText, text, lang, isFilipino, updateIndex: assistantMsgIndex);
    }
  }

  void _handleResponseOutput(String response, String text, String lang, bool isFilipino, {int? updateIndex}) {
    if (!mounted) return;

    // Detect dynamic navigation target
    final matchedKey = _detectNavigationTarget(text, response);

    if (matchedKey != null && matchedKey.isNotEmpty) {
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

    if (updateIndex != null) {
      setState(() {
        _messages[updateIndex]['text'] = response;
        _isThinking = false;
      });
      _scrollToBottom();
    } else {
      setState(() {
        _messages.add({'text': response, 'isUser': false});
        _isThinking = false;
      });
      _scrollToBottom();
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
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: AppColors.unselectedBorder, width: 1.5),
      ),
      height: MediaQuery.of(context).size.height * 0.85,
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
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: isKeyboardOpen ? 6 : 16),
            child: Row(
              children: [
                if (!isKeyboardOpen) ...[
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
                ],
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
                            fontSize: isKeyboardOpen ? 16 : 20,
                            color: AppColors.primaryText,
                          ),
                        ),
                        if (!isKeyboardOpen) ...[
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
                final isLastMsg = index == _messages.length - 1;
                
                // Clean navigate tags from UI bubble S01
                final cleanText = msg['text'].replaceAll(RegExp(r'\[NAVIGATE:.*?\]'), '').trim();

                // Show typing animation for empty streaming assistant bubble S01
                if (!isUser && isLastMsg && _isStreaming && cleanText.isEmpty) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDefault ? const Color(0xFFF1F5F9) : AppColors.unselectedBorder,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: _TypingIndicator(color: AppColors.primaryButton),
                    ),
                  );
                }
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
                      onTap: () {
                        // Immediately stop active voice/speech listeners when keyboard gets focus S01
                        if (_isListening) {
                          _toggleListening();
                        }
                      },
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

/// Animated three-dot typing indicator shown while Buddy is generating a response.
class _TypingIndicator extends StatefulWidget {
  final Color color;
  const _TypingIndicator({required this.color});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  static const int _dotCount = 3;
  static const Duration _dotDuration = Duration(milliseconds: 500);
  static const Duration _dotDelay = Duration(milliseconds: 160);

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_dotCount, (i) {
      return AnimationController(
        vsync: this,
        duration: _dotDuration,
      );
    });

    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0.0, end: -7.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    // Start each dot with a staggered delay
    for (int i = 0; i < _dotCount; i++) {
      Future.delayed(_dotDelay * i, () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_dotCount, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[i].value),
              child: child,
            );
          },
          child: Container(
            margin: EdgeInsets.only(right: i < _dotCount - 1 ? 5 : 0),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.75),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
