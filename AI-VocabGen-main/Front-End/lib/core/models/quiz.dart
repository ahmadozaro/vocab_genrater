class QuizQuestion {
  final String question;
  final List<String> options;
  final String correctAnswer; // ← أضف

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'] ?? '', // ← أضف
    );
  }
}

class QuizModel {
  final int quizId;
  final List<QuizQuestion> questions;

  QuizModel({required this.quizId, required this.questions});

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(
      quizId: json['quiz_id'], // ← من الـ backend
      questions: (json['questions'] as List)
          .map((q) => QuizQuestion.fromJson(q))
          .toList(),
    );
  }
}

class QuizHistory {
  final int quizId;
  final int score;
  final int questionsCount;
  final String date;

  QuizHistory({
    required this.quizId,
    required this.score,
    required this.questionsCount,
    required this.date,
  });

  factory QuizHistory.fromJson(Map<String, dynamic> json) {
    return QuizHistory(
      quizId: json['quizId'],
      score: json['score'] ?? 0,
      questionsCount: json['questionsCount'] ?? 0,
      date: json['date'] ?? '',
    );
  }
}
