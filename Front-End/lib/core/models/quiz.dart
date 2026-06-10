class QuizQuestion {
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String questionType;
  final String? correctMeaning;
  final String? exampleSentence;
  final String? learningTip;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.questionType = 'mcq',
    this.correctMeaning,
    this.exampleSentence,
    this.learningTip,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] ?? json['questionText'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'] ?? json['correct_answer'] ?? '',
      questionType: json['questionType'] ?? json['question_type'] ?? 'mcq',
      correctMeaning: json['correctMeaning'] ?? json['correct_meaning'],
      exampleSentence: json['exampleSentence'] ?? json['example_sentence'],
      learningTip: json['learningTip'] ?? json['learning_tip'],
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correctAnswer': correctAnswer,
        'questionType': questionType,
        'correctMeaning': correctMeaning,
        'exampleSentence': exampleSentence,
        'learningTip': learningTip,
      };
}

class QuizModel {
  final int quizId;
  final List<QuizQuestion> questions;

  QuizModel({required this.quizId, required this.questions});

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(
      quizId: json['quiz_id'] ?? json['quizId'] ?? json['id'] ?? 0,
      questions: (json['questions'] as List? ?? [])
          .map((q) => QuizQuestion.fromJson(Map<String, dynamic>.from(q)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'quiz_id': quizId,
        'questions': questions.map((q) => q.toJson()).toList(),
      };
}

class QuizHistory {
  final int quizId;
  final int score;
  final int questionsCount;
  final String date;
  final String? quizType;

  QuizHistory({
    required this.quizId,
    required this.score,
    required this.questionsCount,
    required this.date,
    this.quizType,
  });

  factory QuizHistory.fromJson(Map<String, dynamic> json) {
    return QuizHistory(
      quizId: json['quizId'] ?? json['quiz_id'] ?? json['id'] ?? 0,
      score: json['score'] ?? 0,
      questionsCount: json['questionsCount'] ??
          json['total_questions'] ??
          json['total'] ??
          0,
      date: json['date'] ?? json['started_at'] ?? json['submitted_at'] ?? '',
      quizType: json['quizType'] ?? json['quiz_type'] ?? json['type'],
    );
  }

  String get formattedDate {
    if (date.isEmpty) return 'No date';
    try {
      final dt = DateTime.parse(date);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return date;
    }
  }
}

class QuizQuestionBreakdown {
  final String question;
  final String userAnswer;
  final String correctAnswer;
  final bool isCorrect;

  QuizQuestionBreakdown({
    required this.question,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
  });

  factory QuizQuestionBreakdown.fromJson(Map<String, dynamic> json) {
    return QuizQuestionBreakdown(
      question: json['question'] ?? json['questionText'] ?? '',
      userAnswer: json['userAnswer'] ?? json['user_answer'] ?? '',
      correctAnswer: json['correctAnswer'] ?? json['correct_answer'] ?? '',
      isCorrect: json['isCorrect'] ?? json['is_correct'] ?? false,
    );
  }
}

class QuizResultDetails {
  final int score;
  final int total;
  final double percentage;
  final String grade;
  final List<QuizQuestionBreakdown> breakdown;

  QuizResultDetails({
    required this.score,
    required this.total,
    required this.percentage,
    required this.grade,
    required this.breakdown,
  });

  factory QuizResultDetails.fromJson(Map<String, dynamic> json) {
    return QuizResultDetails(
      score: json['score'] ?? 0,
      total: json['total'] ?? json['totalQuestions'] ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      grade: json['grade'] ?? 'Needs Work',
      breakdown: (json['breakdown'] as List? ?? [])
          .map((item) =>
              QuizQuestionBreakdown.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}
