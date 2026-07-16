import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../hardware_screen.dart'; // import HudMode

class HudModeSelector extends StatelessWidget {
  final HudMode selectedHudMode;
  final Function(HudMode) onModeChanged;

  const HudModeSelector({
    super.key,
    required this.selectedHudMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BUDDY MODE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildModeButton(HudMode.navigation, 'Nav', Icons.directions_walk, const Color(0xFF1E88E5)),
              const SizedBox(width: 4),
              _buildModeButton(HudMode.objectDetection, 'Objects', Icons.radar, const Color(0xFF43A047)),
              const SizedBox(width: 4),
              _buildModeButton(HudMode.scenery, 'Scenery', Icons.photo_size_select_actual, const Color(0xFFF4511E)),
              const SizedBox(width: 4),
              _buildModeButton(HudMode.faceRecognition, 'Faces', Icons.face_retouching_natural, const Color(0xFF7C3AED)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(HudMode mode, String label, IconData icon, Color activeColor) {
    final isSelected = selectedHudMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => onModeChanged(mode),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.transparent : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.black54,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
