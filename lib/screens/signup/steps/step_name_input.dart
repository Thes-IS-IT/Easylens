import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import 'step_helpers.dart';

// STEP 17: What should I call you?
class StepNameInput extends StatefulWidget {
  final String name;
  final ValueChanged<String> onNameChanged;

  const StepNameInput({
    super.key,
    required this.name,
    required this.onNameChanged,
  });

  @override
  State<StepNameInput> createState() => _StepNameInputState();
}

class _StepNameInputState extends State<StepNameInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name);
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
          title: 'What should I call you?',
          subtitle: 'Speak your first name or nickname, or type it below.',
        ),
        const SizedBox(height: 36),

        // Circular mic button
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: () {}, // Mic action placeholder
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryButton, width: 2.5),
                    color: Colors.transparent,
                  ),
                  child: Icon(
                    Icons.mic_none,
                    size: 52,
                    color: AppColors.primaryButton,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Tap to Speak Name',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
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
        const SizedBox(height: 10),

        // Input field — pill shaped, filled, prefix icon
        TextField(
          controller: _controller,
          onChanged: widget.onNameChanged,
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.primaryText),
          decoration: InputDecoration(
            hintText: 'Nickname or Preferred Name',
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
            prefixIcon: Icon(Icons.person_outline, color: AppColors.textMuted, size: 20),
            filled: true,
            fillColor: AppColors.lightBackground,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: AppColors.unselectedBorder, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: AppColors.primaryButton, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
