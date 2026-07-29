import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class AppColors {
  // Get active contrast theme
  static String get _theme => SettingsService().selectedContrastTheme;
  static bool get _isDark => SettingsService().isDarkMode;

  // Primary Theme Colors
  static Color get primaryText {
    switch (_theme) {
      case 'Black on White':
        return Colors.black;
      case 'White on Black':
        return Colors.white;
      case 'Green on Black':
        return const Color(0xFF32CD32); // lime green
      case 'Yellow on Black':
        return const Color(0xFFFFD700); // Gold yellow
      case 'Cyan on Black':
        return const Color(0xFF00D2C4); // Cyan
      case 'Default':
      default:
        return _isDark ? Colors.white : const Color(0xFF002663); // White in Dark mode, Deep Blue in Light mode
    }
  }

  static Color get primaryButton {
    switch (_theme) {
      case 'Black on White':
        return Colors.black;
      case 'White on Black':
        return Colors.white;
      case 'Green on Black':
        return const Color(0xFF32CD32);
      case 'Yellow on Black':
        return const Color(0xFFFFD700);
      case 'Cyan on Black':
        return const Color(0xFF00D2C4);
      case 'Default':
      default:
        return _isDark ? Colors.white : const Color(0xFF002663);
    }
  }

  static Color get primaryButtonText {
    switch (_theme) {
      case 'White on Black':
      case 'Green on Black':
      case 'Yellow on Black':
      case 'Cyan on Black':
        return Colors.black;
      case 'Black on White':
        return Colors.white;
      case 'Default':
      default:
        return _isDark ? Colors.black : Colors.white;
    }
  }

  static Color get primaryBackground {
    switch (_theme) {
      case 'Black on White':
        return Colors.white;
      case 'White on Black':
      case 'Green on Black':
      case 'Yellow on Black':
      case 'Cyan on Black':
        return Colors.black;
      case 'Default':
      default:
        return _isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
    }
  }
  
  // Welcome Screen Specifics (Panel 1)
  static Color get welcomeBackground {
    switch (_theme) {
      case 'Black on White':
        return Colors.white;
      case 'White on Black':
      case 'Green on Black':
      case 'Yellow on Black':
      case 'Cyan on Black':
        return Colors.black;
      case 'Default':
      default:
        return _isDark ? const Color(0xFF121212) : const Color(0xFF00205B);
    }
  }

  static Color get welcomeAccentGold {
    switch (_theme) {
      case 'Black on White':
        return Colors.black;
      case 'White on Black':
        return Colors.white;
      case 'Green on Black':
        return const Color(0xFF32CD32);
      case 'Yellow on Black':
        return const Color(0xFFFFD700);
      case 'Cyan on Black':
        return const Color(0xFF00D2C4);
      case 'Default':
      default:
        return const Color(0xFFE5A63C);
    }
  }

  // General App Styling Colors
  static Color get cardBorder {
    switch (_theme) {
      case 'Black on White':
        return Colors.black;
      case 'White on Black':
        return Colors.white;
      case 'Green on Black':
        return const Color(0xFF32CD32);
      case 'Yellow on Black':
        return const Color(0xFFFFD700);
      case 'Cyan on Black':
        return const Color(0xFF00D2C4);
      case 'Default':
      default:
        return _isDark ? const Color(0xFF333333) : const Color(0xFF002663);
    }
  }

  static Color get unselectedBorder {
    switch (_theme) {
      case 'Black on White':
        return const Color(0xFFE2E8F0);
      case 'White on Black':
      case 'Green on Black':
      case 'Yellow on Black':
      case 'Cyan on Black':
        return const Color(0xFF333333);
      case 'Default':
      default:
        return _isDark ? const Color(0xFF333333) : const Color(0xFFCCCCCC);
    }
  }

  static Color get lightBackground {
    switch (_theme) {
      case 'Black on White':
        return const Color(0xFFF8F9FA);
      case 'White on Black':
      case 'Green on Black':
      case 'Yellow on Black':
      case 'Cyan on Black':
        return const Color(0xFF121212);
      case 'Default':
      default:
        return _isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA);
    }
  }

  static Color get textMuted {
    switch (_theme) {
      case 'Black on White':
        return const Color(0xFF4A5568);
      case 'White on Black':
      case 'Green on Black':
      case 'Yellow on Black':
      case 'Cyan on Black':
        return const Color(0xFF999999);
      case 'Default':
      default:
        return _isDark ? const Color(0xFFA0AEC0) : const Color(0xFF666666);
    }
  }

  static Color get shadowColor {
    switch (_theme) {
      case 'Black on White':
        return const Color(0x0F000000);
      case 'White on Black':
      case 'Green on Black':
      case 'Yellow on Black':
      case 'Cyan on Black':
        return Colors.transparent;
      case 'Default':
      default:
        return const Color(0x1A000000);
    }
  }
}
