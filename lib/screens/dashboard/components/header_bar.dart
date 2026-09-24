import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../services/settings_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/sound_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../widgets/system_status_modal.dart';

class HeaderBar extends StatelessWidget {
  final VoidCallback onSOSSelected;
  final VoidCallback onSettingsSelected;
  final VoidCallback onNotificationsSelected;
  final VoidCallback onContactsSelected;
  final GlobalKey? sosKey;
  final GlobalKey? settingsKey;
  final GlobalKey? notificationsKey;
  final GlobalKey? contactsKey;

  const HeaderBar({
    super.key,
    required this.onSOSSelected,
    required this.onSettingsSelected,
    required this.onNotificationsSelected,
    required this.onContactsSelected,
    this.sosKey,
    this.settingsKey,
    this.notificationsKey,
    this.contactsKey,
  });

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();
    final theme = settings.selectedContrastTheme;
    final isDark = settings.isDarkMode;
    final isDefault = theme == 'Default' && !isDark;
    
    final pillBg = isDark ? const Color(0xFF1E1E1E) : (isDefault ? Colors.white : AppColors.primaryBackground);
    final iconColor = isDark ? Colors.white : (isDefault ? const Color(0xFF002663) : AppColors.primaryText);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // SOS button
        GestureDetector(
          key: sosKey,
          onTap: () {
            SoundService.playClick();
            onSOSSelected();
          },
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

        // Online / Offline Status Pill
        ListenableBuilder(
          listenable: ConnectivityService(),
          builder: (context, _) {
            final isOnline = ConnectivityService().isOnline;
            return GestureDetector(
              onTap: () {
                SoundService.playClick();
                SystemStatusModal.show(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isOnline
                      ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                      : (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOnline
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isOnline
                            ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46))
                            : (isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        
        // Settings / profiles float pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(30),
            border: isDark ? Border.all(color: const Color(0xFF333333), width: 1.5) : (isDefault ? null : Border.all(color: AppColors.cardBorder, width: 1.5)),
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
              ListenableBuilder(
                listenable: NotificationService(),
                builder: (context, _) {
                  final service = NotificationService();
                  final count = service.unreadCount;
                  
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        key: notificationsKey,
                        icon: Icon(
                          count > 0 ? Icons.notifications : Icons.notifications_none, 
                          color: count > 0 ? const Color(0xFFEF4444) : iconColor,
                        ),
                        onPressed: () {
                          SoundService.playClick();
                          onNotificationsSelected();
                        },
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      if (count > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Center(
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                key: contactsKey,
                icon: Icon(Icons.people_outline, color: iconColor),
                onPressed: () {
                  SoundService.playClick();
                  onContactsSelected();
                },
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              IconButton(
                key: settingsKey,
                icon: Icon(Icons.settings_outlined, color: iconColor),
                onPressed: () {
                  SoundService.playClick();
                  onSettingsSelected();
                },
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
