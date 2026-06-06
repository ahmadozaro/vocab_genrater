import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai/core/models/testslevel_m.dart';
import 'package:ai/features/placement_tests/logic/quiz_logic.dart';
import 'package:ai/features/placement_tests/widgets/difficulty_badge.dart';
import 'package:ai/features/placement_tests/widgets/option_button.dart';
import 'package:ai/core/providers/auth_provider.dart';
import 'package:ai/core/navigation/navigation_all.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/core/widgets/appbar.dart';

class TestScreen extends StatefulWidget {
  final bool isRetake;
  const TestScreen({super.key, this.isRetake = false});
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final QuizLogic _logic = QuizLogic();

  void _answerQuestion(int index) {
    setState(() => _logic.answerQuestion(index));
  }

  void _nextQuestion() {
    final isDone = _logic.nextQuestion();
    setState(() {});
    if (isDone) _finishQuiz();
  }

  Future<void> _finishQuiz() async {
    final level = _logic.calculateLevel();
    if (!mounted) return;

    final screenContext = context;

    await showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Test Completed!",
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Your Score: ${_logic.correctCount} / ${_logic.maxQuestions}",
              style: TextStyle(fontSize: 16, color: AppColors.textDark),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "Your Level: $level",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Your level has been saved!",
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.pop(dialogContext);

              if (widget.isRetake) {
                Navigator.pop(screenContext, level);
              } else {
                await Provider.of<AuthProvider>(
                  screenContext,
                  listen: false,
                ).completeQuiz(detectedLevel: level);
                if (!screenContext.mounted) return;
                Navigator.pushAndRemoveUntil(
                  screenContext,
                  MaterialPageRoute(builder: (_) => Navigation()),
                  (route) => false,
                );
              }
            },
            child: Text("Continue", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _skipLevelTest() async {
    await context.read<AuthProvider>().skipLevelTest();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => Navigation()),
      (route) => false,
    );
  }

  void _showHintDialog(String hint) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Hint", style: TextStyle(color: AppColors.primary)),
        content: Text(hint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = _logic.currentQuestion;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: LearningAppBar(
        title: "Level Test",
        subtitle: "Question ${_logic.questionsAsked} of ${_logic.maxQuestions}",
        icon: Icons.school_outlined,
        metricLabel: "Score",
        metricValue: "${_logic.correctCount}",
        progress: _logic.progress,
        showBackButton: widget.isRetake,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.text,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  DifficultyBadge(difficulty: question.level),
                ],
              ),
            ),
            if (!widget.isRetake) ...[
              SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: Icon(Icons.skip_next_rounded, color: AppColors.primary),
                  label: Text(
                    "Skip Level Test",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _skipLevelTest,
                ),
              ),
            ],
            SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: Icon(Icons.lightbulb_outline, color: AppColors.warning),
                label: Text(
                  "Show Hint",
                  style: TextStyle(color: AppColors.secondary),
                ),
                onPressed: () => _showHintDialog(question.hint),
              ),
            ),
            SizedBox(height: 10),
            ...List.generate(
              question.options.length,
              (i) => OptionButton(
                index: i,
                label: question.options[i],
                correctIndex: question.correctIndex,
                selectedIndex: _logic.selectedIndex,
                isAnswered: _logic.isAnswered,
                onTap: () => _answerQuestion(i),
              ),
            ),
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _logic.isAnswered ? _nextQuestion : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.navInactive,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _logic.isLastQuestion ? "Finish Quiz" : "Next Question",
                  style: TextStyle(fontSize: 18, color: AppColors.textWhite),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
