import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';

// STEP 4: Contrast Theme
class StepContrastTheme extends StatelessWidget {
  final String selectedTheme;
  final String language;
  final ValueChanged<String> onChanged;

  StepContrastTheme({
    super.key,
    required this.selectedTheme,
    required this.language,
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
    const double circleSize = 72.0;

    switch (name) {
      case 'Default':
        return Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF002663),
            border: Border.all(
              color: isSelected ? const Color(0xFFE59C1B) : const Color(0xFFD1D5DB),
              width: isSelected ? 5.0 : 2.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6.0,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: isSelected
              ? const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: Color(0xFFE59C1B),
                    size: 32,
                  ),
                )
              : null,
        );

      case 'Black on White':
        return Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: isSelected ? const Color(0xFFE59C1B) : const Color(0xFFD1D5DB),
              width: isSelected ? 4.0 : 2.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6.0,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
            ),
            child: isSelected
                ? const Center(
                    child: Icon(Icons.check_rounded, color: Colors.white, size: 24),
                  )
                : null,
          ),
        );

      case 'White on Black':
        return Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            border: Border.all(
              color: isSelected ? const Color(0xFFE59C1B) : Colors.black,
              width: isSelected ? 4.0 : 6.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6.0,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: isSelected
                ? const Center(
                    child: Icon(Icons.check_rounded, color: Colors.black, size: 24),
                  )
                : null,
          ),
        );

      case 'Green on Black':
        return Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            border: Border.all(
              color: isSelected ? const Color(0xFFE59C1B) : Colors.black,
              width: isSelected ? 4.0 : 6.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6.0,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2EC03A),
            ),
            child: isSelected
                ? const Center(
                    child: Icon(Icons.check_rounded, color: Colors.black, size: 24),
                  )
                : null,
          ),
        );

      case 'Yellow on Black':
        return Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            border: Border.all(
              color: isSelected ? const Color(0xFFE59C1B) : Colors.black,
              width: isSelected ? 4.0 : 6.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6.0,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE2E600),
            ),
            child: isSelected
                ? const Center(
                    child: Icon(Icons.check_rounded, color: Colors.black, size: 24),
                  )
                : null,
          ),
        );

      case 'Cyan on Black':
        return Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            border: Border.all(
              color: isSelected ? const Color(0xFFE59C1B) : Colors.black,
              width: isSelected ? 4.0 : 6.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6.0,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF25C5CF),
            ),
            child: isSelected
                ? const Center(
                    child: Icon(Icons.check_rounded, color: Colors.black, size: 24),
                  )
                : null,
          ),
        );

      default:
        return const SizedBox();
    }
  }

  Color _getOptionTextColor(String name, bool isSelected, bool isLightBg) {
    switch (name) {
      case 'Default':
        if (isLightBg) {
          return isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569);
        } else {
          return isSelected ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8);
        }

      case 'Black on White':
        if (isLightBg) {
          return isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B);
        } else {
          return isSelected ? Colors.white : const Color(0xFFCBD5E1);
        }

      case 'White on Black':
        if (isLightBg) {
          return isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B);
        } else {
          return isSelected ? Colors.white : const Color(0xFFCBD5E1);
        }

      case 'Green on Black':
        if (isLightBg) {
          return isSelected ? const Color(0xFF15803D) : const Color(0xFF16A34A);
        } else {
          return isSelected ? const Color(0xFF4ADE80) : const Color(0xFF2EC03A);
        }

      case 'Yellow on Black':
        if (isLightBg) {
          return isSelected ? const Color(0xFFB45309) : const Color(0xFFD97706);
        } else {
          return isSelected ? const Color(0xFFFACC15) : const Color(0xFFE2E600);
        }

      case 'Cyan on Black':
        if (isLightBg) {
          return isSelected ? const Color(0xFF0369A1) : const Color(0xFF0284C7);
        } else {
          return isSelected ? const Color(0xFF22D3EE) : const Color(0xFF25C5CF);
        }

      default:
        return isLightBg ? const Color(0xFF0F172A) : Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLightBg = selectedTheme == 'Default' || selectedTheme == 'Black on White';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: SignupL10n.t('theme_title', language),
          subtitle: SignupL10n.t('theme_subtitle', language),
        ),
        const SizedBox(height: 32),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 28,
            childAspectRatio: 0.70,
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
                  const SizedBox(height: 12),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                      color: _getOptionTextColor(name, isSelected, isLightBg),
                      height: 1.25,
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
