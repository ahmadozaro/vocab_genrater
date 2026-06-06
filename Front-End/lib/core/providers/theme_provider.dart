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
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.card,
      onSurface: AppColors.textDark,
    ),
    scaffoldBackgroundColor: AppColors.background,
    cardColor: AppColors.card,
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    ),
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
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.card,
      onSurface: AppColors.textDark,
    ),
    scaffoldBackgroundColor: AppColors.background,
    cardColor: AppColors.card,
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    ),
    dialogTheme: DialogThemeData(backgroundColor: AppColors.card),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      hintStyle: TextStyle(color: AppColors.textLight),
      labelStyle: TextStyle(color: AppColors.textLight),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.textLight,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary.withOpacity(0.44)
            : AppColors.border,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.primaryLight,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: AppColors.textLight),
      ),
    ),
    elevatedButtonTheme: _elevatedButtonTheme,
    pageTransitionsTheme: _pageTransitions,
    useMaterial3: true,
  );
}
