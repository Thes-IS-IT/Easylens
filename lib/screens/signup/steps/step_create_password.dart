import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';
import 'voice_input_widget.dart';

// STEP 11: Create Password with instructions, try-catch error handling, and criteria badges
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

  /// Evaluates password against requirements inside a robust try-catch block.
  void _validateAndUpdate() {
    try {
      final pass = _passwordController.text;
      final confirm = _confirmController.text;
      final isTagalog = widget.language.toLowerCase().contains('tagalog') ||
          widget.language.toLowerCase().contains('filipino');

      final bool hasMinLength = pass.length >= 6;
      final bool hasUppercase = RegExp(r'[A-Z]').hasMatch(pass);
      final bool hasNumber = RegExp(r'[0-9]').hasMatch(pass);
      final bool hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>\-_=+\\|/`~]').hasMatch(pass);

      setState(() {
        if (pass.isEmpty) {
          _errorText = isTagalog ? 'Mangyaring gumawa ng password' : 'Please enter a password';
          widget.onPasswordChanged('');
        } else if (!hasMinLength) {
          _errorText = isTagalog
              ? 'Dapat may hindi bababa sa 6 na karakter ang password'
              : 'Password must be at least 6 characters long';
          widget.onPasswordChanged('');
        } else if (!hasUppercase) {
          _errorText = isTagalog
              ? 'Dapat may hindi bababa sa 1 uppercase na letra (A-Z)'
              : 'Password must contain at least 1 uppercase letter (A-Z)';
          widget.onPasswordChanged('');
        } else if (!hasNumber) {
          _errorText = isTagalog
              ? 'Dapat may hindi bababa sa 1 numero (0-9)'
              : 'Password must contain at least 1 number (0-9)';
          widget.onPasswordChanged('');
        } else if (!hasSpecialChar) {
          _errorText = isTagalog
              ? 'Dapat may hindi bababa sa 1 espesyal na karakter (!@#\$%^&*)'
              : 'Password must contain at least 1 special character (!@#\$%^&*)';
          widget.onPasswordChanged('');
        } else if (confirm.isNotEmpty && pass != confirm) {
          _errorText = isTagalog
              ? 'Hindi magkatugma ang dalawang password'
              : 'Passwords do not match';
          widget.onPasswordChanged('');
        } else if (pass == confirm && hasMinLength && hasUppercase && hasNumber && hasSpecialChar) {
          _errorText = null; // Clean valid state
          widget.onPasswordChanged(pass);
        } else {
          _errorText = null;
        }
      });
    } catch (e) {
      // Gracefully catch unexpected validation errors
      setState(() {
        final isTagalog = widget.language.toLowerCase().contains('tagalog') ||
            widget.language.toLowerCase().contains('filipino');
        _errorText = isTagalog
            ? 'Error sa pag-validate ng password: ${e.toString()}'
            : 'Error validating password input: ${e.toString()}';
        widget.onPasswordChanged('');
      });
    }
  }

  Widget _buildRequirementBadge(String label, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isMet ? const Color(0xFF10B981) : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
                color: isMet ? const Color(0xFF065F46) : AppColors.primaryText.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pass = _passwordController.text;
    final bool hasMinLength = pass.length >= 6;
    final bool hasUppercase = RegExp(r'[A-Z]').hasMatch(pass);
    final bool hasNumber = RegExp(r'[0-9]').hasMatch(pass);
    final bool hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>\-_=+\\|/`~]').hasMatch(pass);
    final isTagalog = widget.language.toLowerCase().contains('tagalog') ||
        widget.language.toLowerCase().contains('filipino');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: SignupL10n.t('password_title', widget.language),
          subtitle: SignupL10n.t('password_subtitle', widget.language),
        ),
        const SizedBox(height: 20),

        // ── Password Requirement Instruction Card ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    isTagalog ? 'Mga Kinakailangan sa Password:' : 'Password Requirements:',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E40AF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildRequirementBadge(
                isTagalog ? 'May hindi bababa sa 6 na karakter' : 'At least 6 characters long',
                hasMinLength,
              ),
              _buildRequirementBadge(
                isTagalog ? 'May hindi bababa sa 1 uppercase na letra (A-Z)' : 'At least 1 uppercase letter (A-Z)',
                hasUppercase,
              ),
              _buildRequirementBadge(
                isTagalog ? 'May hindi bababa sa 1 numero (0-9)' : 'At least 1 number (0-9)',
                hasNumber,
              ),
              _buildRequirementBadge(
                isTagalog ? 'May hindi bababa sa 1 espesyal na karakter (!@#\$%^&*)' : 'At least 1 special character (!@#\$%^&*)',
                hasSpecialChar,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

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
