import 'package:flutter/material.dart';
import 'package:ai/core/models/word.dart';
import 'package:ai/core/theme/colors.dart';

class WordListItem extends StatelessWidget {
  final WordModel word;

  const WordListItem({super.key, required this.word});

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return SingleChildScrollView(
            controller: controller,
            padding: EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        word.text,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    _StatusChip(status: word.status ?? 'new'),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  word.arabicMeaning ?? 'No Arabic meaning',
                  style: TextStyle(fontSize: 18, color: AppColors.primary),
                ),
                Divider(height: 28),
                _Section(
                  title: 'Definition',
                  value: word.definition ?? 'No definition saved yet.',
                ),
                SizedBox(height: 16),
                Text(
                  'Examples',
                  style: TextStyle(fontSize: 13, color: AppColors.textLight),
                ),
                SizedBox(height: 8),
                if (word.examples.isEmpty)
                  Text(
                    'No example saved yet.',
                    style: TextStyle(color: AppColors.textDark),
                  )
                else
                  ...word.examples.map(
                    (e) => Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.circle, size: 7, color: AppColors.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(e, style: TextStyle(height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: 20),
                Text(
                  'SM2 Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoBox(label: 'Score', value: '${word.score}'),
                    _InfoBox(label: 'Repeats', value: '${word.sm2Repeats}'),
                    _InfoBox(
                      label: 'Ease',
                      value: word.sm2EaseFactor.toStringAsFixed(2),
                    ),
                    _InfoBox(
                      label: 'Interval',
                      value: '${word.sm2IntervalDays} d',
                    ),
                    _InfoBox(label: 'Correct', value: '${word.correctStreak}'),
                    _InfoBox(label: 'Wrong', value: '${word.wrongStreak}'),
                  ],
                ),
                SizedBox(height: 14),
                _Section(
                  title: 'Next Review',
                  value: word.nextReviewDate ?? 'Due now',
                ),
                SizedBox(height: 8),
                _Section(
                  title: 'Last Reviewed',
                  value: word.lastReviewedAt ?? 'Not reviewed yet',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showDetails(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(14),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.text_fields,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.text,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    word.arabicMeaning ?? 'No Arabic meaning',
                    style: TextStyle(fontSize: 13, color: AppColors.textLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusChip(status: word.status ?? 'new'),
                SizedBox(height: 6),
                Text(
                  '⭐ ${word.score}',
                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String value;
  const _Section({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, color: AppColors.textLight)),
        SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textDark,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;
  const _InfoBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}
