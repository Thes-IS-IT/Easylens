import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../services/settings_service.dart';

class MascotBanner extends StatefulWidget {
  final double bannerHeight;
  final double mascotLeft;
  final double mascotTop;
  final double mascotBottom;
  final double mascotWidth;
  final String mascotAsset;

  const MascotBanner({
    super.key,
    this.bannerHeight = 120, // Height of the card banner stripe S01
    this.mascotLeft = 24,
    this.mascotTop = -15,     // Negative offset to overlap/exit the top S01
    this.mascotBottom = -45,  // Pushes the mascot down to crop the bottom inside the banner S01
    this.mascotWidth = 145,   // Large width S01
    this.mascotAsset = 'assets/Mascots/05 Welcome.gif',
  });

  @override
  State<MascotBanner> createState() => _MascotBannerState();
}

class _MascotBannerState extends State<MascotBanner> {
  bool _isExpanded = false;
  int _activeMessageIndex = 0;

  // 20 sweet persona messages from Buddy the guide dog in English S01
  static const List<String> _sweetMessagesEn = [
    "I'm actively scanning your surroundings. Stay safe, buddy!",
    "You are doing amazing today! Let's explore the world together.",
    "No matter where we walk, I've got your back. Lead the way!",
    "Your safety is my number one priority. Let's step out confidently!",
    "The world is full of beauty, and I'm happy to help you find it.",
    "Ready for our next adventure? Grab your glasses and let's go!",
    "You make every journey look easy. Keep walking strong!",
    "Take it step by step, I will warn you of any obstacles ahead.",
    "I'm so lucky to be your virtual service companion!",
    "Trust your steps. I'm keeping a close eye on the path for you.",
    "You inspire me! Let's conquer the roads together today.",
    "Step carefully, breathe gently. We are navigating perfectly.",
    "Always remember, you are never walking alone. I'm right here!",
    "Keep that wonderful smile on! The road ahead is clear and beautiful.",
    "Let's check out some new places! I'll guide you step by step.",
    "I am here to guide your path and keep you safe from hazards.",
    "Every step you take is a step toward greater independence!",
    "You are unstoppable! Let's make today a safe and wonderful day.",
    "Your guide buddy is ready! Tell me where you'd love to explore next.",
    "Breathe in the fresh air, trust your direction, and enjoy the walk!",
  ];

  // 20 sweet persona messages from Buddy in Tagalog S01
  static const List<String> _sweetMessagesTl = [
    "Kasalukuyan kong sinusuri ang iyong paligid. Mag-ingat ka, kaibigan!",
    "Mahusay ang ginagawa mo ngayon! Sabay nating galugarin ang mundo.",
    "Saan man tayo maglakad, kasama mo ako. Ikaw ang mamuno!",
    "Ang iyong kaligtasan ang aking pangunahing priyoridad. Maglakad tayo nang may tiwala!",
    "Puno ng kagandahan ang mundo, at masaya akong tulungan kang mahanap ito.",
    "Handa na ba para sa susunod nating pakikipagsapalaran? Kunin ang iyong salamin at tara na!",
    "Pinapadali mo ang bawat lakbayin. Patuloy na maglakad nang matatag!",
    "Dahan-dahan lang, babalaan kita sa anumang mga harang sa harap.",
    "Napakaswerte ko na maging iyong virtual na kasamang gabay!",
    "Magtiwala sa iyong mga hakbang. Nakabantay ako sa landas para sa iyo.",
    "Binibigyan mo ako ng inspirasyon! Sabay nating lakbayin ang mga daan ngayon.",
    "Humakbang nang maingat, huminga nang malalim. Perpekto ang ating paglalakbay.",
    "Laging tandaan, hindi ka nag-iisa sa paglalakad. Narito lang ako!",
    "Panatilihin ang magandang ngiti na iyan! Malinis at maganda ang daan sa harap.",
    "Tuklasin natin ang mga bagong lugar! Gagabayan kita step by step.",
    "Narito ako para gabayan ang iyong landas at iligtas ka sa mga panganib.",
    "Ang bawat hakbang mo ay hakbang patungo sa higit na kalayaan!",
    "Walang makakapigil sa iyo! Gawin nating ligtas at kahanga-hanga ang araw na ito.",
    "Handa na ang iyong gabay! Sabihin mo sa akin kung saan mo gustong maglakbay susunod.",
    "Langhapin ang sariwang hangin, magtiwala sa iyong direksyon, at tamasahin ang lakad!",
  ];

  @override
  void initState() {
    super.initState();
    _activeMessageIndex = Random().nextInt(_sweetMessagesEn.length);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, child) {
        final settings = SettingsService();
        final theme = settings.selectedContrastTheme;
        final isDefault = theme == 'Default';
        final isBlack = settings.appearanceTheme == 'Black';

        final isFilipino = settings.selectedLanguage.toLowerCase().contains('tagalog') || settings.selectedLanguage.toLowerCase().contains('filipino');
        final activeMessage = isFilipino 
            ? _sweetMessagesTl[_activeMessageIndex] 
            : _sweetMessagesEn[_activeMessageIndex];

        final bannerColor = isDefault 
            ? const Color(0xFF3B82F6) 
            : AppColors.primaryButton;
            
        final isWhiteBanner = bannerColor == Colors.white || theme == 'Black on White';

        final bubbleBg = isWhiteBanner 
            ? const Color(0xFFF1F5F9) 
            : Colors.white;
            
        final headerColor = const Color(0xFF002663);
            
        final subtextColor = const Color(0xFF334155);

        final bannerBorder = isDefault
            ? null
            : Border(
                top: BorderSide(color: isWhiteBanner ? Colors.grey.shade300 : AppColors.cardBorder, width: 1.5),
                bottom: BorderSide(color: isWhiteBanner ? Colors.grey.shade300 : AppColors.cardBorder, width: 1.5),
              );

        final bubbleBorder = isDefault
            ? null
            : Border.all(color: isWhiteBanner ? Colors.grey.shade400 : AppColors.cardBorder, width: 1.5);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: _isExpanded ? widget.bannerHeight + 40 : widget.bannerHeight,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none, // Allows the mascot top overflow to be visible S01
            children: [
              // 1. The Blue Banner Container (stretches full-bleed, flat rect S01)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: bannerColor,
                    border: bannerBorder,
                  ),
                ),
              ),

              // 2. Decorative subtle circles for visual interest (Default only)
              if (isDefault) ...[
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  left: 100,
                  bottom: -40,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
              ],

              // 2. Rotated Speech Bubble Pointer (positioned relative to dog size)
              Positioned(
                left: widget.mascotLeft + widget.mascotWidth - 10,
                top: widget.bannerHeight / 2 - 6,
                child: RotationTransition(
                  turns: const AlwaysStoppedAnimation(45 / 360),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: bubbleBg,
                      border: isDefault ? null : Border(
                        left: BorderSide(color: AppColors.cardBorder, width: 1.5),
                        bottom: BorderSide(color: AppColors.cardBorder, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Speech Bubble Card (positioned relative to dog size)
              Positioned(
                left: widget.mascotLeft + widget.mascotWidth - 4,
                right: 24,
                top: 12,
                bottom: 12,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    borderRadius: BorderRadius.circular(16),
                    border: bubbleBorder,
                    boxShadow: isDefault ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      )
                    ] : null,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Buddy',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: headerColor,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 200),
                          crossFadeState: _isExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: Text(
                            activeMessage,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: subtextColor,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                          secondChild: Text(
                            activeMessage,
                            style: GoogleFonts.inter(
                              color: subtextColor,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Mascot Image (positioned in the left offset, overlapping top boundary S01)
              Positioned(
                left: widget.mascotLeft,
                top: widget.mascotTop,
                bottom: widget.mascotBottom,
                width: widget.mascotWidth,
                child: Image.asset(
                  widget.mascotAsset,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
