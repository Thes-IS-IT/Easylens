import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import '../../../constants/colors.dart';
import '../../../services/settings_service.dart';

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

  void _triggerHaptic() {
    if (SettingsService().hapticFeedback) {
      try {
        Vibration.vibrate(duration: 40, amplitude: 255);
      } catch (_) {}
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();
    final theme = settings.selectedContrastTheme;
    final isDefault = theme == 'Default';

    final navBg = isDefault ? Colors.white : AppColors.primaryBackground;
    final navBorderColor = isDefault ? Colors.black.withOpacity(0.04) : AppColors.cardBorder;
    final visibilityBtnBg = isDefault ? Colors.white : AppColors.primaryBackground;
    final visibilityIconColor = isDefault ? const Color(0xFF002663) : AppColors.primaryText;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
      child: Row(
        children: [
          // Main floating navbar pill
          Expanded(
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: navBg,
                borderRadius: BorderRadius.circular(32),
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
              child: Row(
                children: [
                  _buildNavbarItem(
                    index: 0,
                    icon: Icons.home_rounded,
                    label: 'Home',
                  ),
                  _buildNavbarItem(
                    key: navKey,
                    index: 1,
                    icon: Icons.navigation_rounded,
                    label: 'Nav',
                  ),
                  _buildNavbarItem(
                    key: easylensKey,
                    index: 2,
                    icon: Icons.sensors_rounded,
                    label: 'EasyLens',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Floating Circular Action Button on the right
          GestureDetector(
            onTap: () {
              _triggerHaptic();
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
    Key? key,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final settings = SettingsService();
    final theme = settings.selectedContrastTheme;
    final isDefault = theme == 'Default';
    final isSelected = currentIndex == index;

    Color activeBg;
    Color activeFg;
    Color unselectedFg;

    if (isDefault) {
      activeBg = const Color(0xFFE3F2FD); // Light blue active pill background
      activeFg = const Color(0xFF1E88E5); // Vibrant blue text & icon
      unselectedFg = Colors.black87;
    } else {
      activeBg = AppColors.primaryButton;
      activeFg = AppColors.primaryButtonText;
      unselectedFg = AppColors.primaryText;
    }

    return Expanded(
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _triggerHaptic();
          onTap(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: (isSelected && isDefault)
                ? [
                    BoxShadow(
                      color: const Color(0xFF60A5FA).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? activeFg : unselectedFg,
                size: 22,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? activeFg : unselectedFg,
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
