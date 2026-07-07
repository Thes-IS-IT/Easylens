import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import 'step_helpers.dart';

// STEP 12: Enter 4-Digit Code
class StepVerificationCode extends StatefulWidget {
  final ValueChanged<String> onVerify;
  final Future<void> Function() onResendCode;
  final String? errorMessage;

  const StepVerificationCode({
    super.key,
    required this.onVerify,
    required this.onResendCode,
    this.errorMessage,
  });

  @override
  State<StepVerificationCode> createState() => _StepVerificationCodeState();
}

class _StepVerificationCodeState extends State<StepVerificationCode> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isResending = false;

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _getEnteredCode() {
    return _controllers.map((c) => c.text).join();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: 'Enter 4-Digit Code',
          subtitle: 'Enter the 4-digit verification code sent to your device.',
        ),
        const SizedBox(height: 24),
        if (widget.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) {
            return SizedBox(
              width: 64,
              height: 64,
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: "",
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.cardBorder, width: 1.5),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryButton, width: 2.5),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                onChanged: (val) {
                  if (val.isNotEmpty && index < 3) {
                    _focusNodes[index + 1].requestFocus();
                  } else if (val.isEmpty && index > 0) {
                    _focusNodes[index - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),
        
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              Text(
                'DON\'T RECEIVE A CODE?',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              _isResending
                  ? SizedBox(width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryText),
                      ),
                    )
                  : TextButton(
                      onPressed: () async {
                        setState(() => _isResending = true);
                        try {
                          await widget.onResendCode();
                        } finally {
                          if (mounted) {
                            setState(() => _isResending = false);
                          }
                        }
                      },
                      child: Text(
                        'RESEND CODE',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                      ),
                    ),
            ],
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
            onPressed: () => widget.onVerify(_getEnteredCode()),
            child: Text(
              'Verify',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
