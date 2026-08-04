import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';
import 'voice_input_widget.dart';

// STEP 11: Create Password
class StepCreatePassword extends StatefulWidget {
  final String password;
  final String language;
  final ValueChanged<String> onPasswordChanged;
  final ValueChanged<bool>? onRememberMeChanged;

  const StepCreatePassword({
    super.key,
    required this.password,
    required this.language,
    required this.onPasswordChanged,
    this.onRememberMeChanged,
  });

  @override
  State<StepCreatePassword> createState() => _StepCreatePasswordState();
}

class _StepCreatePasswordState extends State<StepCreatePassword> {
  late TextEditingController _passwordController;
  late TextEditingController _confirmController;
  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController(text: widget.password);
    _confirmController = TextEditingController(text: widget.password);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _validateAndUpdate() {
    try {
      final pass = _passwordController.text;
      final confirm = _confirmController.text;
      final isTagalog = widget.language.toLowerCase().contains('tagalog') || widget.language.toLowerCase().contains('filipino');

      setState(() {
        if (pass.isEmpty) {
          _errorText = isTagalog ? 'Mangyaring gumawa ng password' : 'Please enter a password';
          widget.onPasswordChanged('');
        } else if (pass.length < 6) {
          _errorText = isTagalog ? 'Ang password ay dapat may hindi bababa sa 6 na karakter' : 'Password must be at least 6 characters long';
          widget.onPasswordChanged('');
        } else if (confirm.isNotEmpty && pass != confirm) {
          _errorText = isTagalog ? 'Hindi magkatugma ang dalawang password' : 'Passwords do not match';
          widget.onPasswordChanged('');
        } else if (pass == confirm) {
          _errorText = null; // Valid!
          widget.onPasswordChanged(pass);
        } else {
          _errorText = null;
        }
      });
    } catch (e) {
      setState(() {
        _errorText = 'Error reading password input: ${e.toString()}';
        widget.onPasswordChanged('');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: SignupL10n.t('password_title', widget.language),
          subtitle: SignupL10n.t('password_subtitle', widget.language),
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
          controller: _passwordController,
          obscureText: _obscurePassword,
          onChanged: (_) => _validateAndUpdate(),
          decoration: InputDecoration(
            labelText: SignupL10n.t('password_enter', widget.language),
            labelStyle: GoogleFonts.inter(color: AppColors.primaryText),
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
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoiceMicIconButton(
                  controller: _passwordController,
                  onChanged: (_) => _validateAndUpdate(),
                ),
                IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmController,
          obscureText: _obscureConfirm,
          onChanged: (_) => _validateAndUpdate(),
          decoration: InputDecoration(
            labelText: SignupL10n.t('password_confirm_field', widget.language),
            labelStyle: GoogleFonts.inter(color: AppColors.primaryText),
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
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoiceMicIconButton(
                  controller: _confirmController,
                  onChanged: (_) => _validateAndUpdate(),
                ),
                IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirm = !_obscureConfirm;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: Text(
            SignupL10n.t('password_keep_signed_in', widget.language),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryText),
          ),
          value: _rememberMe,
          activeTrackColor: AppColors.primaryButton,
          activeThumbColor: AppColors.primaryButtonText,
          inactiveTrackColor: AppColors.unselectedBorder,
          inactiveThumbColor: AppColors.primaryText.withValues(alpha: 0.6),
          onChanged: (val) {
            setState(() {
              _rememberMe = val;
            });
            widget.onRememberMeChanged?.call(val);
          },
        ),
      ],
    );
  }
}
