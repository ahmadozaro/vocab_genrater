import 'package:flutter/material.dart';

class AppColors {
  static bool _isDarkMode = false;

  static void setDarkMode(bool value) {
    _isDarkMode = value;
  }

  static bool get isDarkMode => _isDarkMode;

  static const primary = Color(0xFF9F7BFF);
  static const secondary = Color(0xFF755DC1);
  static const primaryDark = Color(0xFF5A3FC0);

  static Color get primaryLight =>
      _isDarkMode ? const Color(0xFF2E2550) : const Color(0xFFD6C8FF);

  static Color get textDark => Colors.black;

  static Color get textLight => Colors.black;

  static const textWhite = Colors.white;

  static Color get background =>
      _isDarkMode ? const Color(0xFF121018) : const Color(0xFFF7F5FF);

  static Color get card => _isDarkMode ? const Color(0xFF1D1926) : Colors.white;

  static const buttonPrimary = primary;
  static const buttonSecondary = secondary;

  static Color get border =>
      _isDarkMode ? const Color(0xFF3A314A) : const Color(0xFFE0E0E0);

  static const success = Color(0xFF4CAF50);
  static const error = Color(0xFFE53935);
  static const warning = Color(0xFFFFA000);

  static const navActive = primary;
  static Color get navInactive =>
      _isDarkMode ? const Color(0xFF6F657C) : const Color(0xFFB0B0B0);
}
