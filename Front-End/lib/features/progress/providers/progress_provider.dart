import 'package:flutter/material.dart';
import 'package:ai/core/services/api.dart';

class ProgressProvider extends ChangeNotifier {
  Map<String, dynamic> _progress = {};
  Map<String, dynamic> _due = {};
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  Map<String, dynamic> get progress => _progress;
  Map<String, dynamic> get due => _due;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  int get activeWordsCount =>
      _intValue(_progress['activeWordsCount'] ?? _progress['newWords']);
  int get masteredWords => _intValue(_progress['masteredWords']);
  int get dailyStreak {
    final value = _intValue(_progress['dailyStreak']);
    return value <= 0 ? 1 : value;
  }

  int get completedSm2Quizzes => _intValue(_progress['completedSm2Quizzes']);
  int get dueReviewCount =>
      _intValue(_due['dueCount'] ?? _progress['dueReviewCount']);
  int get overdueCount => _intValue(_due['overdueCount']);
  int get hardCount => _intValue(_due['hardCount']);
  int get pendingCount => _intValue(_due['pendingCount']);

  Future<void> load({bool force = false}) async {
    if (_isLoading || (_hasLoaded && !force)) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        ApiService.getProgress(),
        ApiService.getSm2DueSummary(),
      ]);
      _progress = results[0];
      _due = results[1];
      _hasLoaded = true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(force: true);

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
