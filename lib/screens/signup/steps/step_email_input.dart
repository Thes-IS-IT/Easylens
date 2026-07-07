import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import 'step_helpers.dart';

// STEP 10: Email Input
class StepEmailInput extends StatefulWidget {
  final String email;
  final ValueChanged<String> onEmailChanged;
  final VoidCallback onContinue;
  final VoidCallback onChangeMethod;

  const StepEmailInput({
    super.key,
    required this.email,
    required this.onEmailChanged,
    required this.onContinue,
    required this.onChangeMethod,
  });

  @override
  State<StepEmailInput> createState() => _StepEmailInputState();
}

class _StepEmailInputState extends State<StepEmailInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.email);
  }

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
          title: 'Enter your email',
          subtitle: 'This will be used to sign in to your account.',
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.emailAddress,
          onChanged: widget.onEmailChanged,
          style: GoogleFonts.inter(fontSize: 16, color: AppColors.primaryText),
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.unselectedBorder),
              borderRadius: BorderRadius.circular(12.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.cardBorder, width: 2.0),
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryButton,
              foregroundColor: AppColors.primaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28.0),
              ),
            ),
            onPressed: widget.onContinue,
            child: Text(
              'Continue',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
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
            onPressed: widget.onChangeMethod,
            child: Text(
              'Change Method',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
