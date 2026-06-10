import 'package:ai/features/add_word/providers/word_provider.dart';
import 'package:ai/features/progress/providers/progress_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/core/widgets/appbar.dart';
import 'package:ai/features/quiz/providers/sm2_quiz_provider.dart';

enum _UnansweredAction {
  cancel,
  review,
  submit,
}

class Sm2ReviewQuizScreen extends StatefulWidget {
  const Sm2ReviewQuizScreen({super.key});

  @override
  State<Sm2ReviewQuizScreen> createState() => _Sm2ReviewQuizScreenState();
}

class _Sm2ReviewQuizScreenState extends State<Sm2ReviewQuizScreen> {
  final Map<int, TextEditingController> _fillControllers = {};

  @override
  void initState() {
    super.initState();
  }

  void _clearFillControllers() {
    for (final controller in _fillControllers.values) {
      controller.dispose();
    }
    _fillControllers.clear();
  }

  @override
  void dispose() {
    _clearFillControllers();
    super.dispose();
  }

  
  
  

  @override
  Widget build(BuildContext context) {
    final sm2 = context.watch<Sm2QuizProvider>();

    
    
    
    return PopScope(
      canPop: sm2.state != Sm2QuizState.active,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return; 
        final leave = await _confirmExit(sm2);
        if (leave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: LearningAppBar(
          title: "SM2 Review",
          subtitle: sm2.state == Sm2QuizState.active && sm2.quiz != null
              ? "Question ${sm2.currentIndex + 1} of ${sm2.quiz!.questions.length}"
              : "Review words at the right time",
          icon: Icons.replay_circle_filled_rounded,
          metricLabel: "Mode",
          metricValue: "SM2",
          progress: sm2.state == Sm2QuizState.active ? sm2.progress : null,
          showBackButton: true,
        ),
        body: _body(sm2),
      ),
    );
  }

  
  
  

  Widget _body(Sm2QuizProvider sm2) {
    switch (sm2.state) {
      case Sm2QuizState.loading:
      case Sm2QuizState.submitting:
        return Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      case Sm2QuizState.active:
        return _active(sm2);
      case Sm2QuizState.finished:
        return _finished(sm2);
      case Sm2QuizState.error:
        return _error(sm2);
      case Sm2QuizState.idle:
        final progress = context.watch<ProgressProvider>();
        final wordProvider = context.watch<WordProvider>();
        final now = DateTime.now();
        final dueWordsPreview = wordProvider.words
            .where((w) {
              if ((w.status ?? '') == 'pending') return false;
              if (w.nextReviewDate == null) return true;
              try {
                return DateTime.parse(w.nextReviewDate!).isBefore(now);
              } catch (_) {
                return false;
              }
            })
            .take(5)
            .toList();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.replay_circle_filled_rounded,
                  size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Ready for review',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                progress.dueReviewCount > 0
                    ? 'You have ${progress.dueReviewCount} words due for SM2 review.'
                    : 'No words are due for review yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight),
              ),
              const SizedBox(height: 20),
              if (dueWordsPreview.isNotEmpty) ...[
                Text(
                  'Due words',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...dueWordsPreview.map((word) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              word.text,
                              style: TextStyle(
                                color: AppColors.textDark,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 20),
              ],
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                onPressed: () {
                  _clearFillControllers();
                  sm2.start();
                },
                child: const Text(
                  "Start SM2 Review",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
    }
  }

  
  
  

  Widget _active(Sm2QuizProvider sm2) {
    final question = sm2.currentQuestion;
    if (question == null) return const SizedBox.shrink();
    final selected = sm2.selectedAnswerForCurrent();

    return Column(
      children: [
        LinearProgressIndicator(
          value: sm2.progress,
          minHeight: 6,
          backgroundColor: AppColors.primaryLight,
          color: AppColors.primaryDark,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Question ${sm2.currentIndex + 1} of ${sm2.quiz!.questions.length}",
                  style: TextStyle(color: AppColors.textLight),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    question.questionText,
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (question.questionType == 'fill')
                  _sm2FillInBlank(sm2, selected)
                else
                  ...question.options.map((option) {
                    final isSelected = selected == option;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isSelected
                              ? AppColors.primaryLight
                              : AppColors.card,
                          foregroundColor: isSelected
                              ? AppColors.primaryDark
                              : AppColors.textDark,
                          side: BorderSide(
                            color:
                                isSelected ? AppColors.primary : Colors.black12,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => sm2.selectAnswer(option),
                        child: Text(option, textAlign: TextAlign.center),
                      ),
                    );
                  }),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _skipCurrent(sm2),
                      child: const Text("Skip"),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: () => _continue(sm2),
                      child: Text(
                        sm2.isLastQuestion ? "Submit" : "Next",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sm2FillInBlank(Sm2QuizProvider sm2, String? selected) {
    final question = sm2.currentQuestion;
    if (question == null) return const SizedBox.shrink();

    final controller = _fillControllers.putIfAbsent(
      question.itemId,
      () => TextEditingController(text: selected ?? ''),
    );

    if ((selected ?? '').isEmpty &&
        sm2.currentIsSkipped &&
        controller.text.isNotEmpty) {
      controller.clear();
    }

    return Column(
      children: [
        TextField(
          controller: controller,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: "Type your answer...",
            hintTextDirection: TextDirection.ltr,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
          style: const TextStyle(fontSize: 16),
          onChanged: (val) => sm2.selectAnswer(val.trim()),
          onSubmitted: (val) => sm2.selectAnswer(val.trim()),
        ),
      ],
    );
  }

  
  
  

  Widget _finished(Sm2QuizProvider sm2) {
    final result = sm2.result ?? {};
    final score = result['score'] ?? 0;
    final total = result['total'] ?? 0;
    final dailyStreak = result['dailyStreak'] ?? 0;
    final streakCount = result['countsForStreak'] ?? 0;
    final results = (result['results'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final wrongItems = _extractWrongItems(results);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 64),
              const SizedBox(height: 16),
              Text(
                "SM2 Review Complete",
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Score: $score of $total",
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Daily streak: $dailyStreak",
                style: TextStyle(color: AppColors.textLight),
              ),
              const SizedBox(height: 4),
              Text(
                "Streak progress: $streakCount",
                style: TextStyle(color: AppColors.textLight),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _resultDetailRow(label: 'Mode', value: 'SM2 Review'),
                    const SizedBox(height: 8),
                    _resultDetailRow(label: 'Questions', value: '$total'),
                    const SizedBox(height: 8),
                    _resultDetailRow(label: 'Score', value: '$score'),
                    const SizedBox(height: 8),
                    _resultDetailRow(
                      label: 'Updated words',
                      value: '${results.length}',
                    ),
                  ],
                ),
              ),
              if (results.isNotEmpty) ...[
                const SizedBox(height: 20),
                _resultSummarySection(results),
              ],
              if (wrongItems.isNotEmpty) ...[
                const SizedBox(height: 20),
                _learningInsightsSection(wrongItems),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                onPressed: () async {
                  if (context.mounted) {
                    context.read<ProgressProvider>().refresh();
                    await context
                        .read<WordProvider>()
                        .loadWords(forceRefresh: true);
                  }
                  if (!mounted) return;
                  sm2.reset();
                  Navigator.pop(context);
                },
                child: const Text(
                  "Done",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ], 
          ), 
        ), 
      ), 
    ); 
  }

  List<Map<String, dynamic>> _extractWrongItems(dynamic rawResults) {
    final results = rawResults is List ? rawResults : [];
    return results
        .whereType<Map<String, dynamic>>()
        .where((item) => (item['errorType']?.toString() ?? 'none') != 'none')
        .toList();
  }

  Widget _learningInsightsSection(List<Map<String, dynamic>> wrongItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Learning insights',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...wrongItems.map((item) {
          final word = item['word']?.toString() ?? 'Unknown word';
          final insight = item['learningInsight']?.toString() ?? '';
          final action = item['smartAction']?.toString();
          final sm2 = item['sm2'] as Map<String, dynamic>?;
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word,
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (insight.isNotEmpty)
                  Text(
                    insight,
                    style: TextStyle(color: AppColors.textLight),
                  ),
                if (action != null && action.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Recommendation: $action',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (sm2 != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'SM2 update',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _resultDetailRow(
                    label: 'Next review',
                    value: sm2['next_review_label']?.toString() ?? '-',
                  ),
                  if (sm2['new_interval_days'] != null) ...[
                    const SizedBox(height: 6),
                    _resultDetailRow(
                      label: 'Interval',
                      value: '${sm2['new_interval_days']}',
                    ),
                  ],
                  if (sm2['new_ease_factor'] != null) ...[
                    const SizedBox(height: 6),
                    _resultDetailRow(
                      label: 'Ease factor',
                      value: '${sm2['new_ease_factor']}',
                    ),
                  ],
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _resultDetailRow({required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textLight)),
        Text(value,
            style: TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _resultSummarySection(List<Map<String, dynamic>> results) {
    final correctCount =
        results.where((item) => item['isCorrect'] == true).length;
    final incorrectCount = results.length - correctCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'SM2 result details',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _resultDetailRow(
                  label: 'Total reviewed', value: '${results.length}'),
              const SizedBox(height: 8),
              _resultDetailRow(
                  label: 'Correct answers', value: '$correctCount'),
              const SizedBox(height: 8),
              _resultDetailRow(
                  label: 'Incorrect answers', value: '$incorrectCount'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _error(Sm2QuizProvider sm2) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              sm2.errorMessage ?? "Something went wrong",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _clearFillControllers();
                sm2.start();
              },
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }

  
  
  

  Future<void> _continue(Sm2QuizProvider sm2) async {
    if (!sm2.currentIsAnswered && !sm2.currentIsSkipped) {
      final skip = await _showWarning(
        "You did not answer this question. "
        "If you skip it, it will be counted as wrong and may affect the next review date.",
      );
      if (!skip) return;
      sm2.markCurrentSkipped();
    }
    if (sm2.isLastQuestion) {
      if (sm2.hasUnansweredQuestions()) {
        final action = await _showUnansweredDialog();
        if (action == _UnansweredAction.cancel) return;
        if (action == _UnansweredAction.review) {
          sm2.goToFirstUnanswered();
          return;
        }
      }
      await sm2.submit(confirmEmptyAsWrong: true);
    } else {
      sm2.next();
    }
  }

  Future<void> _skipCurrent(Sm2QuizProvider sm2) async {
    final skip = await _showWarning(
      "You did not answer this question. "
      "If you skip it, it will be counted as wrong and may affect the next review date.",
    );
    if (!skip) return;
    sm2.markCurrentSkipped();
    
    if (sm2.isLastQuestion) {
      await sm2.submit(confirmEmptyAsWrong: true);
    } else {
      sm2.next();
    }
  }

  Future<bool> _confirmExit(Sm2QuizProvider sm2) async {
    if (sm2.state != Sm2QuizState.active) return true;
    final leave = await _showWarning(
      "If you leave now, this quiz will not be saved, "
      "SM2 will not be updated, and the daily streak will not increase.",
    );
    if (leave) {
      await sm2.abandon();
      if (mounted) {
        context.read<ProgressProvider>().refresh();
        context.read<WordProvider>().loadWords();
      }
    }
    return leave;
  }

  Future<bool> _showWarning(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Continue"),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<_UnansweredAction> _showUnansweredDialog() async {
    return await showDialog<_UnansweredAction>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unanswered questions'),
            content: const Text(
              'Some questions are unanswered. Submit them as wrong, or review unanswered questions first.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _UnansweredAction.cancel),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _UnansweredAction.review),
                child: const Text('Review unanswered'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, _UnansweredAction.submit),
                child: const Text('Submit as wrong'),
              ),
            ],
          ),
        ) ??
        _UnansweredAction.cancel;
  }
}
