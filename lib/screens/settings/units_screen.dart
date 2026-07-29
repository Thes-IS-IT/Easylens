import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../services/settings_service.dart';
import '../../services/firebase_service.dart';

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  String _selectedUnit = 'Metric';

  @override
  void initState() {
    super.initState();
    _selectedUnit = SettingsService().selectedUnit;
  }

  void _saveSettings(String unit) {
    SettingsService().updateSettings(selectedUnit: unit);

    final user = FirebaseService().currentUser;
    if (user != null) {
      FirebaseService().syncPreferencesToCloud(user.uid, {
        'selectedUnit': unit,
      });
    }
  }

  Widget _buildUnitCard({
    required String title,
    required String subtitle,
  }) {
    final settings = SettingsService();
    final isDark = settings.isDarkMode;
    final isDefault = settings.selectedContrastTheme == 'Default' && !isDark;
    final isSelected = _selectedUnit == title;

    final cardColor = isSelected
        ? AppColors.primaryButton
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final titleColor = isSelected
        ? AppColors.primaryButtonText
        : (isDark ? AppColors.primaryText : (isDefault ? Colors.black : AppColors.primaryText));
    final subtitleColor = isSelected
        ? AppColors.primaryButtonText.withOpacity(0.85)
        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B));
    final borderColor = isSelected
        ? AppColors.primaryButton
        : AppColors.cardBorder.withOpacity(isDark ? 0.6 : 0.3);

    return GestureDetector(
      onTap: () {
        setState(() => _selectedUnit = title);
        _saveSettings(title);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: isDefault ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: subtitleColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primaryButtonText : AppColors.primaryText,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();
    final isDark = settings.isDarkMode;
    final isDefault = settings.selectedContrastTheme == 'Default' && !isDark;
    final headerTextColor = AppColors.primaryText;
    final secondaryTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Floating Pill Back Button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 95,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.cardBorder.withOpacity(isDark ? 0.6 : 0.3), width: 1.5),
                    boxShadow: isDefault ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ] : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chevron_left, color: headerTextColor, size: 24),
                      const SizedBox(width: 4),
                      Text(
                        'Back',
                        style: GoogleFonts.inter(
                          color: headerTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 2. Title Header
              Text(
                'Units',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: headerTextColor,
                ),
              ),
              const SizedBox(height: 8),
              
              // Description
              Text(
                'Select measurement unit preference for distance announcements.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: secondaryTextColor,
                  height: 1.45,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 3. Selection cards
              _buildUnitCard(
                title: 'Metric',
                subtitle: 'Meters and Kilometers',
              ),
              _buildUnitCard(
                title: 'Imperial',
                subtitle: 'Feet and Miles',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
