import 'package:flutter/material.dart';
import 'package:ai/core/models/sm2_quiz.dart';
import 'package:ai/core/services/api.dart';

enum Sm2QuizState { idle, loading, active, submitting, finished, error }

class Sm2AnswerDraft {
  String? answer;
  int durationSeconds = 0;
  bool skipped = false;
}

class Sm2QuizProvider extends ChangeNotifier {
  Sm2QuizState _state = Sm2QuizState.idle;
  Sm2Quiz? _quiz;
  int _currentIndex = 0;
  String? _errorMessage;
  Map<String, dynamic>? _result;
  final Map<int, Sm2AnswerDraft> _answers = {};
  DateTime? _questionStartedAt;

  Sm2QuizState get state => _state;
  Sm2Quiz? get quiz => _quiz;
  int get currentIndex => _currentIndex;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get result => _result;

  Sm2Question? get currentQuestion {
    if (_quiz == null || _quiz!.questions.isEmpty) return null;
    return _quiz!.questions[_currentIndex];
  }

  bool get isLastQuestion =>
      _quiz != null && _currentIndex == _quiz!.questions.length - 1;

  double get progress {
    final total = _quiz?.questions.length ?? 0;
    if (total == 0) return 0;
    return ((_currentIndex + 1) / total).clamp(0.0, 1.0).toDouble();
  }

  String? selectedAnswerForCurrent() {
    final question = currentQuestion;
    if (question == null) return null;
    return _answers[question.itemId]?.answer;
  }

  Future<void> start() async {
    _state = Sm2QuizState.loading;
    _errorMessage = null;
    _result = null;
    _answers.clear();
    notifyListeners();

    try {
      _quiz = Sm2Quiz.fromJson(await ApiService.startSm2Quiz());
      _currentIndex = 0;
      _questionStartedAt = DateTime.now();
      _state = Sm2QuizState.active;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = Sm2QuizState.error;
    }
    notifyListeners();
  }

  void selectAnswer(String answer) {
    final question = currentQuestion;
    if (question == null) return;
    final draft = _answers.putIfAbsent(question.itemId, () => Sm2AnswerDraft());
    draft.answer = answer;
    draft.skipped = false;
    draft.durationSeconds = _elapsedSeconds();
    notifyListeners();
  }

  bool get currentIsAnswered {
    final answer = selectedAnswerForCurrent();
    return answer != null && answer.trim().isNotEmpty;
  }

  bool get currentIsSkipped {
    final question = currentQuestion;
    if (question == null) return false;
    return _answers[question.itemId]?.skipped ?? false;
  }

  void markCurrentSkipped() {
    final question = currentQuestion;
    if (question == null) return;
    final draft = _answers.putIfAbsent(question.itemId, () => Sm2AnswerDraft());
    draft.answer = '';
    draft.skipped = true;
    draft.durationSeconds = _elapsedSeconds();
    notifyListeners();
  }

  void next() {
    if (_quiz == null) return;
    if (!isLastQuestion) {
      _currentIndex++;
      _questionStartedAt = DateTime.now();
      notifyListeners();
    }
  }

  Future<void> submit({bool confirmEmptyAsWrong = false}) async {
    if (_quiz == null) return;
    _captureCurrentDuration();
    _state = Sm2QuizState.submitting;
    notifyListeners();

    try {
      final payload = _quiz!.questions.map((question) {
        final draft = _answers[question.itemId] ?? Sm2AnswerDraft();
        return {
          'itemId': question.itemId,
          'answer': draft.answer ?? '',
          'durationSeconds': draft.durationSeconds,
          'skipped': draft.skipped || (draft.answer ?? '').trim().isEmpty,
        };
      }).toList();
      _result = await ApiService.submitSm2Quiz(
        quizId: _quiz!.quizId,
        answers: payload,
        confirmEmptyAsWrong: confirmEmptyAsWrong,
      );
      _state = Sm2QuizState.finished;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = Sm2QuizState.error;
    }
    notifyListeners();
  }

  Future<void> abandon() async {
    if (_quiz != null) {
      try {
        await ApiService.abandonSm2Quiz(_quiz!.quizId);
      } catch (_) {}
    }
    reset();
  }

  bool hasUnansweredQuestions() {
    if (_quiz == null) return false;
    return _quiz!.questions.any((question) {
      final answer = _answers[question.itemId]?.answer;
      return answer == null || answer.trim().isEmpty;
    });
  }

  void reset() {
    _state = Sm2QuizState.idle;
    _quiz = null;
    _currentIndex = 0;
    _errorMessage = null;
    _result = null;
    _answers.clear();
    _questionStartedAt = null;
    notifyListeners();
  }

  int _elapsedSeconds() {
    final started = _questionStartedAt;
    if (started == null) return 0;
    return DateTime.now().difference(started).inSeconds;
  }

  void _captureCurrentDuration() {
    final question = currentQuestion;
    if (question == null) return;
    final draft = _answers.putIfAbsent(question.itemId, () => Sm2AnswerDraft());
    draft.durationSeconds = _elapsedSeconds();
  }
}
