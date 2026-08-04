import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../services/notification_service.dart';
import '../../../services/esp32_service.dart';
import '../../notifications/notifications_screen.dart';
import '../../contacts/contacts_screen.dart';
import '../../settings/settings_screen.dart';
import '../../../utils/app_route.dart';

class PairingWizard extends StatelessWidget {
  final int pairStep;
  final VoidCallback onInitializeCamera;
  final VoidCallback onAddDevice;
  final VoidCallback onStartPairing;
  final VoidCallback onCancelOrBack;

  const PairingWizard({
    super.key,
    required this.pairStep,
    required this.onInitializeCamera,
    required this.onAddDevice,
    required this.onStartPairing,
    required this.onCancelOrBack,
  });

  @override
  Widget build(BuildContext context) {
    switch (pairStep) {
      case 1:
        return _buildMainScreen(context);
      case 2:
        return _buildPairingStartScreen(context);
      case 3:
        return _buildScanningScreen(context);
      default:
        return _buildMainScreen(context);
    }
  }

  Widget _buildMainScreen(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  'SOS',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    ListenableBuilder(
                      listenable: NotificationService(),
                      builder: (ctx, _) {
                        final unread = NotificationService().unreadCount;
                        return Badge(
                          isLabelVisible: unread > 0,
                          label: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(fontSize: 9, color: Colors.white),
                          ),
                          backgroundColor: const Color(0xFFDC2626),
                          child: IconButton(
                            icon: Icon(
                              unread > 0
                                  ? Icons.notifications_active
                                  : Icons.notifications_none,
                              size: 20,
                              color: unread > 0 ? const Color(0xFFDC2626) : null,
                            ),
                            onPressed: () => Navigator.push(context, AppRoute.to(const NotificationsScreen())),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.people_outline, size: 20),
                      onPressed: () => Navigator.push(context, AppRoute.to(const ContactsScreen())),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    ListenableBuilder(
                      listenable: Esp32Service(),
                      builder: (ctx, _) {
                        final connected = Esp32Service().isConnected;
                        return IconButton(
                          icon: Icon(
                            connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                            size: 20,
                            color: connected ? const Color(0xFF10B981) : null,
                          ),
                          onPressed: () => Navigator.push(context, AppRoute.to(const SettingsScreen())),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          tooltip: connected ? 'Glasses connected' : 'Connect glasses',
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, size: 20),
                      onPressed: () => Navigator.push(context, AppRoute.to(const SettingsScreen())),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'EasyLens Glasses',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pair your glasses to unlock a new dimension of augmented reality. Once connected, your lightweight smart glasses will work seamlessly with your Buddy hardware to project real-time information, interactive filters, and custom AR elements directly into your field of view.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/easylens.JPG',
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.lightBackground,
                height: 220,
                child: Icon(Icons.image_not_supported, size: 48, color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryText,
                      backgroundColor: AppColors.lightBackground,
                      side: BorderSide(color: AppColors.cardBorder, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                    onPressed: onInitializeCamera,
                    icon: Icon(Icons.camera_alt_outlined, size: 20, color: AppColors.primaryText),
                    label: Text(
                      'Use Camera',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryButton,
                      foregroundColor: AppColors.primaryButtonText,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      elevation: 0,
                    ),
                    onPressed: onAddDevice,
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(
                      'Add Device',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPairingStartScreen(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SOS',
              style: GoogleFonts.inter(
                color: Colors.transparent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black54, size: 18),
                onPressed: onCancelOrBack,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Text(
                'EasyLens Glasses',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF002663),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Start pairing your EasyLens Glasses to the Buddy app. Click on Start pairing process to start pairing your EasyLens Glasses with the Buddy app.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Image.asset(
                'assets/images/mockup_glasses.png',
                width: 280,
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade100,
                  width: 280,
                  height: 180,
                  child: const Icon(Icons.image_not_supported, size: 48),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF002663),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              elevation: 0,
            ),
            onPressed: onStartPairing,
            child: Text(
              'Start pairing process',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanningScreen(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF002663),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.black.withOpacity(0.06)),
              ),
            ),
            onPressed: onCancelOrBack,
            icon: const Icon(Icons.arrow_back_ios, size: 16),
            label: Text(
              'Back',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const Spacer(),
        Image.asset(
          'assets/Mascots/03 Loading.gif',
          width: 180,
          height: 180,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const CircularProgressIndicator(),
        ),
        const SizedBox(height: 36),
        Text(
          'Searching for Glasses',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF002663),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Ensure your EasyLens glasses are turned on, fully charged, and near your phone.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF002663),
              side: const BorderSide(color: Color(0xFF002663), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            onPressed: onCancelOrBack,
            child: Text(
              'Cancel Search',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
