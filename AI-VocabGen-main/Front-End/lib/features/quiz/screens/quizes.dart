import 'package:ai/features/quiz/providers/quiz_provider.dart';
import 'package:ai/features/quiz/widgets/quiz_history_card.dart';
import 'package:ai/features/quiz/widgets/quiz_option_button.dart';
import 'package:ai/features/quiz/widgets/quiz_question_card.dart';
import 'package:ai/features/quiz/widgets/quiz_result_dialog.dart';
import 'package:ai/features/quiz/screens/sm2_review_quiz.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/core/widgets/appbar.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: LearningAppBar(
        title: "Quiz",
        subtitle: quiz.state == QuizState.active
            ? "Question ${quiz.currentIndex + 1} in progress"
            : "Practice and strengthen your words",
        icon: Icons.quiz_outlined,
        metricLabel: quiz.state == QuizState.active ? "Score" : "History",
        metricValue: quiz.state == QuizState.active
            ? "${quiz.score}"
            : "${quiz.history.length}",
        progress: quiz.state == QuizState.active ? quiz.progress : null,
      ),
      body: _buildBody(quiz),
    );
  }

  Widget _buildBody(QuizProvider quiz) {
    switch (quiz.state) {
      case QuizState.idle:
        return _buildIdleScreen(quiz);
      case QuizState.loading:
        return Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      case QuizState.active:
        return _buildActiveQuiz(quiz);
      case QuizState.finished:
        return _buildFinishedScreen(quiz);
      case QuizState.error:
        return _buildErrorScreen(quiz);
    }
  }

  // ─── شاشة البداية ──────────────────────────────────────────────
  Widget _buildIdleScreen(QuizProvider quiz) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // بطاقة بدء الكويز
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(Icons.quiz, color: Colors.white, size: 60),
                SizedBox(height: 16),
                Text(
                  "Test Your Vocabulary!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Practice words you've learned and track your progress",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: quiz.startQuiz,
                        child: Text(
                          "Recent Quiz",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.8),
                          foregroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: quiz.startAiReviewQuiz,
                        child: Text(
                          "AI Review",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Sm2ReviewQuizScreen(),
                        ),
                      );
                    },
                    icon: Icon(Icons.replay_circle_filled),
                    label: Text(
                      "SM2 Review Quiz",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 28),

          // سجل الكويزات
          if (quiz.history.isNotEmpty) ...[
            Text(
              "Recent Quizzes",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            ...quiz.history.map((h) => QuizHistoryCard(history: h)),
          ],
        ],
      ),
    );
  }

  // ─── الكويز النشط ──────────────────────────────────────────────
  Widget _buildActiveQuiz(QuizProvider quiz) {
    final question = quiz.currentQuestion;
    if (question == null) {
      return Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: quiz.reset,
          child: Text("Exit Quiz", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Column(
      children: [
        // شريط التقدم
        LinearProgressIndicator(
          value: quiz.progress,
          backgroundColor: AppColors.primaryLight,
          color: AppColors.primaryDark,
          minHeight: 6,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: quiz.reset,
                    icon: Icon(Icons.close),
                    label: Text("Exit Quiz"),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                QuizQuestionCard(
                  question: question.question,
                  currentIndex: quiz.currentIndex,
                  total: quiz.currentQuiz!.questions.length,
                ),
                SizedBox(height: 24),
                ...question.options.map(
                  (opt) => QuizOptionButton(
                    label: opt,
                    selectedAnswer: quiz.selectedAnswer,
                    correctAnswer: question.correctAnswer,
                    isAnswered: quiz.isAnswered,
                    onTap: () => quiz.selectAnswer(opt),
                  ),
                ),
                SizedBox(height: 20),
                if (quiz.isAnswered)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: quiz.nextQuestion,
                      child: Text(
                        quiz.isLastQuestion ? "See Results" : "Next Question",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── شاشة النتيجة ──────────────────────────────────────────────
  Widget _buildFinishedScreen(QuizProvider quiz) {
    return Center(
      child: QuizResultDialog(
        score: quiz.score,
        total: quiz.currentQuiz?.questions.length ?? 0,
        onRetry: () => quiz.startQuiz(),
        onHome: () => quiz.reset(),
      ),
    );
  }

  // ─── شاشة الخطأ ────────────────────────────────────────────────
  Widget _buildErrorScreen(QuizProvider quiz) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 60),
          SizedBox(height: 16),
          Text(
            quiz.errorMessage ?? 'Something went wrong',
            style: TextStyle(color: AppColors.textLight),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: quiz.startQuiz,
            child: Text("Try Again", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
