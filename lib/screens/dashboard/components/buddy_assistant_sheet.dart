import 'package:flutter/material.dart';
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
  String _buddyState = 'idle'; // 'idle', 'thinking', 'speaking', 'error'

  @override
  void initState() {
    super.initState();
    // Add initial welcome message
    final user = FirebaseService().currentUser;
    final name = user?.displayName ?? "friend";
    
    _messages.add({
      'text': "Woof! Hi $name! I'm Buddy, your local on-device LLM helper. Tell me what to explain or where to navigate!",
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

    // Call Gemma local LLM with context
    final user = FirebaseService().currentUser;
    final name = user?.displayName ?? "User";
    final aid = SettingsService().selectedMobilityAid;
    final lang = SettingsService().selectedLanguage;

    final prompt = """
You are Buddy, the friendly golden retriever dog mascot and visual assistant.
You help visually impaired users navigate this app and explain features.
User Info: Name is '$name', using mobility aid '$aid', language is '$lang'.
Be loyal, friendly, and enthusiastic (like a happy dog).

You have MCP navigation abilities. To open a screen, append exactly one of these tags to the end of your response:
- Home tab: [NAVIGATE: home]
- Audio Navigation tab: [NAVIGATE: nav]
- EasyLens Sensor/Camera tab: [NAVIGATE: hardware]
- Nearby Text Scanner: [NAVIGATE: text]
- Nearby Object Detector: [NAVIGATE: objects]
- Emergency SOS Screen: [NAVIGATE: emergency]
- Settings Screen: [NAVIGATE: settings]

User Question: $text
Buddy's Answer:
""";

    final response = await RagService().askBuddy(prompt);

    if (mounted) {
      setState(() {
        _messages.add({'text': response, 'isUser': false});
        _isThinking = false;
      });
      _scrollToBottom();

      // Check if LLM requested navigation
      final navMatch = RegExp(r'\[NAVIGATE:\s*(\w+)\]').firstMatch(response);
      
      // Speak response concurrently (do not await so navigation is instantaneous)
      _speakText(response);

      if (navMatch != null) {
        final targetScreen = navMatch.group(1);
        if (targetScreen != null) {
          if (mounted) {
            Navigator.of(context).pop();
            widget.onNavigate(targetScreen.trim().toLowerCase());
          }
        }
      }
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await SttService().stopListening((listening) {
        setState(() => _isListening = listening);
      });
    } else {
      await TtsService().stop();
      await SttService().startListening(
        onResult: (text) {
          setState(() {
            _textController.text = text;
          });
        },
        onListeningStateChanged: (listening) {
          setState(() {
            _isListening = listening;
            if (listening) {
              _buddyState = 'speaking';
            } else {
              _buddyState = 'idle';
              if (_textController.text.isNotEmpty) {
                _handleSendMessage(_textController.text);
              }
            }
          });
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
          
          // ── Mascot & Header ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    _getMascotAsset(),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 72,
                      height: 72,
                      color: AppColors.primaryButton,
                      child: Icon(Icons.pets, color: AppColors.primaryButtonText),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buddy local LLM',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isThinking 
                            ? 'Buddy is thinking…' 
                            : _isListening 
                                ? 'Buddy is listening…' 
                                : 'Buddy is ready to help',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: _isListening ? Colors.red : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
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
                        hintText: _isListening ? 'Speak now…' : 'Ask Buddy anything…',
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
