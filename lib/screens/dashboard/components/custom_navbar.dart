import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../services/settings_service.dart';
import '../../../services/sound_service.dart';

class CustomNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onEasyLensTap;
  final GlobalKey? navKey;
  final GlobalKey? easylensKey;

  const CustomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onEasyLensTap,
    this.navKey,
    this.easylensKey,
  });

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();
    final theme = settings.selectedContrastTheme;
    final isDefault = theme == 'Default';

    final navBg = isDefault ? Colors.white : AppColors.primaryBackground;
    final navBorderColor = isDefault ? Colors.black.withOpacity(0.04) : AppColors.cardBorder;
    final visibilityBtnBg = isDefault ? Colors.white : AppColors.primaryBackground;
    final visibilityIconColor = isDefault ? Colors.black : AppColors.primaryText;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
      child: Row(
        children: [
          // Main floating navbar pill
          Expanded(
            child: Container(
              height: 74,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: navBg,
                borderRadius: BorderRadius.circular(37),
                border: Border.all(
                  color: navBorderColor,
                  width: 1.5,
                ),
                boxShadow: isDefault ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ] : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildNavbarItem(
                      index: 0,
                      icon: Icons.home_outlined,
                      label: 'Home',
                    ),
                  ),
                  Expanded(
                    key: navKey,
                    child: _buildNavbarItem(
                      index: 1,
                      icon: Icons.navigation_outlined,
                      label: 'Nav',
                    ),
                  ),
                  Expanded(
                    key: easylensKey,
                    child: _buildNavbarItem(
                      index: 2,
                      icon: Icons.sensors,
                      label: 'EasyLens',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Floating Circular Action Button on the right
          GestureDetector(
            onTap: () {
              SoundService.playClick();
              onEasyLensTap();
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: visibilityBtnBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: navBorderColor,
                  width: 1.5,
                ),
                boxShadow: isDefault ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ] : null,
              ),
              child: Center(
                child: Icon(
                  Icons.visibility_outlined,
                  color: visibilityIconColor,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavbarItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final settings = SettingsService();
    final theme = settings.selectedContrastTheme;
    final isDefault = theme == 'Default';
    final isSelected = currentIndex == index;

    Color bg;
    Color fg;
    Color unselectedFg;

    if (isDefault) {
      bg = isSelected ? const Color(0xFFECEFF1) : Colors.transparent;
      fg = isSelected ? const Color(0xFF1E88E5) : Colors.black;
      unselectedFg = Colors.black;
    } else {
      bg = isSelected ? AppColors.primaryButton : Colors.transparent;
      fg = isSelected ? AppColors.primaryButtonText : AppColors.primaryText;
      unselectedFg = AppColors.primaryText;
    }

    return GestureDetector(
      onTap: () {
        SoundService.playClick();
        onTap(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(31),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? fg : unselectedFg,
              size: 24,
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? fg : unselectedFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
