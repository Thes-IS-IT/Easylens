import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class HudControlsPanel extends StatelessWidget {
  final int batteryPercent;
  final bool isBluetoothConnected;
  final bool isGeminiEnabled;
  final bool isWifiOn;
  final bool isAudioSpeaker;
  final bool isScreenLocked;
  final bool useLocalAI;
  final bool isContinuousVoiceEnabled;

  final VoidCallback onBluetoothToggled;
  final VoidCallback onGeminiToggled;
  final VoidCallback onWifiToggled;
  final VoidCallback onAudioToggled;
  final VoidCallback onLockToggled;
  final VoidCallback onLocalAiToggled;

  const HudControlsPanel({
    super.key,
    required this.batteryPercent,
    required this.isBluetoothConnected,
    required this.isGeminiEnabled,
    required this.isWifiOn,
    required this.isAudioSpeaker,
    required this.isScreenLocked,
    required this.useLocalAI,
    required this.isContinuousVoiceEnabled,
    required this.onBluetoothToggled,
    required this.onGeminiToggled,
    required this.onWifiToggled,
    required this.onAudioToggled,
    required this.onLockToggled,
    required this.onLocalAiToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230, // Fixed height for visual consistency S01
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -4))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Pull indicator line
          Center(
            child: Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Custom Vertical Battery cylinder on the left S01
                      Container(
                        width: 105,
                        height: 215,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            FractionallySizedBox(
                              heightFactor: batteryPercent / 100.0,
                              widthFactor: 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: const Radius.circular(30),
                                    bottomRight: const Radius.circular(30),
                                    topLeft: batteryPercent >= 95 ? const Radius.circular(30) : Radius.zero,
                                    topRight: batteryPercent >= 95 ? const Radius.circular(30) : Radius.zero,
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$batteryPercent%',
                                      style: GoogleFonts.inter(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        shadows: [
                                          const Shadow(
                                            offset: Offset(0, 1.5),
                                            blurRadius: 3,
                                            color: Colors.black38,
                                          )
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Battery',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        shadows: [
                                          const Shadow(
                                            offset: Offset(0, 1.5),
                                            blurRadius: 3,
                                            color: Colors.black38,
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Scrollable 2x2 grid panel on the right S01
                      Expanded(
                        child: SizedBox(
                          height: 215,
                          child: GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.0,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              // EasyLens Connected (Bluetooth)
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

                              // Gemini AI Toggle
                              _buildControlBox(
                                title: 'Gemini',
                                subtitle: (isContinuousVoiceEnabled && !useLocalAI) ? 'Active' : 'Disable',
                                icon: Icons.auto_awesome,
                                activeBgColor: const Color(0xFFD69E2E),
                                inactiveBgColor: const Color(0xFFEDF2F7),
                                activeTextColor: Colors.white,
                                inactiveTextColor: const Color(0xFF2D3748),
                                isActive: isContinuousVoiceEnabled && !useLocalAI,
                                onTap: onGeminiToggled,
                              ),

                              // Local AI Toggle
                              _buildControlBox(
                                title: 'Local AI',
                                subtitle: (isContinuousVoiceEnabled && useLocalAI) ? 'Active' : 'Disable',
                                icon: Icons.offline_bolt_outlined,
                                activeBgColor: const Color(0xFF8B5CF6),
                                inactiveBgColor: const Color(0xFFEDF2F7),
                                activeTextColor: Colors.white,
                                inactiveTextColor: const Color(0xFF2D3748),
                                isActive: isContinuousVoiceEnabled && useLocalAI,
                                onTap: onLocalAiToggled,
                              ),

                              // Audio Route Toggle
                              _buildControlBox(
                                title: 'Audio',
                                subtitle: isAudioSpeaker ? 'Speaker' : 'Glasses',
                                icon: Icons.volume_up,
                                activeBgColor: const Color(0xFF3182CE),
                                inactiveBgColor: const Color(0xFFEDF2F7),
                                activeTextColor: Colors.white,
                                inactiveTextColor: const Color(0xFF2D3748),
                                isActive: isAudioSpeaker,
                                onTap: onAudioToggled,
                              ),

                              // Network / Wifi Toggle
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

                              // Lock Mode Toggle S01
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
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? activeBgColor : inactiveBgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? Colors.transparent : Colors.black.withOpacity(0.04),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: isActive ? activeTextColor : const Color(0xFF475569),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isActive ? activeTextColor : const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
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
