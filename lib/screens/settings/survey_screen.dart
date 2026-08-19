import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/colors.dart';
import '../../services/firebase_service.dart';
import '../../services/settings_service.dart';
import '../../services/notion_service.dart';
import '../../services/sound_service.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final _firebaseService = FirebaseService();
  final _notionService = NotionService();
  final _commentController = TextEditingController();
  
  int _selectedRating = -1; // 1 to 5 mapping to emojis
  String _selectedSubject = '';
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _emojis = [
    {'emoji': '😠', 'label': 'Angry', 'value': 1},
    {'emoji': '😟', 'label': 'Sad', 'value': 2},
    {'emoji': '😐', 'label': 'Neutral', 'value': 3},
    {'emoji': '🙂', 'label': 'Happy', 'value': 4},
    {'emoji': '😁', 'label': 'Very Happy', 'value': 5},
  ];

  final List<Map<String, dynamic>> _subjects = [
    {'icon': Icons.bug_report_outlined, 'label': 'Bug'},
    {'icon': Icons.chat_bubble_outline_rounded, 'label': 'Suggestion'},
    {'icon': Icons.article_outlined, 'label': 'Content'},
    {'icon': Icons.thumb_up_alt_outlined, 'label': 'Compliment'},
    {'icon': Icons.adjust_rounded, 'label': 'Other'},
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_selectedRating == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select your satisfaction rating.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_selectedSubject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please pick a subject.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _firebaseService.currentUser;
      final userId = user?.uid ?? 'anonymous';
      final email = user?.email ?? 'anonymous@easylens.com';
      final displayName = user?.displayName ?? 'Anonymous';
      final commentText = _commentController.text.trim();

      final feedbackData = {
        'userId': userId,
        'email': email,
        'displayName': displayName,
        'rating': _selectedRating,
        'subject': _selectedSubject,
        'comment': commentText,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // 1. Submit to Firestore Database
      if (_firebaseService.isFirebaseAvailable) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('feedbacks')
            .add(feedbackData);
      } else {
        // Fallback for offline/mock mode
        await Future.delayed(const Duration(milliseconds: 300));
        print('Mock saved feedback to firestore: $feedbackData');
      }

      // 2. Submit / Sync to Notion Database
      await _notionService.submitFeedbackToNotion(
        userId: userId,
        displayName: displayName,
        email: email,
        subject: _selectedSubject,
        rating: _selectedRating,
        comment: commentText,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Thank you for your feedback!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to submit feedback: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();
    final isDark = settings.isDarkMode;
    final isDefault = settings.selectedContrastTheme == 'Default' && !isDark;

    final headerTextColor = AppColors.primaryText;
    final contentTextColor = isDark ? Colors.white : (isDefault ? Colors.black : AppColors.primaryText);
    final secondaryTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: headerTextColor),
          onPressed: () {
            SoundService.playClick();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'Share your feedback!',
          style: GoogleFonts.inter(
            color: headerTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rating Header
              Text(
                'How satisfied are you with your experience today?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: contentTextColor,
                ),
              ),
              const SizedBox(height: 20),

              // Emoji Selection Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_emojis.length, (index) {
                  final item = _emojis[index];
                  final isSelected = _selectedRating == item['value'];
                  return GestureDetector(
                    onTap: () {
                      SoundService.playClick();
                      setState(() {
                        _selectedRating = item['value'] as int;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE8F5E9))
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected 
                              ? AppColors.primaryButton 
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        item['emoji'] as String,
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // Pick Subject Header
              Text(
                'Pick a subject and provide your feedback:',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: contentTextColor,
                ),
              ),
              const SizedBox(height: 12),

              // Subject List Options
              Column(
                children: _subjects.map((subj) {
                  final isSelected = _selectedSubject == subj['label'];
                  return GestureDetector(
                    onTap: () {
                      SoundService.playClick();
                      setState(() {
                        _selectedSubject = subj['label'] as String;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF)) 
                            : (isDark ? const Color(0xFF1E1E1E) : (isDefault ? Colors.white : AppColors.primaryBackground)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected 
                              ? AppColors.primaryButton 
                              : (isDark ? const Color(0xFF333333) : (isDefault ? const Color(0xFFE2E8F0) : AppColors.cardBorder)),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            subj['icon'] as IconData,
                            color: isSelected ? AppColors.primaryButton : secondaryTextColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            subj['label'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppColors.primaryButton : contentTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Text Field Header
              Text(
                'What would you like to share?',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: contentTextColor,
                ),
              ),
              const SizedBox(height: 12),

              // Description Text Field
              TextField(
                controller: _commentController,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                style: GoogleFonts.inter(color: contentTextColor),
                decoration: InputDecoration(
                  hintText: 'Enter your comments or suggestions here...',
                  hintStyle: GoogleFonts.inter(color: secondaryTextColor, fontSize: 13),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E1E) : (isDefault ? Colors.white : AppColors.primaryBackground),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF333333) : (isDefault ? const Color(0xFFE2E8F0) : AppColors.cardBorder),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF333333) : (isDefault ? const Color(0xFFE2E8F0) : AppColors.cardBorder),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppColors.primaryButton,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () {
                    SoundService.playClick();
                    _submitFeedback();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButton,
                    foregroundColor: AppColors.primaryButtonText,
                    disabledBackgroundColor: Colors.grey.shade800,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: AppColors.primaryButtonText,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Submit Feedback',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
