import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai/core/animations/app_motion.dart';
import 'package:ai/core/models/word.dart';
import 'package:ai/core/services/api.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/core/widgets/appbar.dart';
import 'package:ai/core/providers/notification_provider.dart';
import 'package:ai/features/add_word/providers/word_provider.dart';
import 'package:ai/features/progress/providers/progress_provider.dart';
import 'package:ai/features/quiz/providers/sm2_quiz_provider.dart';

class WordDetailsScreen extends StatefulWidget {
  final int wordId;

  const WordDetailsScreen({super.key, required this.wordId});

  @override
  State<WordDetailsScreen> createState() => _WordDetailsScreenState();
}

class _WordDetailsScreenState extends State<WordDetailsScreen> {
  WordModel? _word;
  bool _isLoading = true;
  String? _error;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadWord();
  }

  Future<void> _loadWord() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _word = await ApiService.getWord(widget.wordId);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteWord() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Word'),
        content: const Text(
          'Are you sure you want to delete this word from your words?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isDeleting = true);
    try {
      await ApiService.deleteWord(widget.wordId);
      if (!mounted) return;
      await Future.wait([
        context.read<WordProvider>().loadWords(),
        context.read<ProgressProvider>().refresh(),
        context.read<NotificationProvider>().sync(),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Word deleted successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: LearningAppBar(
        title: _word?.text ?? 'Word Details',
        subtitle: _word?.arabicMeaning ?? '',
        icon: Icons.menu_book_rounded,
        metricLabel: 'Status',
        metricValue: _word?.status?.toUpperCase() ?? '',
        showBackButton: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 56),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadWord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Retry',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    final word = _word!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Section(title: 'English Word', value: word.text),
          if (word.arabicMeaning != null && word.arabicMeaning!.isNotEmpty)
            _Section(title: 'Arabic Meaning', value: word.arabicMeaning!),
          if (word.definition != null && word.definition!.isNotEmpty)
            _Section(title: 'Definition', value: word.definition!),
          if (word.examples.isNotEmpty) ...[
            _Section(title: 'Example Sentences', value: word.examples.join('\n')),
          ],
          if (word.source != null && word.source!.isNotEmpty)
            _Section(title: 'Source', value: word.source!),
          const SizedBox(height: 16),
          Text(
            'Learning Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
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
              _InfoBox(label: 'Interval', value: '${word.sm2IntervalDays}d'),
              _InfoBox(label: 'Correct Streak', value: '${word.correctStreak}'),
              _InfoBox(label: 'Wrong Streak', value: '${word.wrongStreak}'),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Next Review',
            value: word.nextReviewDate ?? 'Due now',
          ),
          _Section(
            title: 'Last Reviewed',
            value: word.lastReviewedAt ?? 'Not reviewed yet',
          ),
          if (word.addedAt != null)
            _Section(title: 'Added', value: word.addedAt!),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isDeleting ? null : _deleteWord,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_outline),
              label: Text(
                _isDeleting ? 'Deleting...' : 'Delete Word',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textDark,
              height: 1.4,
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(12),
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
