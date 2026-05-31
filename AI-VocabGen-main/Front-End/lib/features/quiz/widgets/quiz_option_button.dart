import 'package:flutter/material.dart';
import 'package:ai/core/theme/colors.dart';

class QuizOptionButton extends StatelessWidget {
  final String label;
  final String? selectedAnswer;
  final String correctAnswer; // ← من الـ model مباشرة
  final bool isAnswered;
  final VoidCallback onTap;

  const QuizOptionButton({
    super.key,
    required this.label,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.isAnswered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = AppColors.card;
    Color borderColor = AppColors.border;
    Color textColor = AppColors.textDark;
    IconData? icon;

    if (isAnswered) {
      if (label == correctAnswer) {
        bgColor = AppColors.success.withOpacity(0.15);
        borderColor = AppColors.success;
        textColor = AppColors.success;
        icon = Icons.check_circle;
      } else if (label == selectedAnswer) {
        bgColor = AppColors.error.withOpacity(0.15);
        borderColor = AppColors.error;
        textColor = AppColors.error;
        icon = Icons.cancel;
      }
    } else if (label == selectedAnswer) {
      bgColor = AppColors.primaryLight;
      borderColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: isAnswered ? null : onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: textColor,
                  fontWeight: label == selectedAnswer
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            if (icon != null) Icon(icon, color: textColor, size: 22),
          ],
        ),
      ),
    );
  }
}
