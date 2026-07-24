import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/danger_warning_service.dart';

class CriticalDangerOverlay extends StatefulWidget {
  final HazardSeverity severity;
  final String title;
  final String message;
  final String hazardName;
  final VoidCallback onDismiss;
  final VoidCallback onReannounce;
  final VoidCallback? onEmergencyCall;

  const CriticalDangerOverlay({
    super.key,
    required this.severity,
    required this.title,
    required this.message,
    required this.hazardName,
    required this.onDismiss,
    required this.onReannounce,
    this.onEmergencyCall,
  });

  @override
  State<CriticalDangerOverlay> createState() => _CriticalDangerOverlayState();
}

class _CriticalDangerOverlayState extends State<CriticalDangerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _triggerStrongWarningVibration();
  }

  void _triggerStrongWarningVibration() {
    DangerWarningService().triggerStrongHazardVibration(
      isCritical: widget.severity == HazardSeverity.critical,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCritical = widget.severity == HazardSeverity.critical;

    final primaryColor = isCritical ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    final accentBg = isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    final hazardInfo = DangerWarningService().getHazardInfo(widget.hazardName);
    final iconData = hazardInfo.icon;


    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primaryColor, width: isCritical ? 3.0 : 2.0),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(isCritical ? 0.35 : 0.20),
              blurRadius: isCritical ? 20 : 12,
              spreadRadius: isCritical ? 4 : 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isCritical ? "CRITICAL HAZARD DETECTED" : "SAFETY CAUTION",
                          style: GoogleFonts.inter(
                            color: primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onDismiss,
                  icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 24),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // High Visibility Red AVOID Warning Pill for Critical Hazards
            if (isCritical) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.do_not_disturb_on_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "STOP & AVOID AREA IMMEDIATELY",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Warning Description Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryColor.withOpacity(0.25)),
              ),
              child: Text(
                widget.message,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isCritical ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                  height: 1.35,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons Row
            Row(
              children: [
                // Re-announce TTS
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: widget.onReannounce,
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  label: Text(
                    "Speak",
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(width: 8),

                // Emergency Call (if critical)
                if (isCritical && widget.onEmergencyCall != null) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: widget.onEmergencyCall,
                      icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                      label: Text(
                        "SOS CALL",
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Safe / Dismiss Button
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryColor, width: 1.5),
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: widget.onDismiss,
                    child: Text(
                      "Dismiss",
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
