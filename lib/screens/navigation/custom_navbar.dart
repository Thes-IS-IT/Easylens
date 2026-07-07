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
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
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
                    activeIcon: Icons.home,
                    label: 'Home',
                  ),
                  _buildNavbarItem(
                    index: 1,
                    icon: Icons.navigation_outlined,
                    activeIcon: Icons.navigation,
                    label: 'Nav',
                  ),
                  _buildNavbarItem(
                    index: 2,
                    icon: Icons.sensors,
                    activeIcon: Icons.sensors,
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.visibility_outlined,
                  color: Color(0xFF002663),
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
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFFF1F5F9), // Light grey-blue background pill
                borderRadius: BorderRadius.circular(20),
              )
            : const BoxDecoration(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? const Color(0xFF002663) : const Color(0xFF94A3B8),
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF002663),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
