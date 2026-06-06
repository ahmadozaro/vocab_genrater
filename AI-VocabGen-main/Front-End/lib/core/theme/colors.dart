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
      _isDarkMode ? const Color(0xFF3A2B68) : const Color(0xFFD6C8FF);

  static Color get textDark =>
      _isDarkMode ? const Color(0xFFF4F0FF) : const Color(0xFF191521);

  static Color get textLight =>
      _isDarkMode ? const Color(0xFFC8BEDA) : const Color(0xFF6F657C);

  static const textWhite = Colors.white;

  static Color get background =>
      _isDarkMode ? const Color(0xFF100D17) : const Color(0xFFF7F5FF);

  static Color get card => _isDarkMode ? const Color(0xFF211B2D) : Colors.white;

  static const buttonPrimary = primary;
  static const buttonSecondary = secondary;

  static Color get border =>
      _isDarkMode ? const Color(0xFF46395B) : const Color(0xFFE0E0E0);

  static const success = Color(0xFF4CAF50);
  static const error = Color(0xFFE53935);
  static const warning = Color(0xFFFFA000);

  static const navActive = primary;
  static Color get navInactive =>
      _isDarkMode ? const Color(0xFF8A8298) : const Color(0xFFB0B0B0);
}
