import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../services/journal_service.dart';
import '../../services/settings_service.dart';
import '../../services/tts_service.dart';

class JournalDetailScreen extends StatefulWidget {
  final String filePath;
  final String dateStr;

  const JournalDetailScreen({
    super.key,
    required this.filePath,
    required this.dateStr,
  });

  @override
  State<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _JournalDetailScreenState extends State<JournalDetailScreen> {
  final _journalService = JournalService();
  String _content = '';
  bool _isLoading = true;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    TtsService().stop();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    final text = await _journalService.readJournalContent(widget.filePath);
    if (mounted) {
      setState(() {
        _content = text;
        _isLoading = false;
      });
    }
  }

  /// Cleans the markdown tags for readable TTS announcement
  String _getReadableTtsText(String md) {
    var text = md;
    text = text.replaceAll('#', '');
    text = text.replaceAll('*', '');
    text = text.replaceAll('-', '•');
    return text;
  }

  Future<void> _toggleTts() async {
    if (_isPlaying) {
      await TtsService().stop();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    } else {
      if (_content.isEmpty) return;
      setState(() => _isPlaying = true);
      
      final speechText = _getReadableTtsText(_content);
      
      // Speak the content and stop when done
      await TtsService().speak(speechText);
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  List<Widget> _renderMarkdown(String markdownText, bool isDark) {
    if (markdownText.isEmpty) {
      return [
        Text(
          "Empty journal content.",
          style: GoogleFonts.inter(color: AppColors.textMuted),
        )
      ];
    }

    final List<Widget> widgets = [];
    final lines = markdownText.split('\n');

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      if (trimmed.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text(
              trimmed.substring(2),
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryText,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
            child: Text(
              trimmed.substring(3),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.extrabold,
                color: isDark ? Colors.tealAccent : const Color(0xFF0D9488),
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14.0, bottom: 6.0),
            child: Text(
              trimmed.substring(4),
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        final cleanText = trimmed.substring(2);
        final isUser = cleanText.startsWith('**User**:');
        final isBuddy = cleanText.startsWith('**Buddy**:');
        
        Widget textWidget;
        if (isUser) {
          final content = cleanText.replaceAll('**User**:', '').trim();
          textWidget = Text.rich(
            TextSpan(
              text: 'User: ',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF3B82F6),
              ),
              children: [
                TextSpan(
                  text: content,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.normal,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          );
        } else if (isBuddy) {
          final content = cleanText.replaceAll('**Buddy**:', '').trim();
          textWidget = Text.rich(
            TextSpan(
              text: 'Buddy: ',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF10B981),
              ),
              children: [
                TextSpan(
                  text: content,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.normal,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          );
        } else {
          textWidget = Text(
            cleanText,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.primaryText,
            ),
          );
        }

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, right: 8.0),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryText.withOpacity(0.7),
                    ),
                  ),
                ),
                Expanded(child: textWidget),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Text(
              trimmed,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.primaryText,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final isDark = AppColors.primaryBackground == Colors.black;

        return Scaffold(
          backgroundColor: AppColors.primaryBackground,
          appBar: AppBar(
            backgroundColor: AppColors.primaryBackground,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.primaryText),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              widget.dateStr,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryText,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.volume_up : Icons.volume_mute,
                  color: _isPlaying ? Colors.green : AppColors.primaryText,
                ),
                onPressed: _toggleTts,
                tooltip: "Read Journal Aloud",
              ),
            ],
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryButton,
                  ),
                )
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _renderMarkdown(_content, isDark),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
