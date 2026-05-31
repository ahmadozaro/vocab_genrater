import 'package:ai/core/models/testslevel_m.dart';

class QuizLogic {
  int currentIndex = 0;
  int? selectedIndex;
  bool isAnswered = false;
  int correctCount = 0;
  final List<int> answers = [];

  bool get isLastQuestion => currentIndex == testsQuestions.length - 1;
  double get progress => (currentIndex + 1) / testsQuestions.length;
  Testslevel get currentQuestion => testsQuestions[currentIndex];

  void answerQuestion(int index) {
    if (isAnswered) return;
    selectedIndex = index;
    isAnswered = true;
    if (index == currentQuestion.correctIndex) correctCount++;
  }

  bool nextQuestion() {
    answers.add(selectedIndex ?? -1);
    if (!isLastQuestion) {
      currentIndex++;
      selectedIndex = null;
      isAnswered = false;
      return false;
    }
    return true;
  }

  /// حساب المستوى المنطقي
  /// عندك 10 أسئلة: 3 easy + 4 medium + 3 hard
  String calculateLevel() {
    int easyCorrect = 0, mediumCorrect = 0, hardCorrect = 0;

    for (int i = 0; i < answers.length; i++) {
      final q = testsQuestions[i];
      if (answers[i] != q.correctIndex) continue;
      if (q.difficulty == 'easy') {
        easyCorrect++;
      } else if (q.difficulty == 'medium') {
        mediumCorrect++;
      } else {
        hardCorrect++;
      }
    }

    // كل غلط → A1
    if (correctCount == 0) return 'A1';

    // صح صعب 3/3 → C1
    if (hardCorrect >= 3) return 'C1';

    // صح صعب 1-2 + medium جيد → B2
    if (hardCorrect >= 1 && mediumCorrect >= 2) return 'B2';

    // medium 3-4 → B2
    if (mediumCorrect >= 3) return 'B2';

    // medium 1-2 → B1
    if (mediumCorrect >= 1) return 'B1';

    // easy 3/3 → A2
    if (easyCorrect >= 3) return 'A2';

    // easy 1-2 → A1
    return 'A1';
  }
}
