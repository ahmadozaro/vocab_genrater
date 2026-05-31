import 'package:flutter/material.dart';
import 'package:ai/core/theme/colors.dart';

class QuizResultDialog extends StatelessWidget {
  final int score;
  final int total;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  const QuizResultDialog({
    super.key,
    required this.score,
    required this.total,
    required this.onRetry,
    required this.onHome,
  });

  String get _grade {
    if (total <= 0) return '📚 Quiz Empty';
    final percent = score / total;
    if (percent >= 0.9) return '🏆 Excellent!';
    if (percent >= 0.7) return '🎉 Great Job!';
    if (percent >= 0.5) return '👍 Good Effort!';
    return '📚 Keep Practicing!';
  }

  Color get _gradeColor {
    if (total <= 0) return AppColors.warning;
    final percent = score / total;
    if (percent >= 0.9) return AppColors.success;
    if (percent >= 0.7) return AppColors.primary;
    if (percent >= 0.5) return AppColors.warning;
    return AppColors.error;
  }

  double get _safePercent {
    if (total <= 0) return 0.0;
    return (score / total).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _grade,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: _safePercent,
                  strokeWidth: 10,
                  backgroundColor: AppColors.border,
                  color: _gradeColor,
                ),
              ),
              Column(
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: _gradeColor,
                    ),
                  ),
                  Text(
                    'of $total',
                    style: TextStyle(fontSize: 14, color: AppColors.textLight),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: onHome,
                  child: Text('Home'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: onRetry,
                  child: Text(
                    'Try Again',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
