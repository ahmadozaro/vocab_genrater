import 'package:flutter/material.dart';
import 'package:ai/core/animations/app_motion.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    AppColors.setDarkMode(_isDarkMode);
    notifyListeners();
  }

  void toggleDarkMode(bool value) async {
    _isDarkMode = value;
    AppColors.setDarkMode(value);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  PageTransitionsTheme get _pageTransitions => const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: LearningPageTransitionsBuilder(),
      TargetPlatform.iOS: LearningPageTransitionsBuilder(),
      TargetPlatform.macOS: LearningPageTransitionsBuilder(),
      TargetPlatform.windows: LearningPageTransitionsBuilder(),
      TargetPlatform.linux: LearningPageTransitionsBuilder(),
    },
  );

  ElevatedButtonThemeData get _elevatedButtonTheme => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      animationDuration: AppMotion.fast,
      elevation: 0,
      splashFactory: InkSparkle.splashFactory,
    ),
  );

  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    colorSchemeSeed: const Color(0xFF4C6FFF),
    scaffoldBackgroundColor: AppColors.background,
    cardColor: AppColors.card,
    dialogTheme: DialogThemeData(backgroundColor: AppColors.card),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
    ),
    elevatedButtonTheme: _elevatedButtonTheme,
    pageTransitionsTheme: _pageTransitions,
    useMaterial3: true,
  );

  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: const Color(0xFF4C6FFF),
    scaffoldBackgroundColor: AppColors.background,
    cardColor: AppColors.card,
    dialogTheme: DialogThemeData(backgroundColor: AppColors.card),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
    ),
    elevatedButtonTheme: _elevatedButtonTheme,
    pageTransitionsTheme: _pageTransitions,
    useMaterial3: true,
  );
}
