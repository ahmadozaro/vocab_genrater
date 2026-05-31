import 'package:flutter/material.dart';
import 'package:ai/core/theme/colors.dart';

class DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const DifficultyBadge({super.key, required this.difficulty});

  Color get _color {
    if (difficulty == 'easy') return AppColors.success;
    if (difficulty == 'medium') return AppColors.warning;
    return AppColors.error;
  }

  String get _label {
    if (difficulty == 'easy') return '● Easy';
    if (difficulty == 'medium') return '●● Medium';
    return '●●● Hard';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 12,
          color: _color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
