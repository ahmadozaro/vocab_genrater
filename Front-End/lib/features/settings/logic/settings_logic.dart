import 'package:ai/core/theme/colors.dart';
import 'package:flutter/material.dart';

class SettingsLogic {
  
  static void showSnack(
    BuildContext context, {
    required bool ok,
    required String successMsg,
    required String failMsg,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? successMsg : failMsg),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}
