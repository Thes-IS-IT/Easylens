import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  String _selectedUnit = 'Metric';

  Widget _buildUnitCard({
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedUnit == title;
    final cardColor = isSelected ? const Color(0xFF002663) : Colors.white;
    final titleColor = isSelected ? Colors.white : Colors.black;
    final subtitleColor = isSelected ? const Color(0xFFE2E8F0) : const Color(0xFF64748B);
    final borderColor = isSelected ? Colors.transparent : const Color(0xFF002663);

    return GestureDetector(
      onTap: () => setState(() => _selectedUnit = title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20.0),
          border: isSelected ? null : Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
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
              color: isSelected ? Colors.white : const Color(0xFF002663),
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chevron_left, color: Color(0xFF002663), size: 24),
                      const SizedBox(width: 4),
                      Text(
                        'Back',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF002663),
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
                  color: const Color(0xFF002663),
                ),
              ),
              const SizedBox(height: 8),
              
              // Description
              Text(
                'Select measurement unit preference for distance announcements.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  height: 1.4,
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
