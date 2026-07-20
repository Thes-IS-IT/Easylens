import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';

// STEP 8: Units
class StepUnits extends StatelessWidget {
  final String selectedUnit;
  final String language;
  final ValueChanged<String> onChanged;

  const StepUnits({
    super.key,
    required this.selectedUnit,
    required this.language,
    required this.onChanged,
  });

  Widget _buildUnitButton(String value, String label) {
    final isSelected = selectedUnit == value;
    return GestureDetector(
      onTap: () => onChanged(value),
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
            label,
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
          title: SignupL10n.t('units_title', language),
          subtitle: SignupL10n.t('units_subtitle', language),
        ),
        const SizedBox(height: 32),
        _buildUnitButton('Metric', SignupL10n.t('units_metric', language)),
        const SizedBox(height: 16),
        _buildUnitButton('Imperial', SignupL10n.t('units_imperial', language)),
      ],
    );
  }
}
