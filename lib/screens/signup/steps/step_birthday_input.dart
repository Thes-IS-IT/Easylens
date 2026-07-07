import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import 'step_helpers.dart';

// STEP 18: Your Birthday
class StepBirthdayInput extends StatefulWidget {
  final String birthday;
  final ValueChanged<String> onBirthdayChanged;

  const StepBirthdayInput({
    super.key,
    required this.birthday,
    required this.onBirthdayChanged,
  });

  @override
  State<StepBirthdayInput> createState() => _StepBirthdayInputState();
}

class _StepBirthdayInputState extends State<StepBirthdayInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.birthday);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openDatePicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryButton,
              onPrimary: AppColors.primaryButtonText,
              surface: Colors.white,
              onSurface: AppColors.primaryText,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryButton,
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
            dialogTheme: const DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted =
          '${picked.month.toString().padLeft(2, '0')} / ${picked.day.toString().padLeft(2, '0')} / ${picked.year}';
      _controller.text = formatted;
      widget.onBirthdayChanged(formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: 'Your Birthday',
          subtitle: 'Tap the microphone to speak your birthday.',
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
                'Tap to Speak Birthday',
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

        // Input field — pill shaped, filled, calendar suffix icon
        TextField(
          controller: _controller,
          onChanged: widget.onBirthdayChanged,
          readOnly: true,
          onTap: _openDatePicker,
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.primaryText),
          decoration: InputDecoration(
            hintText: 'MM / DD / YYYY',
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
            suffixIcon: GestureDetector(
              onTap: _openDatePicker,
              child: Icon(Icons.calendar_month_outlined, color: AppColors.textMuted, size: 20),
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
