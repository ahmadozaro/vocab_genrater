import 'dart:math';
import 'package:ai/core/models/testslevel_m.dart';

class QuizLogic {
  int? selectedIndex;
  bool isAnswered = false;
  int correctCount = 0; 

  
  final int maxQuestions = 7; 
  int questionsAsked = 0;

  
  
  int currentLevelScore = 3;

  
  final List<int> askedQuestionIds = [];

  late Testslevel currentQuestion;

  QuizLogic() {
    _fetchNextQuestion();
  }

  bool get isLastQuestion => questionsAsked >= maxQuestions;
  double get progress => questionsAsked / maxQuestions;

  
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

  
  void _fetchNextQuestion() {
    String targetLevel = _getLevelString(currentLevelScore);

    
    List<Testslevel> availableQuestions = testsQuestions.where((q) {
      return q.level == targetLevel && !askedQuestionIds.contains(q.id);
    }).toList();

    
    if (availableQuestions.isEmpty) {
      availableQuestions = testsQuestions
          .where((q) => !askedQuestionIds.contains(q.id))
          .toList();
    }

    
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
    
    if (selectedIndex == currentQuestion.correctIndex) {
      currentLevelScore = min(5, currentLevelScore + 1); 
    } else {
      currentLevelScore = max(1, currentLevelScore - 1); 
    }

    if (isLastQuestion) {
      return true; 
    } else {
      
      selectedIndex = null;
      isAnswered = false;
      _fetchNextQuestion();
      return false;
    }
  }

  
  String calculateLevel() {
    return _getLevelString(currentLevelScore);
  }
}
