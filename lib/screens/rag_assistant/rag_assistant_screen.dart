import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../services/rag_service.dart';
import '../../services/tts_service.dart';
import '../../services/stt_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class RagAssistantScreen extends StatefulWidget {
  const RagAssistantScreen({super.key});

  @override
  State<RagAssistantScreen> createState() => _RagAssistantScreenState();
}

class _RagAssistantScreenState extends State<RagAssistantScreen> {
  final List<ChatMessage> _messages = [];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _ragService = RagService();
  final _sttService = SttService();

  bool _isBuddyThinking = false;
  bool _isDownloadingModel = false;
  double _downloadProgress = 0.0;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _ragService.initializeGemma();
    
    // Add initial greeting message from Buddy
    _messages.add(
      ChatMessage(
        text: "Woof! Hello there! I'm Buddy, your EasyLens vision assistant. How can I help you explore today? Ask me about my features, safety guidelines, or Firebase support!",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    TtsService().stop();
    super.dispose();
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

  Future<void> _handleSendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    
    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isBuddyThinking = true;
    });
    
    _scrollToBottom();

    // Call RAG Service (Gemma / Gemini fallback)
    final reply = await _ragService.askBuddy(text);

    setState(() {
      _messages.add(
        ChatMessage(
          text: reply,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      _isBuddyThinking = false;
    });

    _scrollToBottom();

    // Announce reply via TTS
    TtsService().speak(reply);
  }

  void _toggleSttListening() async {
    if (_isListening) {
      await _sttService.stopListening((state) {
        setState(() {
          _isListening = state;
        });
      });
    } else {
      await _sttService.startListening(
        onResult: (text, isFinal) {
          setState(() {
            _textController.text = text;
          });
        },
        onListeningStateChanged: (state) {
          setState(() {
            _isListening = state;
          });
        },
      );
    }
  }

  Future<void> _handleDownloadGemmaModel() async {
    setState(() {
      _isDownloadingModel = true;
      _downloadProgress = 0.0;
    });

    try {
      const savePath = "/storage/emulated/0/Android/data/com.company.easylens/files/model.bin";
      const url = "https://huggingface.co/MrHoang/LLM/resolve/main/gemma-2b-it-gpu-int8.bin";
      
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.parent.create(recursive: true);
        
        final int totalBytes = response.contentLength;
        int downloadedBytes = 0;
        
        final IOSink sink = file.openWrite();
        
        await for (final chunk in response) {
          if (!mounted) {
            await sink.close();
            return;
          }
          sink.add(chunk);
          downloadedBytes += chunk.length;
          if (totalBytes > 0) {
            setState(() {
              _downloadProgress = downloadedBytes / totalBytes;
            });
          }
        }
        
        await sink.flush();
        await sink.close();
        
        // Initialize the actual Gemma model engine using the downloaded file
        await _ragService.initializeGemma();
        
        if (mounted) {
          setState(() {
            _isDownloadingModel = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Gemma 2B model successfully downloaded! Buddy is now fully localized offline."),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Server returned code ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloadingModel = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Download failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocalActive = _ragService.isGemmaReady;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RAG Buddy Chatbot',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
                fontSize: 16,
              ),
            ),
            Text(
              isLocalActive ? 'Gemma 2B (Offline)' : 'Gemini AI Fallback (Online)',
              style: GoogleFonts.inter(
                color: isLocalActive ? Colors.green : Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Gemma Installer progress card (if offline Gemma is not downloaded yet)
            if (!isLocalActive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.orange.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.download_for_offline, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gemma 2B Offline Assistant',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          Text(
                            _isDownloadingModel
                                ? 'Downloading: ${(_downloadProgress * 100).toStringAsFixed(0)}%'
                                : 'Download the offline model for local private queries (1.4 GB).',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          if (_isDownloadingModel) ...[
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: _downloadProgress,
                              color: Colors.orange,
                              backgroundColor: Colors.orange.shade200,
                            ),
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!_isDownloadingModel)
                      TextButton(
                        onPressed: _handleDownloadGemmaModel,
                        child: Text(
                          'DOWNLOAD',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Messages chat feed list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),

            // Thinking mascot feedback panel
            if (_isBuddyThinking)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: AppColors.lightBackground,
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/Mascots/06 Thinking.gif',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(Icons.pets, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Buddy is thinking...',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

            // Message Input bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: GoogleFonts.inter(fontSize: 15),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSendMessage(),
                      decoration: InputDecoration(
                        hintText: _isListening ? 'Listening...' : 'Type your question...',
                        hintStyle: GoogleFonts.inter(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.lightBackground,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Speech-to-Text Mic Icon button
                  GestureDetector(
                    onTap: _toggleSttListening,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.red : AppColors.primaryText,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  GestureDetector(
                    onTap: _handleSendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.primaryButton,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? AppColors.primaryButton : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16.0),
            topRight: const Radius.circular(16.0),
            bottomLeft: Radius.circular(message.isUser ? 16.0 : 0.0),
            bottomRight: Radius.circular(message.isUser ? 0.0 : 16.0),
          ),
          border: message.isUser
              ? null
              : Border.all(color: AppColors.unselectedBorder.withOpacity(0.5)),
          boxShadow: [BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 4,
              offset: Offset(0, 2),
            )],
        ),
        child: Text(
          message.text,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: message.isUser ? Colors.white : AppColors.primaryText,
          ),
        ),
      ),
    );
  }
}
