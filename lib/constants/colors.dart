import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class AppColors {
  // Get active contrast theme
  static String get _theme => SettingsService().selectedContrastTheme;

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
        return const Color(0xFF002663); // Deep Blue text
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
        return const Color(0xFF002663); // Deep Blue buttons
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
      case 'Default':
      default:
        return Colors.white;
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
        return const Color(0xFFFFFFFF); // Pure White
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
        return const Color(0xFF00205B); // Deep navy splash
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
        return const Color(0xFFE5A63C); // Golden mascot letters
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
        return const Color(0xFF002663);
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
        return const Color(0xFFCCCCCC);
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
        return const Color(0xFFF8F9FA); // Off-white
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
        return const Color(0xFF666666);
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
