import 'package:flutter/material.dart';
import 'package:ai/core/models/word.dart';
import 'package:ai/core/services/api.dart';

enum WordSearchState { idle, loading, found, error }

class WordProvider extends ChangeNotifier {
  WordSearchState _searchState = WordSearchState.idle;
  List<WordModel> _words = [];
  WordModel? _searchResult;
  String? _errorMessage;
  bool _isSaving = false;
  bool _isLoadingWords = false;

  WordSearchState get searchState => _searchState;
  List<WordModel> get words => _words;
  WordModel? get searchResult => _searchResult;
  String? get errorMessage => _errorMessage;
  bool get isSaving => _isSaving;
  bool get isLoadingWords => _isLoadingWords;

  Future<void> searchWord(String text) async {
    if (text.trim().isEmpty) return;
    _searchState = WordSearchState.loading;
    _searchResult = null;
    _errorMessage = null;
    notifyListeners();

    try {
      _searchResult = await ApiService.lookupWord(text.trim());
      _searchState = WordSearchState.found;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _searchState = WordSearchState.error;
    }
    notifyListeners();
  }

  Future<bool> saveWord(String text, String arabicMeaning) async {
    _isSaving = true;
    notifyListeners();
    try {
      final saved = await ApiService.createWord(
        text: text,
        arabicMeaning: arabicMeaning,
        audio: _searchResult?.audio,
        source: _searchResult?.source,
        examples: _searchResult?.examples ?? [],
      );
      _words.insert(0, saved);
      _searchResult = null;
      _searchState = WordSearchState.idle;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> loadWords() async {
    _isLoadingWords = true;
    notifyListeners();
    try {
      _words = await ApiService.getWords();
    } catch (_) {}
    _isLoadingWords = false;
    notifyListeners();
  }

  void clearSearch() {
    _searchState = WordSearchState.idle;
    _searchResult = null;
    _errorMessage = null;
    notifyListeners();
  }
}
