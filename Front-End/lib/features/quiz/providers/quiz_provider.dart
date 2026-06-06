import 'package:flutter/material.dart';
import 'package:ai/core/models/quiz.dart';
import 'package:ai/core/services/api.dart';

enum QuizState { idle, loading, active, finished, error }

class QuizProvider extends ChangeNotifier {
  QuizState _state = QuizState.idle;
  QuizModel? _currentQuiz;
  List<QuizHistory> _history = [];
  int _currentIndex = 0;
  int _score = 0;
  String? _selectedAnswer;
  bool _isAnswered = false;
  String? _errorMessage;
  final List<String> _userAnswers = [];

  QuizState get state => _state;
  QuizModel? get currentQuiz => _currentQuiz;
  List<QuizHistory> get history => _history;
  int get currentIndex => _currentIndex;
  int get score => _score;
  String? get selectedAnswer => _selectedAnswer;
  bool get isAnswered => _isAnswered;
  String? get errorMessage => _errorMessage;

  QuizQuestion? get currentQuestion =>
      _currentQuiz == null || _currentQuiz!.questions.isEmpty
      ? null
      : _currentQuiz!.questions[_currentIndex];

  bool get isLastQuestion => _currentQuiz == null
      ? false
      : _currentIndex == _currentQuiz!.questions.length - 1;

  double get progress {
    final total = _currentQuiz?.questions.length ?? 0;
    if (total <= 0) return 0.0;
    return ((_currentIndex + 1) / total).clamp(0.0, 1.0).toDouble();
  }

  // ─── بدء كويز جديد ───────────────────────────────────────
  Future<void> startQuiz() async {
    _state = QuizState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentQuiz = await ApiService.createQuiz();
      _currentIndex = 0;
      _score = 0;
      _selectedAnswer = null;
      _isAnswered = false;
      _userAnswers.clear();
      _state = QuizState.active;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = QuizState.error;
    }
    notifyListeners();
  }

  // ─── بدء كويز ذكي من AI ───────────────────────────────────────
  Future<void> startAiReviewQuiz() async {
    _state = QuizState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentQuiz = await ApiService.createAiReviewQuiz();
      _currentIndex = 0;
      _score = 0;
      _selectedAnswer = null;
      _isAnswered = false;
      _userAnswers.clear();
      _state = QuizState.active;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = QuizState.error;
    }
    notifyListeners();
  }

  // ─── اختيار إجابة ────────────────────────────────────────
  void selectAnswer(String answer) {
    if (_isAnswered) return;
    _selectedAnswer = answer;
    _isAnswered = true;
    _userAnswers.add(answer);

    final q = currentQuestion;
    if (q == null) return;
    if (q.questionType == 'fill') {
      if (answer.trim().toLowerCase() == q.correctAnswer.trim().toLowerCase()) {
        _score++;
      }
    } else {
      if (answer == q.correctAnswer) {
        _score++;
      }
    }
    notifyListeners();
  }

  // ─── السؤال التالي ───────────────────────────────────────
  Future<void> nextQuestion() async {
    if (isLastQuestion) {
      await _submitQuiz();
    } else {
      _currentIndex++;
      _selectedAnswer = null;
      _isAnswered = false;
      notifyListeners();
    }
  }

  // ─── إرسال النتيجة ───────────────────────────────────────
  Future<void> _submitQuiz() async {
    if (_currentQuiz == null) return;
    _state = QuizState.loading;
    notifyListeners();
    try {
      await ApiService.submitQuiz(
        quizId: _currentQuiz!.quizId,
        answers: _userAnswers,
      );
      await loadHistory();
    } catch (_) {}
    _state = QuizState.finished;
    notifyListeners();
  }

  // ─── تحميل السجل ─────────────────────────────────────────
  Future<void> loadHistory() async {
    try {
      _history = await ApiService.getQuizHistory();
      notifyListeners();
    } catch (_) {}
  }

  // ─── إعادة التعيين ───────────────────────────────────────
  void reset() {
    _state = QuizState.idle;
    _currentQuiz = null;
    _currentIndex = 0;
    _score = 0;
    _selectedAnswer = null;
    _isAnswered = false;
    _errorMessage = null;
    _userAnswers.clear();
    notifyListeners();
    loadHistory();
  }
}
