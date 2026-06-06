import 'package:flutter/material.dart';
import 'package:ai/core/theme/colors.dart';

class OptionButton extends StatelessWidget {
  final int index;
  final String label;
  final int correctIndex;
  final int? selectedIndex;
  final bool isAnswered;
  final VoidCallback onTap;

  const OptionButton({
    super.key,
    required this.index,
    required this.label,
    required this.correctIndex,
    required this.selectedIndex,
    required this.isAnswered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = AppColors.card;
    Color textColor = AppColors.textDark;
    IconData? icon;

    if (isAnswered) {
      if (index == correctIndex) {
        bgColor = AppColors.success.withOpacity(0.2);
        textColor = AppColors.success;
        icon = Icons.check_circle;
      } else if (index == selectedIndex) {
        bgColor = AppColors.error.withOpacity(0.2);
        textColor = AppColors.error;
        icon = Icons.cancel;
      }
    } else if (selectedIndex == index) {
      bgColor = AppColors.primaryLight;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          side: BorderSide(
            color: selectedIndex == index
                ? AppColors.primary
                : AppColors.border,
            width: 2,
          ),
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: selectedIndex == index
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            if (icon != null) Icon(icon, color: textColor),
          ],
        ),
      ),
    );
  }
}
