import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import 'step_helpers.dart';

// STEP 13: Create Password
class StepCreatePassword extends StatefulWidget {
  final String password;
  final ValueChanged<String> onPasswordChanged;

  const StepCreatePassword({
    super.key,
    required this.password,
    required this.onPasswordChanged,
  });

  @override
  State<StepCreatePassword> createState() => _StepCreatePasswordState();
}

class _StepCreatePasswordState extends State<StepCreatePassword> {
  late TextEditingController _passwordController;
  late TextEditingController _confirmController;
  bool _rememberMe = true;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: 'Create Password',
          subtitle: 'Create a secure password for your account.',
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _passwordController,
          obscureText: true,
          onChanged: widget.onPasswordChanged,
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: GoogleFonts.inter(color: AppColors.primaryText),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.unselectedBorder),
              borderRadius: BorderRadius.circular(12.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.cardBorder, width: 2.0),
              borderRadius: BorderRadius.circular(12.0),
            ),
            suffixIcon: const Icon(Icons.visibility_off_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            labelStyle: GoogleFonts.inter(color: AppColors.primaryText),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.unselectedBorder),
              borderRadius: BorderRadius.circular(12.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.cardBorder, width: 2.0),
              borderRadius: BorderRadius.circular(12.0),
            ),
            suffixIcon: const Icon(Icons.visibility_off_outlined),
          ),
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: Text(
            'Remember Me',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primaryText),
          ),
          value: _rememberMe,
          activeColor: AppColors.primaryButton,
          onChanged: (val) {
            setState(() {
              _rememberMe = val;
            });
          },
        ),
      ],
    );
  }
}
