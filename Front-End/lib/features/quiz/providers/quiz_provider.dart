import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai/core/models/quiz.dart';
import 'package:ai/core/services/api.dart';

enum QuizState { idle, loading, active, finished, error }

class QuizProvider extends ChangeNotifier {
  static const int questionSeconds = 30;
  static const String _storageKey = 'active_quiz_session';

  QuizState _state = QuizState.idle;
  QuizModel? _currentQuiz;
  List<QuizHistory> _history = [];
  int _currentIndex = 0;
  int _score = 0;
  String? _selectedAnswer;
  bool _isAnswered = false;
  String? _errorMessage;
  QuizResultDetails? _resultDetails;
  final List<String> _userAnswers = [];
  Timer? _questionTimer;
  Timer? _advanceTimer;
  int _remainingSeconds = questionSeconds;

  QuizState get state => _state;
  QuizModel? get currentQuiz => _currentQuiz;
  List<QuizHistory> get history => _history;
  int get currentIndex => _currentIndex;
  int get score => _score;
  String? get selectedAnswer => _selectedAnswer;
  bool get isAnswered => _isAnswered;
  String? get errorMessage => _errorMessage;
  QuizResultDetails? get resultDetails => _resultDetails;
  int get remainingSeconds => _remainingSeconds;
  double get timerProgress =>
      (_remainingSeconds / questionSeconds).clamp(0.0, 1.0).toDouble();

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

  bool isCorrectAnswer(String? answer) {
    final q = currentQuestion;
    if (q == null || answer == null) return false;
    if (q.questionType == 'fill') {
      return _normalize(answer) == _normalize(q.correctAnswer);
    }
    return answer == q.correctAnswer;
  }

  Future<void> restoreSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;

      final json = Map<String, dynamic>.from(jsonDecode(raw));
      final quiz = QuizModel.fromJson(Map<String, dynamic>.from(json['quiz']));
      if (quiz.questions.isEmpty) {
        await prefs.remove(_storageKey);
        return;
      }

      _currentQuiz = quiz;
      _currentIndex = (json['current_index'] ?? 0)
          .clamp(0, quiz.questions.length - 1)
          .toInt();
      _score = json['score'] ?? 0;
      _userAnswers
        ..clear()
        ..addAll(List<String>.from(json['answers'] ?? []));
      _selectedAnswer =
          _currentIndex < _userAnswers.length ? _userAnswers[_currentIndex] : null;
      _isAnswered = _currentIndex < _userAnswers.length;
      _resultDetails = null;
      _state = QuizState.active;
      if (_isAnswered) {
        _advanceTimer = Timer(const Duration(milliseconds: 1200), () {
          _advanceAfterFeedback();
        });
      } else {
        _startTimer();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> startQuiz() async {
    await _start(() => ApiService.createQuiz());
  }

  Future<void> startAiReviewQuiz() async {
    await _start(() => ApiService.createAiReviewQuiz());
  }

  void selectAnswer(String answer) {
    if (_isAnswered) return;
    _lockAnswer(answer);
  }

  Future<void> nextQuestion() async {
    _advanceTimer?.cancel();
    await _advanceAfterFeedback();
  }

  Future<void> loadHistory() async {
    try {
      _history = await ApiService.getQuizHistory();
      notifyListeners();
    } catch (_) {}
  }

  void reset() {
    _cancelTimers();
    _state = QuizState.idle;
    _currentQuiz = null;
    _currentIndex = 0;
    _score = 0;
    _selectedAnswer = null;
    _isAnswered = false;
    _errorMessage = null;
    _resultDetails = null;
    _remainingSeconds = questionSeconds;
    _userAnswers.clear();
    _clearSavedSession();
    notifyListeners();
    loadHistory();
  }

  Future<void> _start(Future<QuizModel> Function() create) async {
    _cancelTimers();
    _state = QuizState.loading;
    _errorMessage = null;
    _resultDetails = null;
    notifyListeners();
    try {
      _currentQuiz = await create();
      _currentIndex = 0;
      _score = 0;
      _selectedAnswer = null;
      _isAnswered = false;
      _userAnswers.clear();
      _state = QuizState.active;
      _remainingSeconds = questionSeconds;
      _startTimer();
      await _saveSession();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = QuizState.error;
    }
    notifyListeners();
  }

  void _lockAnswer(String answer) {
    _questionTimer?.cancel();
    _selectedAnswer = answer;
    _isAnswered = true;

    while (_userAnswers.length <= _currentIndex) {
      _userAnswers.add('');
    }
    _userAnswers[_currentIndex] = answer;

    if (isCorrectAnswer(answer)) {
      _score++;
    }
    _saveSession();
    notifyListeners();

    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 1200), () {
      _advanceAfterFeedback();
    });
  }

  Future<void> _advanceAfterFeedback() async {
    if (!_isAnswered) return;
    if (isLastQuestion) {
      await _submitQuiz();
    } else {
      _currentIndex++;
      _selectedAnswer = null;
      _isAnswered = false;
      _remainingSeconds = questionSeconds;
      _startTimer();
      await _saveSession();
      notifyListeners();
    }
  }

  Future<void> _submitQuiz() async {
    if (_currentQuiz == null) return;
    _cancelTimers();
    _state = QuizState.loading;
    notifyListeners();
    try {
      final response = await ApiService.submitQuiz(
        quizId: _currentQuiz!.quizId,
        answers: _normalizedAnswersForSubmit(),
      );
      _resultDetails = QuizResultDetails.fromJson(response);
      await _clearSavedSession();
      await loadHistory();
    } catch (_) {
      _resultDetails = _localResultDetails();
      await _clearSavedSession();
    }
    _state = QuizState.finished;
    notifyListeners();
  }

  void _startTimer() {
    _questionTimer?.cancel();
    _remainingSeconds = questionSeconds;
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state != QuizState.active || _isAnswered) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _remainingSeconds = 0;
        _lockAnswer('');
      } else {
        _remainingSeconds--;
        notifyListeners();
      }
    });
  }

  List<String> _normalizedAnswersForSubmit() {
    final total = _currentQuiz?.questions.length ?? 0;
    return List<String>.generate(
      total,
      (index) => index < _userAnswers.length ? _userAnswers[index] : '',
    );
  }

  QuizResultDetails _localResultDetails() {
    final quiz = _currentQuiz;
    final questions = quiz?.questions ?? [];
    final breakdown = <QuizQuestionBreakdown>[];
    for (var i = 0; i < questions.length; i++) {
      final answer = i < _userAnswers.length ? _userAnswers[i] : '';
      final q = questions[i];
      final isCorrect = q.questionType == 'fill'
          ? _normalize(answer) == _normalize(q.correctAnswer)
          : answer == q.correctAnswer;
      breakdown.add(QuizQuestionBreakdown(
        question: q.question,
        userAnswer: answer,
        correctAnswer: q.correctAnswer,
        isCorrect: isCorrect,
      ));
    }
    final total = questions.length;
    final percentage = total == 0 ? 0.0 : (_score / total) * 100;
    return QuizResultDetails(
      score: _score,
      total: total,
      percentage: percentage,
      grade: _gradeFor(percentage),
      breakdown: breakdown,
    );
  }

  Future<void> _saveSession() async {
    final quiz = _currentQuiz;
    if (quiz == null || _state != QuizState.active) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode({
          'quiz': quiz.toJson(),
          'current_index': _currentIndex,
          'score': _score,
          'answers': _userAnswers,
        }),
      );
    } catch (_) {}
  }

  Future<void> _clearSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }

  void _cancelTimers() {
    _questionTimer?.cancel();
    _advanceTimer?.cancel();
    _questionTimer = null;
    _advanceTimer = null;
  }

  String _normalize(String value) => value.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');

  String _gradeFor(double percentage) {
    if (percentage >= 90) return 'Excellent';
    if (percentage >= 70) return 'Good';
    if (percentage >= 50) return 'Average';
    return 'Needs Work';
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
