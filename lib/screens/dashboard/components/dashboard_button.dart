import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../services/settings_service.dart';

class DashboardButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const DashboardButton({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SettingsService().selectedContrastTheme;
    final isDefault = theme == 'Default';

    Color bg;
    Color fg;
    BorderSide border;

    if (isDefault) {
      bg = color;
      fg = Colors.white;
      border = BorderSide.none;
    } else {
      bg = AppColors.primaryBackground;
      fg = AppColors.primaryText;
      border = BorderSide(color: AppColors.cardBorder, width: 2.0);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
              side: border,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          onPressed: onTap,
          child: Row(
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
