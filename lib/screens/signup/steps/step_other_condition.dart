import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';
import 'voice_input_widget.dart';

// STEP 2 SUB: Other Condition (Speech / Custom input)
class StepOtherCondition extends StatefulWidget {
  final String language;
  final ValueChanged<String> onConditionAdded;
  final VoidCallback onCancel;

  const StepOtherCondition({
    super.key,
    required this.language,
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
          title: SignupL10n.t('other_condition_title', widget.language),
          subtitle: SignupL10n.t('other_condition_subtitle', widget.language),
        ),
        const SizedBox(height: 32),
        
        // Microphone visualizer with auto-off timer
        VoiceMicBigButton(
          controller: _controller,
          label: SignupL10n.t('other_condition_mic_label', widget.language),
        ),
        
        const SizedBox(height: 32),
        Text(
          'Or type below:',
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
            hintText: SignupL10n.t('other_condition_hint', widget.language),
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
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
                  SignupL10n.t('other_condition_add', widget.language),
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
              SignupL10n.t('other_condition_cancel', widget.language),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
