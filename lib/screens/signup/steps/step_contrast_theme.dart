import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import 'step_helpers.dart';

// STEP 3: Contrast Theme
class StepContrastTheme extends StatelessWidget {
  final String selectedTheme;
  final ValueChanged<String> onChanged;

  StepContrastTheme({
    super.key,
    required this.selectedTheme,
    required this.onChanged,
  });

  final List<String> themes = [
    'Default',
    'Black on White',
    'White on Black',
    'Green on Black',
    'Yellow on Black',
    'Cyan on Black',
  ];

  Widget _buildThemeCircle(String name, bool isSelected) {
    Color outerRingColor;
    Color bgInnerColor;
    Color centerCircleColor;

    switch (name) {
      case 'Default':
        outerRingColor = const Color(0xFF002663);
        bgInnerColor = const Color(0xFF002663);
        centerCircleColor = const Color(0xFF002663);
        break;
      case 'Black on White':
        outerRingColor = const Color(0xFFE2E8F0);
        bgInnerColor = Colors.white;
        centerCircleColor = Colors.black;
        break;
      case 'White on Black':
        outerRingColor = Colors.black;
        bgInnerColor = Colors.black;
        centerCircleColor = Colors.white;
        break;
      case 'Green on Black':
        outerRingColor = Colors.black;
        bgInnerColor = Colors.black;
        centerCircleColor = const Color(0xFF32CD32);
        break;
      case 'Yellow on Black':
        outerRingColor = Colors.black;
        bgInnerColor = Colors.black;
        centerCircleColor = const Color(0xFFFFD700);
        break;
      case 'Cyan on Black':
        outerRingColor = Colors.black;
        bgInnerColor = Colors.black;
        centerCircleColor = const Color(0xFF00D2C4);
        break;
      default:
        outerRingColor = Colors.grey;
        bgInnerColor = Colors.white;
        centerCircleColor = Colors.black;
    }

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected && name != 'Default'
              ? const Color(0xFFE5A63C)
              : outerRingColor,
          width: 4.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6.0,
            offset: Offset(0, 3),
          )
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          color: bgInnerColor,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: const Color(0xFFE5A63C),
                  width: 3.0,
                )
              : null,
        ),
        child: Center(
          child: isSelected
              ? const Icon(
                  Icons.check,
                  color: Color(0xFFE5A63C),
                  size: 24,
                )
              : (name != 'Default'
                  ? Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: centerCircleColor,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: 'Contrast Theme',
          subtitle: 'Select the color interface to maximize text legibility.',
        ),
        const SizedBox(height: 32),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 24,
            childAspectRatio: 0.72,
          ),
          itemCount: themes.length,
          itemBuilder: (context, index) {
            final name = themes[index];
            final isSelected = selectedTheme == name;

            return GestureDetector(
              onTap: () => onChanged(name),
              child: Column(
                children: [
                  _buildThemeCircle(name, isSelected),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
