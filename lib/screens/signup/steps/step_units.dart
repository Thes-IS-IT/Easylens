import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'step_helpers.dart';

// STEP 7: Units
class StepUnits extends StatelessWidget {
  final String selectedUnit;
  final ValueChanged<String> onChanged;

  const StepUnits({
    super.key,
    required this.selectedUnit,
    required this.onChanged,
  });

  Widget _buildUnitButton(String unit) {
    final isSelected = selectedUnit == unit;
    return GestureDetector(
      onTap: () => onChanged(unit),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF002663) : Colors.white,
          borderRadius: BorderRadius.circular(28.0),
          border: Border.all(
            color: const Color(0xFF002663),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            unit,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF002663),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: 'Units',
          subtitle: 'Select measurement unit preference for distance announcements.',
        ),
        const SizedBox(height: 32),
        _buildUnitButton('Metric'),
        const SizedBox(height: 16),
        _buildUnitButton('Imperial'),
      ],
    );
  }
}
