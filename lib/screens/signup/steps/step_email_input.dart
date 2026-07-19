import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import 'step_helpers.dart';
import 'voice_input_widget.dart';

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
  String? _errorText;

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

  bool _isValidEmail(String email) {
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegExp.hasMatch(email.trim());
  }

  void _handleContinue() {
    final email = _controller.text.trim();
    if (email.isEmpty) {
      setState(() => _errorText = 'Please enter your email address');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _errorText = 'Please enter a valid email address (e.g. name@example.com)');
      return;
    }

    setState(() => _errorText = null);
    widget.onEmailChanged(email);
    widget.onContinue();
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

        if (_errorText != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorText!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        TextField(
          controller: _controller,
          keyboardType: TextInputType.emailAddress,
          onChanged: (val) {
            if (_errorText != null) {
              setState(() => _errorText = null);
            }
            widget.onEmailChanged(val);
          },
          style: GoogleFonts.inter(fontSize: 16, color: AppColors.primaryText),
          decoration: InputDecoration(
            hintText: 'example@email.com',
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
            prefixIcon: Icon(Icons.email_outlined, color: AppColors.textMuted, size: 20),
            suffixIcon: VoiceMicIconButton(
              controller: _controller,
              onChanged: (val) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
                widget.onEmailChanged(val);
              },
              isEmail: true,
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: _errorText != null ? Colors.red.shade300 : AppColors.unselectedBorder,
              ),
              borderRadius: BorderRadius.circular(12.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: _errorText != null ? Colors.red : AppColors.cardBorder,
                width: 2.0,
              ),
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
            onPressed: _handleContinue,
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
