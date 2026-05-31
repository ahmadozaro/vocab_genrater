import 'package:flutter/material.dart';
import 'package:ai/core/services/api.dart';

class SuggestedWord {
  final String text;
  final String definition;
  final String arabicMeaning;
  final String difficulty;
  final String example;
  SuggestedWordState state;

  SuggestedWord({
    required this.text,
    required this.definition,
    required this.arabicMeaning,
    required this.difficulty,
    required this.example,
    this.state = SuggestedWordState.idle,
  });
}

enum SuggestedWordState { idle, saving, saved, rejected }

class SuggestedWordsProvider extends ChangeNotifier {
  List<SuggestedWord> _suggestions = [];
  bool _isLoading = false;
  String? _error;

  List<SuggestedWord> get suggestions => _suggestions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<SuggestedWord> get activeSuggestions => _suggestions
      .where((s) => s.state != SuggestedWordState.rejected)
      .toList();

  Future<void> fetchSuggestions({
    required String level,
    required List<String> interests,
    required List<String> existingWords,
  }) async {
    _isLoading = true;
    _error = null;
    _suggestions = [];
    notifyListeners();

    try {
      final list = await ApiService.suggestWords(
        level: level,
        interests: interests,
        existingWords: existingWords,
      );

      _suggestions = list
          .map(
            (item) => SuggestedWord(
              text: item['text'] ?? '',
              definition: item['definition'] ?? '',
              arabicMeaning: item['arabicMeaning'] ?? '',
              difficulty: item['difficulty'] ?? 'medium',
              example: item['example'] ?? '',
            ),
          )
          .toList();
    } catch (e) {
      _error = 'Failed to load suggestions. Try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveWord(SuggestedWord word) async {
    word.state = SuggestedWordState.saving;
    notifyListeners();

    try {
      await ApiService.createWord(
        text: word.text,
        arabicMeaning: word.arabicMeaning,
        source: 'ai_suggested',
        examples: [word.example],
      );
      word.state = SuggestedWordState.saved;
      notifyListeners();
      return true;
    } catch (_) {
      word.state = SuggestedWordState.idle;
      notifyListeners();
      return false;
    }
  }

  void rejectWord(SuggestedWord word) {
    word.state = SuggestedWordState.rejected;
    notifyListeners();
  }

  void reset() {
    _suggestions = [];
    _error = null;
    notifyListeners();
  }
}
