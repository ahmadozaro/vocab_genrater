import 'package:ai/features/add_word/providers/word_provider.dart';
import 'package:ai/features/progress/providers/progress_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/core/widgets/appbar.dart';
import 'package:ai/features/quiz/providers/sm2_quiz_provider.dart';

class Sm2ReviewQuizScreen extends StatefulWidget {
  const Sm2ReviewQuizScreen({super.key});

  @override
  State<Sm2ReviewQuizScreen> createState() => _Sm2ReviewQuizScreenState();
}

class _Sm2ReviewQuizScreenState extends State<Sm2ReviewQuizScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<Sm2QuizProvider>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sm2 = context.watch<Sm2QuizProvider>();
    return WillPopScope(
      onWillPop: () => _confirmExit(sm2),
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
        return Center(
          child: ElevatedButton(
            onPressed: sm2.start,
            child: Text("Start SM2 Review"),
          ),
        );
    }
  }

  Widget _active(Sm2QuizProvider sm2) {
    final question = sm2.currentQuestion;
    if (question == null) return SizedBox.shrink();
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
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Question ${sm2.currentIndex + 1} of ${sm2.quiz!.questions.length}",
                  style: TextStyle(color: AppColors.textLight),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(18),
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
                SizedBox(height: 20),
                ...question.options.map((option) {
                  final isSelected = selected == option;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isSelected
                            ? AppColors.primaryLight
                            : AppColors.card,
                        foregroundColor: isSelected
                            ? AppColors.primaryDark
                            : AppColors.textDark,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.black12,
                        ),
                        padding: EdgeInsets.symmetric(
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
                SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _skipCurrent(sm2),
                      child: Text("Skip"),
                    ),
                    Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: () => _continue(sm2),
                      child: Text(
                        sm2.isLastQuestion ? "Submit" : "Next",
                        style: TextStyle(color: Colors.white),
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

  Widget _finished(Sm2QuizProvider sm2) {
    final result = sm2.result ?? {};
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 64),
            SizedBox(height: 16),
            Text(
              "${result['score'] ?? 0}/${result['total'] ?? 0}",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text("Daily streak: ${result['dailyStreak'] ?? 0}"),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (context.mounted) {
                  context.read<ProgressProvider>().refresh();
                  context.read<WordProvider>().loadWords();
                }
                sm2.reset();
                if (context.mounted) Navigator.pop(context);
              },
              child: Text("Done"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _error(Sm2QuizProvider sm2) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              sm2.errorMessage ?? "Something went wrong",
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(onPressed: sm2.start, child: Text("Try Again")),
          ],
        ),
      ),
    );
  }

  Future<void> _continue(Sm2QuizProvider sm2) async {
    if (!sm2.currentIsAnswered && !sm2.currentIsSkipped) {
      final skip = await _showWarning(
        "You did not answer this question. If you skip it, it will be counted as wrong and may affect the next review date.",
      );
      if (!skip) return;
      sm2.markCurrentSkipped();
    }
    if (sm2.isLastQuestion) {
      if (sm2.hasUnansweredQuestions()) {
        final submit = await _showWarning(
          "Some questions are unanswered. Submit them as wrong?",
        );
        if (!submit) return;
      }
      await sm2.submit(confirmEmptyAsWrong: true);
    } else {
      sm2.next();
    }
  }

  Future<void> _skipCurrent(Sm2QuizProvider sm2) async {
    final skip = await _showWarning(
      "You did not answer this question. If you skip it, it will be counted as wrong and may affect the next review date.",
    );
    if (!skip) return;
    sm2.markCurrentSkipped();
    await _continue(sm2);
  }

  Future<bool> _confirmExit(Sm2QuizProvider sm2) async {
    if (sm2.state != Sm2QuizState.active) return true;
    final leave = await _showWarning(
      "If you leave now, this quiz will not be saved, SM2 will not be updated, and the daily streak will not increase.",
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
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("Continue"),
              ),
            ],
          ),
        ) ??
        false;
  }
}
