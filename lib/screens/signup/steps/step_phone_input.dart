import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import 'step_helpers.dart';

// STEP 11: Phone Input
class StepPhoneInput extends StatefulWidget {
  final String phone;
  final ValueChanged<String> onPhoneChanged;
  final Future<void> Function() onSendCode;
  final VoidCallback onChangeMethod;

  const StepPhoneInput({
    super.key,
    required this.phone,
    required this.onPhoneChanged,
    required this.onSendCode,
    required this.onChangeMethod,
  });

  @override
  State<StepPhoneInput> createState() => _StepPhoneInputState();
}

class _StepPhoneInputState extends State<StepPhoneInput> {
  late TextEditingController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.phone);
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
          title: 'Phone Input',
          subtitle: 'Enter your phone number.',
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.unselectedBorder),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flag, size: 20),
                  const SizedBox(width: 8),
                  Text('+63', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                onChanged: widget.onPhoneChanged,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: GoogleFonts.inter(color: AppColors.primaryText),
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
            ),
          ],
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
            onPressed: _isLoading
                ? null
                : () async {
                    setState(() => _isLoading = true);
                    try {
                      await widget.onSendCode();
                    } finally {
                      if (mounted) {
                        setState(() => _isLoading = false);
                      }
                    }
                  },
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Send Code',
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
            onPressed: _isLoading ? null : widget.onChangeMethod,
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
