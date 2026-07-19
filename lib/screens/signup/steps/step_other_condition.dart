import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import 'step_helpers.dart';
import 'voice_input_widget.dart';

// STEP 2 SUB: Other Condition (Speech / Custom input)
class StepOtherCondition extends StatefulWidget {
  final ValueChanged<String> onConditionAdded;
  final VoidCallback onCancel;

  const StepOtherCondition({
    super.key,
    required this.onConditionAdded,
    required this.onCancel,
  });

  @override
  State<StepOtherCondition> createState() => _StepOtherConditionState();
}

class _StepOtherConditionState extends State<StepOtherCondition> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: 'Other Condition',
          subtitle: 'Tell us your visual condition so we can calibrate Buddy for you.',
        ),
        const SizedBox(height: 32),
        
        // Microphone visualizer with auto-off timer
        VoiceMicBigButton(
          controller: _controller,
          label: 'Tap to Speak Condition',
        ),
        
        const SizedBox(height: 32),
        Text(
          'Or type it below:',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'e.g., Astigmatism',
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
            suffixIcon: VoiceMicIconButton(
              controller: _controller,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: AppColors.unselectedBorder),
            ),
          ),
        ),
        const SizedBox(height: 32),
        
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryButton,
              foregroundColor: AppColors.primaryButtonText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28.0),
              ),
            ),
            onPressed: () {
              if (_controller.text.trim().isNotEmpty) {
                widget.onConditionAdded(_controller.text.trim());
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add),
                const SizedBox(width: 8),
                Text(
                  'Add Condition',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryText,
              side: BorderSide(color: AppColors.cardBorder, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28.0),
              ),
            ),
            onPressed: widget.onCancel,
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
