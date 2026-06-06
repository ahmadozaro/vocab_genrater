import 'dart:math';
import 'package:ai/core/models/testslevel_m.dart';

class QuizLogic {
  int? selectedIndex;
  bool isAnswered = false;
  int correctCount = 0; // لحفظ عدد الإجابات الصحيحة الكلية

  // إعدادات الامتحان التكيفي
  final int maxQuestions = 7; // عدد الأسئلة التي سيتم طرحها على المستخدم
  int questionsAsked = 0;

  // نبدأ التقييم من المستوى المتوسط B1 (يعادل رقم 3)
  // 1: A1, 2: A2, 3: B1, 4: B2, 5: C1
  int currentLevelScore = 3;

  // قائمة لتتبع الأسئلة التي تم طرحها لمنع تكرارها
  final List<int> askedQuestionIds = [];

  late Testslevel currentQuestion;

  QuizLogic() {
    _fetchNextQuestion();
  }

  bool get isLastQuestion => questionsAsked >= maxQuestions;
  double get progress => questionsAsked / maxQuestions;

  // تحويل الرقم إلى حرف المستوى
  String _getLevelString(int score) {
    switch (score) {
      case 1:
        return 'A1';
      case 2:
        return 'A2';
      case 3:
        return 'B1';
      case 4:
        return 'B2';
      case 5:
        return 'C1';
      default:
        return 'A1';
    }
  }

  // سحب سؤال من البنك يناسب المستوى الحالي للمستخدم
  void _fetchNextQuestion() {
    String targetLevel = _getLevelString(currentLevelScore);

    // فلترة الأسئلة التي تطابق المستوى المستهدف ولم يتم طرحها بعد
    List<Testslevel> availableQuestions = testsQuestions.where((q) {
      return q.level == targetLevel && !askedQuestionIds.contains(q.id);
    }).toList();

    // في حال نفاد أسئلة هذا المستوى، نسحب أي سؤال غير مجاب لمستوى قريب
    if (availableQuestions.isEmpty) {
      availableQuestions = testsQuestions
          .where((q) => !askedQuestionIds.contains(q.id))
          .toList();
    }

    // اختيار سؤال عشوائي من المتاح
    availableQuestions.shuffle();
    currentQuestion = availableQuestions.first;
    askedQuestionIds.add(currentQuestion.id);
    questionsAsked++;
  }

  void answerQuestion(int index) {
    if (isAnswered) return;
    selectedIndex = index;
    isAnswered = true;
    if (index == currentQuestion.correctIndex) {
      correctCount++;
    }
  }

  bool nextQuestion() {
    // تعديل مستوى المستخدم التكيفي بناءً على إجابته
    if (selectedIndex == currentQuestion.correctIndex) {
      currentLevelScore = min(5, currentLevelScore + 1); // نرفع الصعوبة
    } else {
      currentLevelScore = max(1, currentLevelScore - 1); // ننزل الصعوبة
    }

    if (isLastQuestion) {
      return true; // انتهى الامتحان
    } else {
      // تجهيز السؤال التالي
      selectedIndex = null;
      isAnswered = false;
      _fetchNextQuestion();
      return false;
    }
  }

  // المستوى النهائي
  String calculateLevel() {
    return _getLevelString(currentLevelScore);
  }
}
