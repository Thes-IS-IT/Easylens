import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onEasyLensTap;

  const CustomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onEasyLensTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
      child: Row(
        children: [
          // Main floating navbar pill
          Expanded(
            child: Container(
              height: 74,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(37),
                border: Border.all(
                  color: Colors.black.withOpacity(0.04),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavbarItem(
                    index: 0,
                    icon: Icons.home_outlined,
                    label: 'Home',
                  ),
                  _buildNavbarItem(
                    index: 1,
                    icon: Icons.navigation_outlined,
                    label: 'Nav',
                  ),
                  _buildNavbarItem(
                    index: 2,
                    icon: Icons.sensors,
                    label: 'EasyLens',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Floating Circular Action Button on the right
          GestureDetector(
            onTap: onEasyLensTap,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withOpacity(0.04),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.visibility_outlined,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavbarItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFECEFF1) : Colors.transparent, // Light grey background pill S01
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1E88E5) : Colors.black, // Blue when active, black when inactive
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF1E88E5) : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
