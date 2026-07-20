import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';
import 'voice_input_widget.dart';

// STEP 12: Enter 4-Digit Code
class StepVerificationCode extends StatefulWidget {
  final String language;
  final ValueChanged<String> onVerify;
  final Future<void> Function() onResendCode;
  final String? errorMessage;

  const StepVerificationCode({
    super.key,
    required this.language,
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
  final TextEditingController _hiddenSpeechController = TextEditingController();
  bool _isResending = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _hiddenSpeechController.addListener(_onSpeechInputUpdated);
  }

  @override
  void dispose() {
    _hiddenSpeechController.removeListener(_onSpeechInputUpdated);
    _hiddenSpeechController.dispose();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onSpeechInputUpdated() {
    final code = _hiddenSpeechController.text.trim();
    if (code.isNotEmpty) {
      for (int i = 0; i < 4; i++) {
        if (i < code.length) {
          _controllers[i].text = code[i];
        } else {
          _controllers[i].clear();
        }
      }
      if (code.length >= 4) {
        _handleVerify();
      }
    }
  }

  String _getEnteredCode() {
    return _controllers.map((c) => c.text).join();
  }

  void _handleVerify() {
    final code = _getEnteredCode();
    if (code.length < 4) {
      setState(() => _localError = 'Please enter the complete 4-digit code.');
      return;
    }
    setState(() => _localError = null);
    try {
      widget.onVerify(code);
    } catch (e) {
      setState(() => _localError = 'Verification failed: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeError = _localError ?? widget.errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: SignupL10n.t('verify_title', widget.language),
          subtitle: SignupL10n.t('verify_subtitle', widget.language),
        ),
        const SizedBox(height: 24),

        // Speech Recognition Mic Button for Code Entry
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              VoiceMicIconButton(
                controller: _hiddenSpeechController,
                isCode: true,
              ),
              Text(
                'Tap mic to speak code',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (activeError != null) ...[
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
                    activeError,
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
                  if (_localError != null) {
                    setState(() => _localError = null);
                  }
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
                SignupL10n.t('verify_no_code', widget.language),
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              _isResending
                  ? SizedBox(
                      width: 20,
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
                        } catch (e) {
                          if (mounted) {
                            setState(() => _localError = SignupL10n.t('verify_error_resend', widget.language));
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isResending = false);
                          }
                        }
                      },
                      child: Text(
                        SignupL10n.t('verify_resend', widget.language),
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
            onPressed: _handleVerify,
            child: Text(
              'Confirm',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
