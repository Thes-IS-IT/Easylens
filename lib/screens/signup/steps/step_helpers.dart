import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';

// --- SHARED HELPER WIDGETS ---

class StepHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  StepHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryText,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AppColors.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// Custom Option Card for single/multiple selection
class OptionCard extends StatelessWidget {
  final String title;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const OptionCard({
    super.key,
    required this.title,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryButton : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isSelected ? AppColors.primaryButton : AppColors.cardBorder.withOpacity(0.3),
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryButton.withOpacity(0.22),
                    blurRadius: 12.0,
                    offset: const Offset(0, 6),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6.0,
                    offset: const Offset(0, 3),
                  )
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 26,
                  color: isSelected ? AppColors.primaryButtonText : AppColors.primaryText,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.primaryButtonText : AppColors.primaryText,
                  ),
                ),
              ],
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primaryButtonText : AppColors.primaryText,
                  width: 2.0,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 16, color: AppColors.primaryButtonText,)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
