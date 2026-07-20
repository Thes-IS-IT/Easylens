import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';
import 'voice_input_widget.dart';

// STEP 10: Phone Input
class StepPhoneInput extends StatefulWidget {
  final String phone;
  final String language;
  final ValueChanged<String> onPhoneChanged;
  final Future<void> Function() onSendCode;
  final VoidCallback onChangeMethod;

  const StepPhoneInput({
    super.key,
    required this.phone,
    required this.language,
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
  String? _errorText;

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

  Future<void> _handleSendCode() async {
    final phone = _controller.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorText = 'Please enter your phone number');
      return;
    }

    if (phone.length < 10) {
      setState(() => _errorText = 'Please enter a valid 11-digit phone number');
      return;
    }

    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    try {
      await widget.onSendCode();
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = 'Failed to send code: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: SignupL10n.t('phone_title', widget.language),
          subtitle: SignupL10n.t('phone_subtitle', widget.language),
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
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                onChanged: (val) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                  widget.onPhoneChanged(val);
                },
                decoration: InputDecoration(
                  labelText: SignupL10n.t('phone_hint', widget.language),
                  labelStyle: GoogleFonts.inter(color: AppColors.primaryText),
                  suffixIcon: VoiceMicIconButton(
                    controller: _controller,
                    onChanged: (val) {
                      if (_errorText != null) {
                        setState(() => _errorText = null);
                      }
                      widget.onPhoneChanged(val);
                    },
                    isPhone: true,
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
            onPressed: _isLoading ? null : _handleSendCode,
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
                    SignupL10n.t('phone_send_code', widget.language),
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
              SignupL10n.t('phone_change_method', widget.language),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
