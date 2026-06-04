import 'package:ai/core/animations/app_motion.dart';
import 'package:ai/core/models/quiz.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:flutter/material.dart';

class QuizHistoryTable extends StatelessWidget {
  final List<QuizHistory> history;

  const QuizHistoryTable({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final latest = history.first;
    final best = history.reduce((a, b) => _percent(a) >= _percent(b) ? a : b);
    final average = history.isEmpty
        ? 0
        : (history.map(_percent).reduce((a, b) => a + b) / history.length)
              .round();
    final trend = history.length < 2
        ? 0
        : _percent(history.first) - _percent(history[1]);

    return Column(
      children: [
        AnimatedEntry(
          child: Row(
            children: [
              _SummaryTile(
                icon: Icons.insights_rounded,
                label: 'Average',
                value: '$average%',
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              _SummaryTile(
                icon: Icons.emoji_events_rounded,
                label: 'Best',
                value: '${_percent(best)}%',
                color: AppColors.warning,
              ),
              SizedBox(width: 10),
              _SummaryTile(
                icon: trend >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                label: 'Change',
                value: _deltaText(trend),
                color: trend >= 0 ? AppColors.success : AppColors.error,
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        AnimatedEntry(
          index: 1,
          child: Container(
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
            child: Column(
              children: [
                _HeaderRow(),
                Divider(height: 1, color: AppColors.border),
                ...history.take(6).toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final previous = index + 1 < history.length
                      ? history[index + 1]
                      : null;
                  return _HistoryRow(
                    history: item,
                    previous: previous,
                    bestPercent: _percent(best),
                    averagePercent: average,
                    isLatest: item.quizId == latest.quizId,
                    showDivider: index < history.take(6).length - 1,
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static int _percent(QuizHistory item) {
    if (item.questionsCount <= 0) return 0;
    return (item.score / item.questionsCount * 100).round().clamp(0, 100);
  }

  static String _deltaText(int value) {
    if (value == 0) return '0%';
    return value > 0 ? '+$value%' : '$value%';
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedLearningCard(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textLight, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _HeaderCell(label: 'Quiz', flex: 2),
          _HeaderCell(label: 'Score', flex: 2),
          _HeaderCell(label: 'Rate', flex: 2),
          _HeaderCell(label: 'Change', flex: 2, alignEnd: true),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  final bool alignEnd;

  const _HeaderCell({
    required this.label,
    required this.flex,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: TextStyle(
          color: AppColors.textLight,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final QuizHistory history;
  final QuizHistory? previous;
  final int bestPercent;
  final int averagePercent;
  final bool isLatest;
  final bool showDivider;

  const _HistoryRow({
    required this.history,
    required this.previous,
    required this.bestPercent,
    required this.averagePercent,
    required this.isLatest,
    required this.showDivider,
  });

  int get _percent {
    if (history.questionsCount <= 0) return 0;
    return (history.score / history.questionsCount * 100).round().clamp(0, 100);
  }

  int? get _delta {
    final previousItem = previous;
    if (previousItem == null || previousItem.questionsCount <= 0) return null;
    final previousPercent =
        (previousItem.score / previousItem.questionsCount * 100).round().clamp(
          0,
          100,
        );
    return _percent - previousPercent;
  }

  Color get _scoreColor {
    if (_percent >= 70) return AppColors.success;
    if (_percent >= 50) return AppColors.warning;
    return AppColors.error;
  }

  String get _statusLabel {
    if (_percent >= 85) return 'Excellent';
    if (_percent >= 70) return 'Strong';
    if (_percent >= 50) return 'Needs review';
    return 'Practice more';
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _scoreColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.quiz_rounded, color: _scoreColor),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quiz #${history.quizId}',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        history.date.isEmpty ? 'No date saved' : history.date,
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(label: _statusLabel, color: _scoreColor),
              ],
            ),
            SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (_percent / 100).clamp(0.0, 1.0),
                minHeight: 9,
                backgroundColor: AppColors.primaryLight,
                color: _scoreColor,
              ),
            ),
            SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DetailTile(
                  icon: Icons.check_circle_rounded,
                  label: 'Score',
                  value: '${history.score}/${history.questionsCount}',
                  color: _scoreColor,
                ),
                _DetailTile(
                  icon: Icons.percent_rounded,
                  label: 'Rate',
                  value: '$_percent%',
                  color: _scoreColor,
                ),
                _DetailTile(
                  icon: _deltaIcon,
                  label: 'Change',
                  value: _deltaText,
                  color: _deltaColor,
                ),
                _DetailTile(
                  icon: Icons.emoji_events_rounded,
                  label: 'Best',
                  value: '$bestPercent%',
                  color: AppColors.warning,
                ),
                _DetailTile(
                  icon: Icons.insights_rounded,
                  label: 'Average',
                  value: '$averagePercent%',
                  color: AppColors.primary,
                ),
                _DetailTile(
                  icon: Icons.tag_rounded,
                  label: 'Questions',
                  value: '${history.questionsCount}',
                  color: AppColors.secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData get _deltaIcon {
    final delta = _delta;
    if (delta == null || delta == 0) return Icons.remove_rounded;
    return delta > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded;
  }

  Color get _deltaColor {
    final delta = _delta;
    if (delta == null || delta == 0) return AppColors.textLight;
    return delta > 0 ? AppColors.success : AppColors.error;
  }

  String get _deltaText {
    final delta = _delta;
    if (delta == null) return '--';
    if (delta == 0) return '0%';
    return delta > 0 ? '+$delta%' : '$delta%';
  }

  @override
  Widget build(BuildContext context) {
    final delta = _delta;
    final deltaColor = delta == null || delta == 0
        ? AppColors.textLight
        : delta > 0
        ? AppColors.success
        : AppColors.error;

    return PressableScale(
      onTap: () => _showDetails(context),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Icon(
                        isLatest
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isLatest
                            ? AppColors.primary
                            : AppColors.textLight,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '#${history.quizId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${history.score}/${history.questionsCount}',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Icon(Icons.percent_rounded, size: 14, color: _scoreColor),
                      SizedBox(width: 4),
                      Text(
                        '$_percent%',
                        style: TextStyle(
                          color: _scoreColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(_deltaIcon, size: 16, color: deltaColor),
                      SizedBox(width: 4),
                      Text(
                        _deltaText,
                        style: TextStyle(
                          color: deltaColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: deltaColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showDivider) Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textLight, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
