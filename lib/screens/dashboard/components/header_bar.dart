import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../services/settings_service.dart';

class HeaderBar extends StatelessWidget {
  final VoidCallback onSOSSelected;
  final VoidCallback onSettingsSelected;
  final VoidCallback onNotificationsSelected;
  final VoidCallback onContactsSelected;

  const HeaderBar({
    super.key,
    required this.onSOSSelected,
    required this.onSettingsSelected,
    required this.onNotificationsSelected,
    required this.onContactsSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SettingsService().selectedContrastTheme;
    final isDefault = theme == 'Default';
    
    final pillBg = isDefault ? Colors.white : AppColors.primaryBackground;
    final iconColor = isDefault ? const Color(0xFF002663) : AppColors.primaryText;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // SOS button
        GestureDetector(
          onTap: onSOSSelected,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDefault ? const Color(0xFFE53E3E) : AppColors.primaryButton,
              borderRadius: BorderRadius.circular(12),
              border: isDefault ? null : Border.all(color: AppColors.cardBorder, width: 1.5),
            ),
            child: Text(
              'SOS',
              style: TextStyle(
                color: isDefault ? Colors.white : AppColors.primaryButtonText,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ),
        
        // Settings / profiles float pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(30),
            border: isDefault ? null : Border.all(color: AppColors.cardBorder, width: 1.5),
            boxShadow: isDefault ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_none, color: iconColor),
                onPressed: onNotificationsSelected,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              IconButton(
                icon: Icon(Icons.people_outline, color: iconColor),
                onPressed: onContactsSelected, // Wired contacts screen trigger
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              IconButton(
                icon: Icon(Icons.settings_outlined, color: iconColor),
                onPressed: onSettingsSelected,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
