import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai/core/models/word.dart';
import 'package:ai/core/services/api.dart';

enum WordSearchState { idle, loading, found, error }

class WordProvider extends ChangeNotifier {
  static const String _cacheKey = 'cached_words';
  static const String _cacheTimeKey = 'cached_words_time';
  static const Duration _cacheTtl = Duration(minutes: 5);

  WordSearchState _searchState = WordSearchState.idle;
  List<WordModel> _words = [];
  WordModel? _searchResult;
  String? _errorMessage;
  bool _isSaving = false;
  bool _isLoadingWords = false;
  bool _isLoadingMore = false;
  String? _lastSavedWordStatus;
  bool _offlineMode = false;
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  String? _searchFilter;
  String? _statusFilter;
  Timer? _searchDebounce;

  WordSearchState get searchState => _searchState;
  List<WordModel> get words => _words;

  List<WordModel> get sortedWords {
    final ordered = Map<String, int>.from({
      'hard': 0,
      'review': 1,
      'learning': 2,
      'new': 3,
      'mastered': 4,
    });
    final copy = [..._words];
    copy.sort((a, b) {
      final aIndex = ordered[a.status ?? 'new'] ?? 5;
      final bIndex = ordered[b.status ?? 'new'] ?? 5;
      if (aIndex != bIndex) return aIndex.compareTo(bIndex);
      return b.wordId.compareTo(a.wordId);
    });
    return copy;
  }

  WordModel? get searchResult => _searchResult;
  String? get errorMessage => _errorMessage;
  bool get isSaving => _isSaving;
  bool get isLoadingWords => _isLoadingWords;
  bool get isLoadingMore => _isLoadingMore;
  bool get offlineMode => _offlineMode;
  String? get lastSavedWordStatus => _lastSavedWordStatus;
  bool get hasMoreWords => _page < _pages;
  int get totalWords => _total > 0 ? _total : _words.length;
  String? get statusFilter => _statusFilter;

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

  void updateWordSearchFilter(String value) {
    _searchFilter = value.trim().isEmpty ? null : value.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      loadWords(forceRefresh: true);
    });
  }

  void updateStatusFilter(String? status) {
    _statusFilter = status == null || status.isEmpty ? null : status;
    loadWords(forceRefresh: true);
  }

  bool isDuplicateWord(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    return _words.any((word) {
      final candidate = word.text.trim().toLowerCase();
      return candidate == normalized;
    });
  }

  Future<String?> saveWord(String text, String arabicMeaning) async {
    _isSaving = true;
    notifyListeners();

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      _errorMessage = 'Please enter a word';
      _isSaving = false;
      notifyListeners();
      return null;
    }

    if (isDuplicateWord(trimmedText)) {
      _errorMessage = 'Word already exists in your words';
      _isSaving = false;
      notifyListeners();
      return null;
    }

    try {
      final created = await ApiService.createWord(
        text: trimmedText,
        arabicMeaning: arabicMeaning,
        audio: _searchResult?.audio,
        source: _searchResult?.source,
        examples: _searchResult?.examples ?? [],
      );
      _lastSavedWordStatus = created.status;
      await loadWords(forceRefresh: true);
      _searchResult = null;
      _searchState = WordSearchState.idle;
      notifyListeners();
      return created.status ?? 'new';
    } catch (e) {
      _lastSavedWordStatus = null;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> loadWords({bool forceRefresh = false}) async {
    if (_isLoadingWords) return;
    _isLoadingWords = true;
    _offlineMode = false;
    notifyListeners();

    try {
      if (!forceRefresh && _searchFilter == null && _statusFilter == null) {
        final cached = await _readFreshCache();
        if (cached.isNotEmpty) {
          _words = cached;
          _isLoadingWords = false;
          notifyListeners();
          return;
        }
      }

      _page = 1;
      final response = await ApiService.getWordsPage(
        page: _page,
        search: _searchFilter,
        status: _statusFilter,
      );
      _words = List<WordModel>.from(response['words'] as List);
      _total = response['total'] ?? _words.length;
      _pages = response['pages'] ?? 1;
      if (_searchFilter == null && _statusFilter == null) {
        await _writeCache(_words);
      }
    } catch (e) {
      final cached = await _readAnyCache();
      if (cached.isNotEmpty) {
        _words = cached;
        _offlineMode = true;
      } else {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
    }
    _isLoadingWords = false;
    notifyListeners();
  }

  Future<void> loadMoreWords() async {
    if (_isLoadingMore || !hasMoreWords || _offlineMode || _isLoadingWords) {
      return;
    }
    _isLoadingMore = true;
    notifyListeners();
    try {
      final nextPage = _page + 1;
      final response = await ApiService.getWordsPage(
        page: nextPage,
        search: _searchFilter,
        status: _statusFilter,
      );
      _words.addAll(List<WordModel>.from(response['words'] as List));
      _page = response['page'] ?? nextPage;
      _pages = response['pages'] ?? _pages;
      _total = response['total'] ?? _total;
      if (_searchFilter == null && _statusFilter == null) {
        await _writeCache(_words);
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }
    _isLoadingMore = false;
    notifyListeners();
  }

  Future<bool> deleteWord(int wordId) async {
    try {
      await ApiService.deleteWord(wordId);
      _words.removeWhere((word) => word.wordId == wordId);
      await _writeCache(_words);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteWordFromCache(int wordId) async {
    final originalCount = _words.length;
    _words.removeWhere((word) => word.wordId == wordId);
    if (_words.length != originalCount) {
      await _writeCache(_words);
      notifyListeners();
      return;
    }

    final cached = await _readAnyCache();
    if (cached.isNotEmpty) {
      final updated = cached.where((word) => word.wordId != wordId).toList();
      if (updated.length != cached.length) {
        await _writeCache(updated);
      }
    }
  }

  Future<bool> restoreWord(int wordId) async {
    try {
      final restored = await ApiService.restoreWord(wordId);
      _words.removeWhere((word) => word.wordId == wordId);
      _words.insert(0, restored);
      await _writeCache(_words);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clearSearch() {
    _searchState = WordSearchState.idle;
    _searchResult = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<List<WordModel>> _readFreshCache() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_cacheTimeKey);
    if (timestamp == null) return [];
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
    if (age > _cacheTtl) return [];
    return _readCachedWords(prefs);
  }

  Future<List<WordModel>> _readAnyCache() async {
    final prefs = await SharedPreferences.getInstance();
    return _readCachedWords(prefs);
  }

  List<WordModel> _readCachedWords(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List)
          .map((item) => WordModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeCache(List<WordModel> words) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _cacheKey, jsonEncode(words.map((w) => w.toJson()).toList()));
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
