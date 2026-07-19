import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import 'step_helpers.dart';
import 'voice_input_widget.dart';

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
  String? _errorText;

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

  void _handleNameChanged(String val) {
    if (val.trim().isEmpty) {
      setState(() => _errorText = 'Please enter your name or nickname');
    } else {
      if (_errorText != null) {
        setState(() => _errorText = null);
      }
    }
    widget.onNameChanged(val);
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

        // Circular mic button with auto-off timer
        VoiceMicBigButton(
          controller: _controller,
          onChanged: _handleNameChanged,
          label: 'Tap to Speak Name',
        ),

        const SizedBox(height: 32),

        if (_errorText != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18),
                const SizedBox(width: 8),
                Text(
                  _errorText!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        Text(
          'Or type it below:',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),

        // Input field — pill shaped, filled, prefix icon + suffix mic button
        TextField(
          controller: _controller,
          onChanged: _handleNameChanged,
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.primaryText),
          decoration: InputDecoration(
            hintText: 'Nickname or Preferred Name',
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
            prefixIcon: Icon(Icons.person_outline, color: AppColors.textMuted, size: 20),
            suffixIcon: VoiceMicIconButton(
              controller: _controller,
              onChanged: _handleNameChanged,
            ),
            filled: true,
            fillColor: AppColors.lightBackground,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(
                color: _errorText != null ? Colors.red.shade300 : AppColors.unselectedBorder,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(
                color: _errorText != null ? Colors.red : AppColors.primaryButton,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
