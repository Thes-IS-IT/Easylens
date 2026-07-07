import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';

// STEP 14 SUB: Full Terms document overlay
class StepTermsDocument extends StatelessWidget {
  final VoidCallback onClose;

  const StepTermsDocument({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Document card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FULL TERMS & PRIVACY',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'EasyLens Terms of Service & Privacy Disclosure',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),
              _TermsSection(
                number: '1',
                title: 'Scope of Services',
                body:
                    'EasyLens assists visually impaired users in detecting environmental hazards and provides real-time navigation assistance. The service is provided on an "as is" basis without warranties of any kind.',
              ),
              const SizedBox(height: 18),
              _TermsSection(
                number: '2',
                title: 'Camera and Voice Data Utilization',
                body:
                    'To detect obstacles, we activate your device camera feed and microphone input for contextual processing. All computations are performed in real-time. We do not sell or share footage data with third parties without explicit consent.',
              ),
              const SizedBox(height: 18),
              _TermsSection(
                number: '3',
                title: 'User Indemnification',
                body:
                    'EasyLens cannot replace primary mobility aids (e.g. guide dogs, canes). The user agrees to exercise utmost caution and vigilance while using the application.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Close button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.grey.shade600,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: onClose,
            child: Text(
              'Close',
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _TermsSection({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number. ',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
