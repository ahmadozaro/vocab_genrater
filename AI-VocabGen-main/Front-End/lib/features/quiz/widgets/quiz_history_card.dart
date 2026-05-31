import 'package:flutter/material.dart';
import 'package:ai/core/models/quiz.dart';
import 'package:ai/core/theme/colors.dart';

class QuizHistoryCard extends StatelessWidget {
  final QuizHistory history;

  const QuizHistoryCard({super.key, required this.history});

  String _getPercentText() {
    if (history.questionsCount <= 0) return '0%';
    final percent = (history.score / history.questionsCount * 100)
        .round()
        .clamp(0, 100);
    return '$percent%';
  }

  Color get _scoreColor {
    final safeTotal = history.questionsCount <= 0 ? 1 : history.questionsCount;
    final percent = history.score / safeTotal;
    if (percent >= 0.7) return AppColors.success;
    if (percent >= 0.5) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _scoreColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.quiz, color: _scoreColor),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Quiz #${history.quizId}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  history.date,
                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${history.score}/${history.questionsCount}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _scoreColor,
                  fontSize: 16,
                ),
              ),
              Text(
                _getPercentText(),
                style: TextStyle(fontSize: 12, color: _scoreColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
