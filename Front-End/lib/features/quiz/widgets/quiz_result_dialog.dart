import 'package:flutter/material.dart';
import 'package:ai/core/models/quiz.dart';
import 'package:ai/core/theme/colors.dart';

class QuizResultDialog extends StatelessWidget {
  final int score;
  final int total;
  final QuizResultDetails? details;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  const QuizResultDialog({
    super.key,
    required this.score,
    required this.total,
    this.details,
    required this.onRetry,
    required this.onHome,
  });

  String get _grade {
    if (total <= 0) return 'Quiz Empty';
    final percent = score / total;
    if (percent >= 0.9) return 'Excellent';
    if (percent >= 0.7) return 'Good';
    if (percent >= 0.5) return 'Average';
    return 'Needs Work';
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
    final breakdown = details?.breakdown ?? [];
    final percentLabel = total <= 0 ? '0%' : '${(_safePercent * 100).round()}%';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: EdgeInsets.all(24),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: 620),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                details?.grade ?? _grade,
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
                        'of $total - $percentLabel',
                        style: TextStyle(fontSize: 14, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ],
              ),
              if (breakdown.isNotEmpty) ...[
                SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Review',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                ...breakdown.map((item) => _BreakdownTile(item: item)),
              ],
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
        ),
      ),
    );
  }
}

class _BreakdownTile extends StatelessWidget {
  final QuizQuestionBreakdown item;

  const _BreakdownTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.isCorrect ? AppColors.success : AppColors.error;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.isCorrect ? Icons.check_circle : Icons.cancel,
                color: color,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.question,
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text('Your answer: ${item.userAnswer.isEmpty ? "No answer" : item.userAnswer}'),
          Text('Correct answer: ${item.correctAnswer}'),
        ],
      ),
    );
  }
}
