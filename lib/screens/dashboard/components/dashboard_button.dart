import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../services/settings_service.dart';
import '../../../services/sound_service.dart';

class DashboardButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? connectivityBadge;
  final bool? isOnline;
  final IconData? badgeIcon;

  const DashboardButton({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.connectivityBadge,
    this.isOnline,
    this.badgeIcon,
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
      bg = AppColors.primaryButton;
      fg = AppColors.primaryButtonText;
      border = BorderSide(
        color: theme == 'Black on White'
            ? Colors.black.withValues(alpha: 0.25)
            : AppColors.cardBorder.withValues(alpha: 0.6),
        width: 1.5,
      );
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
          onPressed: () {
            SoundService.playClick();
            onTap();
          },
          child: Row(
            children: [
              Icon(icon, size: 24, color: fg),
              const SizedBox(width: 16),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: fg,
                    ),
                  ),
                ),
              ),
              if (connectivityBadge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: fg.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        badgeIcon ??
                            (connectivityBadge!.toLowerCase().contains('sms')
                                ? Icons.sms_outlined
                                : connectivityBadge!.toLowerCase().contains('hybrid')
                                    ? Icons.swap_horiz_rounded
                                    : (isOnline == true
                                        ? Icons.cloud_outlined
                                        : Icons.offline_bolt_outlined)),
                        size: 11,
                        color: fg,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        connectivityBadge!,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
