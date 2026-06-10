import 'package:ai/features/quiz/providers/quiz_provider.dart';
import 'package:ai/features/quiz/widgets/quiz_history_table.dart';
import 'package:ai/features/quiz/widgets/quiz_option_button.dart';
import 'package:ai/features/quiz/widgets/quiz_question_card.dart';
import 'package:ai/features/quiz/widgets/quiz_result_dialog.dart';
import 'package:ai/features/quiz/screens/sm2_review_quiz.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai/core/animations/app_motion.dart';
import 'package:ai/core/models/quiz.dart';
import 'package:ai/core/theme/colors.dart';
import 'package:ai/core/widgets/appbar.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final TextEditingController _fillController = TextEditingController();
  int _lastQuestionIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final quiz = context.read<QuizProvider>();
      quiz.loadHistory();
      quiz.restoreSavedSession();
    });
  }

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
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

  
  Widget _buildIdleScreen(QuizProvider quiz) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          AnimatedEntry(
            child: Container(
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
                          AppMotion.sharedRoute(Sm2ReviewQuizScreen()),
                        );
                      },
                      icon: Icon(Icons.replay_circle_filled),
                      label: Text(
                        "SM2 Review Quiz",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(height: 28),
                ],
              ),
            ),
          ),

          
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
            QuizHistoryTable(history: quiz.history),
          ],
        ],
      ),
    );
  }

  
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

    if (_lastQuestionIndex != quiz.currentIndex) {
      _lastQuestionIndex = quiz.currentIndex;
      final selected = quiz.selectedAnswer;
      if (question.questionType == 'fill' && selected != null && selected.isNotEmpty) {
        _fillController.text = selected;
      } else {
        _fillController.clear();
      }
    }

    return Column(
      children: [
        
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
                _buildTimerBar(quiz),
                SizedBox(height: 16),
                AnimatedEntry(
                  child: QuizQuestionCard(
                    question: question.question,
                    currentIndex: quiz.currentIndex,
                    total: quiz.currentQuiz!.questions.length,
                  ),
                ),
                SizedBox(height: 24),
                if (question.questionType == 'fill')
                  _buildFillInBlank(quiz)
                else
                  ...question.options.asMap().entries.map(
                    (entry) => AnimatedEntry(
                      index: entry.key + 1,
                      child: QuizOptionButton(
                        label: entry.value,
                        selectedAnswer: quiz.selectedAnswer,
                        correctAnswer: question.correctAnswer,
                        isAnswered: quiz.isAnswered,
                        onTap: () => quiz.selectAnswer(entry.value),
                      ),
                    ),
                  ),
                SizedBox(height: 20),
                if (quiz.isAnswered)
                  _buildAnswerFeedback(quiz, question),
              ],
            ),
          ),
        ),
      ],
    );
  }

  
  Widget _buildFillInBlank(QuizProvider quiz) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _fillController,
            enabled: !quiz.isAnswered,
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
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            style: TextStyle(fontSize: 16),
            onSubmitted: (val) {
              if (!quiz.isAnswered && val.trim().isNotEmpty) {
                quiz.selectAnswer(val.trim());
                _fillController.clear();
              }
            },
          ),
        ),
        SizedBox(height: 16),
        if (!quiz.isAnswered)
          SizedBox(
            width: 200,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                if (_fillController.text.trim().isNotEmpty) {
                  quiz.selectAnswer(_fillController.text.trim());
                  _fillController.clear();
                }
              },
              child: Text(
                "Submit Answer",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTimerBar(QuizProvider quiz) {
    final color = _timerColor(quiz.remainingSeconds);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Time",
              style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "${quiz.remainingSeconds}s",
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(height: 8),
        LinearProgressIndicator(
          value: quiz.timerProgress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: AppColors.border,
          color: color,
        ),
      ],
    );
  }

  Widget _buildAnswerFeedback(QuizProvider quiz, QuizQuestion question) {
    final isCorrect = quiz.isCorrectAnswer(quiz.selectedAnswer);
    final color = isCorrect ? AppColors.success : AppColors.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: color,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  isCorrect
                      ? "Correct"
                      : "Correct answer: ${question.correctAnswer}",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        _buildExplanationPanel(question),
        SizedBox(height: 8),
        Center(
          child: Text(
            quiz.isLastQuestion ? "Preparing results..." : "Next question coming up...",
            style: TextStyle(color: AppColors.textLight),
          ),
        ),
      ],
    );
  }

  Widget _buildExplanationPanel(QuizQuestion question) {
    final meaning = question.correctMeaning;
    final example = question.exampleSentence;
    final tip = question.learningTip;
    final hasDetails = [meaning, example, tip].any((value) => value != null && value.trim().isNotEmpty);
    if (!hasDetails) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Explanation",
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (meaning != null && meaning.trim().isNotEmpty) ...[
            SizedBox(height: 8),
            Text("Meaning: $meaning", style: TextStyle(color: AppColors.textDark)),
          ],
          if (example != null && example.trim().isNotEmpty) ...[
            SizedBox(height: 6),
            Text("Example: $example", style: TextStyle(color: AppColors.textLight)),
          ],
          if (tip != null && tip.trim().isNotEmpty) ...[
            SizedBox(height: 6),
            Text("Tip: $tip", style: TextStyle(color: AppColors.primaryDark)),
          ],
        ],
      ),
    );
  }

  Color _timerColor(int seconds) {
    if (seconds <= 8) return AppColors.error;
    if (seconds <= 15) return AppColors.warning;
    return AppColors.success;
  }

  
  Widget _buildFinishedScreen(QuizProvider quiz) {
    return Center(
      child: QuizResultDialog(
        score: quiz.score,
        total: quiz.currentQuiz?.questions.length ?? 0,
        details: quiz.resultDetails,
        onRetry: () => quiz.startQuiz(),
        onHome: () => quiz.reset(),
      ),
    );
  }

  
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
