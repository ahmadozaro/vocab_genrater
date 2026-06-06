import 'package:flutter/material.dart';
import 'package:ai/core/theme/colors.dart';

class LogoutHelper {
  static void showConfirmLogout(BuildContext context, dynamic auth) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Log Out",
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Cancel", style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              // 1. أغلق الديالوج أولاً
              Navigator.pop(dialogContext);

              // 2. تنفيذ الـ logout
              // ✅ الـ auth.logout() يُعيّن _isLoggedIn = false
              // → الـ _AppRouter في main.dart سيعيد البناء تلقائياً
              // → يعرض _AuthFlow مع PageController جديد صحيح
              await auth.logout();

              // ✅ لا نحتاج Navigator هنا — الـ Consumer في _AppRouter يتولى الأمر
            },
            child: const Text("Log Out", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
