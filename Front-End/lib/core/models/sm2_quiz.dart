class Sm2Question {
  final int itemId;
  final int userWordId;
  final String questionText;
  final String questionType;
  final List<String> options;

  Sm2Question({
    required this.itemId,
    required this.userWordId,
    required this.questionText,
    required this.questionType,
    required this.options,
  });

  factory Sm2Question.fromJson(Map<String, dynamic> json) {
    return Sm2Question(
      itemId: json['itemId'] ?? 0,
      userWordId: json['userWordId'] ?? json['wordId'] ?? 0,
      questionText: json['questionText'] ?? '',
      questionType: json['questionType'] ?? 'meaning_to_word',
      options: List<String>.from(json['options'] ?? []),
    );
  }
}

class Sm2Quiz {
  final int quizId;
  final List<Sm2Question> questions;

  Sm2Quiz({required this.quizId, required this.questions});

  factory Sm2Quiz.fromJson(Map<String, dynamic> json) {
    return Sm2Quiz(
      quizId: json['quizId'] ?? 0,
      questions: (json['questions'] as List? ?? [])
          .map((q) => Sm2Question.fromJson(Map<String, dynamic>.from(q)))
          .toList(),
    );
  }
}
