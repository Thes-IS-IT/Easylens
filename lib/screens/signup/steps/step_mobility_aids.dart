import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'step_helpers.dart';

// STEP 8: Mobility Aids
class StepMobilityAids extends StatelessWidget {
  final String selectedAid;
  final ValueChanged<String> onChanged;

  StepMobilityAids({
    super.key,
    required this.selectedAid,
    required this.onChanged,
  });

  final List<String> aids = [
    'White Cane',
    'Guide Dog',
    'Smart Glasses',
    'Eyeglasses',
    'Wheelchair',
    'Walker',
    'Sighted Guide',
    'None',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: 'Mobility Aids',
          subtitle: 'Select the primary mobility assist tool in use by you.',
        ),
        const SizedBox(height: 24),
        Column(
          children: aids.map((aid) {
            final isSelected = selectedAid == aid;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: GestureDetector(
                onTap: () => onChanged(aid),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF002663) : Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF002663) : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      aid,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF002663),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
