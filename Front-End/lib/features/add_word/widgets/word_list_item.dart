import 'package:flutter/material.dart';
import 'package:ai/core/animations/app_motion.dart';
import 'package:ai/core/models/word.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/features/words/screens/word_details_screen.dart';

class WordListItem extends StatelessWidget {
  final WordModel word;
  final VoidCallback? onDelete;

  const WordListItem({super.key, required this.word, this.onDelete});

  Color get _accentColor {
    switch (word.status) {
      case 'learning':
        return Colors.deepPurpleAccent;
      case 'review':
        return AppColors.warning;
      case 'hard':
        return AppColors.error;
      case 'mastered':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  String get _statusLabel {
    switch (word.status) {
      case 'learning':
        return 'Learning';
      case 'review':
        return 'Review';
      case 'hard':
        return 'Hard';
      case 'mastered':
        return 'Mastered';
      default:
        return 'New';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            AppMotion.sharedRoute(WordDetailsScreen(wordId: word.wordId)),
          );
        },
        borderRadius: BorderRadius.circular(18),
        splashColor: AppColors.primary.withOpacity(0.15),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 120,
                decoration: BoxDecoration(
                  color: _accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              word.text,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          if (onDelete != null)
                            IconButton(
                              tooltip: 'Delete',
                              icon: Icon(Icons.delete_outline,
                                  color: AppColors.error),
                              onPressed: onDelete,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        word.arabicMeaning ?? 'No Arabic meaning',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _StatusChip(
                            status: _statusLabel,
                            color: _accentColor.withOpacity(0.14),
                            textColor: _accentColor,
                          ),
                          const SizedBox(width: 8),
                          if (word.examples.isNotEmpty) ...[
                            Icon(Icons.article_outlined,
                                size: 14, color: AppColors.textLight),
                            const SizedBox(width: 4),
                            Text(
                              '${word.examples.length} examples',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.textLight),
                            ),
                          ],
                          if (word.audio != null && word.audio!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Row(
                                children: [
                                  Icon(Icons.volume_up,
                                      size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Audio',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap for details',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;
  final Color textColor;

  const _StatusChip({
    required this.status,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
