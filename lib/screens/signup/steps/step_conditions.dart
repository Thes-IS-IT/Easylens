import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import 'step_helpers.dart';

// STEP 2: Your Conditions
class StepConditions extends StatelessWidget {
  final List<String> selectedConditions;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback onAddCustomCondition;

  const StepConditions({
    super.key,
    required this.selectedConditions,
    required this.onChanged,
    required this.onAddCustomCondition,
  });

  static const List<String> conditionsList = [
    'Cataracts',
    'Glaucoma',
    'Macular Degeneration',
    'Low Vision',
    'Diabetic Retinopathy',
    'Retinitis Pigmentosa',
    'Color Blindness',
    'Hemianopia',
    'Prefer not to say',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: 'Your Conditions',
          subtitle: 'Select your known conditions to calibrate your sensors.',
        ),
        const SizedBox(height: 24),
        Column(
          children: conditionsList.map((condition) {
            final isSelected = selectedConditions.contains(condition);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: GestureDetector(
                onTap: () {
                  final list = List<String>.from(selectedConditions);
                  if (isSelected) {
                    list.remove(condition);
                  } else {
                    list.add(condition);
                  }
                  onChanged(list);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryButton : AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryButton : AppColors.cardBorder.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      condition,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.primaryButtonText : AppColors.primaryText,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Add custom condition button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryText,
              side: BorderSide(color: AppColors.cardBorder, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
            onPressed: onAddCustomCondition,
            child: Text(
              'Condition not listed...',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
