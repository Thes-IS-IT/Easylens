import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class HudControlsPanel extends StatelessWidget {
  final int? batteryPercent;
  final bool isBluetoothConnected;
  final bool isGeminiEnabled;
  final bool isWifiOn;
  final bool isAudioSpeaker;
  final bool isScreenLocked;
  final bool useLocalAI;
  final bool isContinuousVoiceEnabled;
  final bool isFlashOn;
  final bool useMobileCamera;
  final bool isDetectionPaused;

  final VoidCallback onBluetoothToggled;
  final VoidCallback onGeminiToggled;
  final VoidCallback onWifiToggled;
  final VoidCallback onAudioToggled;
  final VoidCallback onLockToggled;
  final VoidCallback onLocalAiToggled;
  final VoidCallback? onFlashToggled;
  final VoidCallback? onCameraSourceToggled;
  final VoidCallback? onDetectionToggled;

  final Widget modeSelector;
  final Widget disconnectButton;

  const HudControlsPanel({
    super.key,
    this.batteryPercent,
    required this.isBluetoothConnected,
    required this.isGeminiEnabled,
    required this.isWifiOn,
    required this.isAudioSpeaker,
    required this.isScreenLocked,
    required this.useLocalAI,
    required this.isContinuousVoiceEnabled,
    this.isFlashOn = false,
    this.useMobileCamera = false,
    this.isDetectionPaused = false,
    required this.onBluetoothToggled,
    required this.onGeminiToggled,
    required this.onWifiToggled,
    required this.onAudioToggled,
    required this.onLockToggled,
    required this.onLocalAiToggled,
    this.onFlashToggled,
    this.onCameraSourceToggled,
    this.onDetectionToggled,
    required this.modeSelector,
    required this.disconnectButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pull indicator line
          Center(
            child: Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Scrollable content area
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // 3x3 Command Control Grid (9 items, 3 columns)
                SizedBox(
                  height: 280, // Height for 3x3 grid items
                  child: GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.1,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // 1. EasyLens Connected (Bluetooth)
                      _buildControlBox(
                        title: 'EasyLens',
                        subtitle: isBluetoothConnected ? 'Connected' : 'Disconnected',
                        icon: Icons.bluetooth,
                        activeBgColor: const Color(0xFF2B6CB0),
                        inactiveBgColor: const Color(0xFFEDF2F7),
                        activeTextColor: Colors.white,
                        inactiveTextColor: const Color(0xFF2D3748),
                        isActive: isBluetoothConnected,
                        onTap: onBluetoothToggled,
                      ),

                      // 2. Gemini AI Toggle
                      _buildControlBox(
                        title: 'Gemini',
                        subtitle: (isContinuousVoiceEnabled && !useLocalAI) ? 'Active' : 'Disabled',
                        icon: Icons.auto_awesome,
                        activeBgColor: const Color(0xFFD69E2E),
                        inactiveBgColor: const Color(0xFFEDF2F7),
                        activeTextColor: Colors.white,
                        inactiveTextColor: const Color(0xFF2D3748),
                        isActive: isContinuousVoiceEnabled && !useLocalAI,
                        onTap: onGeminiToggled,
                      ),

                      // 3. Local AI Toggle
                      _buildControlBox(
                        title: 'Local AI',
                        subtitle: (isContinuousVoiceEnabled && useLocalAI) ? 'Active' : 'Disabled',
                        icon: Icons.offline_bolt_outlined,
                        activeBgColor: const Color(0xFF8B5CF6),
                        inactiveBgColor: const Color(0xFFEDF2F7),
                        activeTextColor: Colors.white,
                        inactiveTextColor: const Color(0xFF2D3748),
                        isActive: isContinuousVoiceEnabled && useLocalAI,
                        onTap: onLocalAiToggled,
                      ),

                      // 4. Audio Route Toggle
                      _buildControlBox(
                        title: 'Audio',
                        subtitle: isAudioSpeaker ? 'Speaker' : 'Glasses',
                        icon: isAudioSpeaker ? Icons.volume_up : Icons.headset,
                        activeBgColor: const Color(0xFF3182CE),
                        inactiveBgColor: const Color(0xFFEDF2F7),
                        activeTextColor: Colors.white,
                        inactiveTextColor: const Color(0xFF2D3748),
                        isActive: isAudioSpeaker,
                        onTap: onAudioToggled,
                      ),

                      // 5. Network / Wifi Toggle
                      _buildControlBox(
                        title: 'Network',
                        subtitle: isWifiOn ? 'On' : 'Off',
                        icon: Icons.wifi,
                        activeBgColor: const Color(0xFF3182CE),
                        inactiveBgColor: const Color(0xFFEDF2F7),
                        activeTextColor: Colors.white,
                        inactiveTextColor: const Color(0xFF2D3748),
                        isActive: isWifiOn,
                        onTap: onWifiToggled,
                      ),

                      // 6. Lock Mode Toggle
                      _buildControlBox(
                        title: 'Lock Mode',
                        subtitle: isScreenLocked ? 'Locked' : 'Unlocked',
                        icon: isScreenLocked ? Icons.lock : Icons.lock_open,
                        activeBgColor: const Color(0xFFEF4444),
                        inactiveBgColor: const Color(0xFFEDF2F7),
                        activeTextColor: Colors.white,
                        inactiveTextColor: const Color(0xFF2D3748),
                        isActive: isScreenLocked,
                        onTap: onLockToggled,
                      ),

                      // 7. Flashlight / Torch LED
                      _buildControlBox(
                        title: 'Flashlight',
                        subtitle: isFlashOn ? 'On' : 'Off',
                        icon: isFlashOn ? Icons.flash_on : Icons.flash_off,
                        activeBgColor: const Color(0xFFEAB308),
                        inactiveBgColor: const Color(0xFFEDF2F7),
                        activeTextColor: Colors.white,
                        inactiveTextColor: const Color(0xFF2D3748),
                        isActive: isFlashOn,
                        onTap: onFlashToggled ?? () {},
                      ),

                      // 8. Camera Source Toggle (Mobile / Glasses)
                      _buildControlBox(
                        title: 'Cam Mode',
                        subtitle: useMobileCamera ? 'Mobile' : 'Glasses',
                        icon: useMobileCamera ? Icons.smartphone : Icons.remove_red_eye,
                        activeBgColor: const Color(0xFF0D9488),
                        inactiveBgColor: const Color(0xFFEDF2F7),
                        activeTextColor: Colors.white,
                        inactiveTextColor: const Color(0xFF2D3748),
                        isActive: useMobileCamera,
                        onTap: onCameraSourceToggled ?? () {},
                      ),

                      // 9. Scanner Active / Pause Toggle
                      _buildControlBox(
                        title: 'Scanner',
                        subtitle: !isDetectionPaused ? 'Active' : 'Paused',
                        icon: !isDetectionPaused ? Icons.center_focus_strong : Icons.pause_circle_outline,
                        activeBgColor: const Color(0xFF10B981),
                        inactiveBgColor: const Color(0xFFEDF2F7),
                        activeTextColor: Colors.white,
                        inactiveTextColor: const Color(0xFF2D3748),
                        isActive: !isDetectionPaused,
                        onTap: onDetectionToggled ?? () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                modeSelector,
                const SizedBox(height: 12),
                disconnectButton,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBox({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color activeBgColor,
    required Color inactiveBgColor,
    required Color activeTextColor,
    required Color inactiveTextColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? activeBgColor : inactiveBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.transparent : Colors.black.withOpacity(0.04),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? activeTextColor : const Color(0xFF475569),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? activeTextColor : const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isActive ? activeTextColor.withOpacity(0.9) : const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
