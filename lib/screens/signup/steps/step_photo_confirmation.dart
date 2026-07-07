import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import 'step_helpers.dart';

// STEP 16: Re-Upload / Photo Confirmation
class StepPhotoConfirmation extends StatelessWidget {
  final File pickedImage;
  final VoidCallback onReupload;
  final VoidCallback onContinue;

  const StepPhotoConfirmation({
    super.key,
    required this.pickedImage,
    required this.onReupload,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: 'Your Photo',
          subtitle: 'Upload a photo for your profile avatar.',
        ),
        const SizedBox(height: 48),
        Center(
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryText, width: 2.0),
              image: DecorationImage(
                image: FileImage(pickedImage),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 64),
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
            onPressed: onReupload,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh),
                const SizedBox(width: 8),
                Text(
                  'Re-Upload Photo',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
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
            onPressed: onContinue,
            child: Text(
              'Continue',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
