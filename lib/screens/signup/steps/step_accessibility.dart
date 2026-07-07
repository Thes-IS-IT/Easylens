import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'step_helpers.dart';

// STEP 4: Accessibility
class StepAccessibility extends StatelessWidget {
  final bool voiceFeedback;
  final bool hapticFeedback;
  final ValueChanged<bool> onVoiceChanged;
  final ValueChanged<bool> onHapticChanged;

  const StepAccessibility({
    super.key,
    required this.voiceFeedback,
    required this.hapticFeedback,
    required this.onVoiceChanged,
    required this.onHapticChanged,
  });

  Widget _buildAccessibilityCard({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF002663),
            ),
          ),
          Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF002663),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE2E8F0),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: 'Accessibility',
          subtitle: 'Configure cognitive feedback mechanisms below.',
        ),
        const SizedBox(height: 32),
        _buildAccessibilityCard(
          title: 'Voice Feedback',
          value: voiceFeedback,
          onChanged: onVoiceChanged,
        ),
        const SizedBox(height: 16),
        _buildAccessibilityCard(
          title: 'Haptic Feedback',
          value: hapticFeedback,
          onChanged: onHapticChanged,
        ),
      ],
    );
  }
}
