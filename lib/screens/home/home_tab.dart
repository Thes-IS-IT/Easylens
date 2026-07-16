import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../hardware/hardware_screen.dart';
import '../image_labeling/image_labeling_screen.dart';
import '../rag_assistant/rag_assistant_screen.dart';
import '../../utils/app_route.dart';

class HomeTab extends StatelessWidget {
  final String displayName;

  const HomeTab({
    super.key,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header Card with Mascot
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: AppColors.primaryText,
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: [BoxShadow(
                  color: AppColors.shadowColor,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                )],
            ),
            child: Row(
              children: [
                // Happy Mascot gif
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/Mascots/01 Happy.gif',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/Mascots/App Mascot.png',
                        fit: BoxFit.contain,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello,',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        displayName,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Buddy is ready to assist you!",
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          Text(
            'Vision & Assistant Tools',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 16),

          // Tool 2: ML Kit Labeling
          _buildFeatureCard(
            context: context,
            title: 'Google ML Kit Labeler',
            subtitle: 'Extract general object tags and confidence scores.',
            icon: Icons.label_outline,
            accentColor: const Color(0xFF2196F3),
            onTap: () {
              Navigator.of(context).push(
                AppRoute.to(const ImageLabelingScreen()),
              );
            },
          ),
          const SizedBox(height: 16),

          // Tool 3: RAG Assistant
          _buildFeatureCard(
            context: context,
            title: 'RAG Buddy Chatbot',
            subtitle: 'Chat offline with Gemma 2B using local knowledge base.',
            icon: Icons.forum_outlined,
            accentColor: AppColors.welcomeAccentGold,
            onTap: () {
              Navigator.of(context).push(
                AppRoute.to(const RagAssistantScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: AppColors.unselectedBorder.withOpacity(0.5)),
        boxShadow: [BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 8,
            offset: Offset(0, 2),
          )],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20.0),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.primaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
