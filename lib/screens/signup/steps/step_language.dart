import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'step_helpers.dart';

// STEP 5: Language Selection
class StepLanguage extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onChanged;

  const StepLanguage({
    super.key,
    required this.selectedLanguage,
    required this.onChanged,
  });

  Widget _buildLanguageButton(String language) {
    final isSelected = selectedLanguage == language;
    return GestureDetector(
      onTap: () => onChanged(language),
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
            language,
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
          title: 'Language',
          subtitle: 'Select your primary voice synthesis and voice control language.',
        ),
        const SizedBox(height: 32),
        _buildLanguageButton('English'),
        const SizedBox(height: 16),
        _buildLanguageButton('Filipino'),
      ],
    );
  }
}
