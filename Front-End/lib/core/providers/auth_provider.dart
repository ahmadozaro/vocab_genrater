import 'dart:async';

import 'package:ai/core/models/interest.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _hasTakenTest = false;
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _isEmailVerified = false;
  bool _isOffline = false;
  bool _isRateLimited = false;
  DateTime? _rateLimitUntil;
  Timer? _rateLimitTimer;

  bool _needsInterests = false;

  String? _errorMessage;
  String? _userName;
  String? _userEmail;
  String? _userLevel;
  String? _lastVerificationDebugCode;
  String? _lastResetDebugCode;
  List<InterestModel> _userInterestModels = [];

  bool get isLoggedIn => _isLoggedIn;
  bool get hasTakenTest => _hasTakenTest;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  bool get isEmailVerified => _isEmailVerified;
  bool get needsInterests => _needsInterests;
  bool get isOffline => _isOffline;
  bool get isRateLimited => _isRateLimited;
  DateTime? get rateLimitUntil => _rateLimitUntil;
  int get rateLimitSecondsRemaining {
    if (_rateLimitUntil == null) return 0;
    final seconds = _rateLimitUntil!.difference(DateTime.now()).inSeconds;
    return seconds > 0 ? seconds : 0;
  }

  String? get errorMessage => _errorMessage;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userLevel => _userLevel;
  String? get lastVerificationDebugCode => _lastVerificationDebugCode;
  String? get lastResetDebugCode => _lastResetDebugCode;
  List<InterestModel> get userInterestModels => _userInterestModels;
  List<String> get userInterests =>
      _userInterestModels.map((m) => m.label).toList();

  Future<void> loadUser() async {
    _setInitializing(true);
    try {
      final token = await ApiService.getToken();
      final prefs = await SharedPreferences.getInstance();

      _isLoggedIn = token != null;
      _hasTakenTest = false;
      _isEmailVerified = false;
      _needsInterests = false;

      if (_isLoggedIn) {
        _userName = prefs.getString('userName');
        _userEmail = prefs.getString('userEmail');
        _userLevel = prefs.getString('userLevel') ?? 'A1';

        final saved = prefs.getString('userInterests') ?? '';
        final labels = saved.isEmpty ? <String>[] : saved.split(',');
        _userInterestModels =
            labels.map((l) => labelToModel(l.trim())).toList();

        await _refreshProfile();
      }
    } finally {
      _setInitializing(false);
    }
  }

  Future<void> _refreshProfile() async {
    _isOffline = false;
    try {
      final data = await ApiService.getProfile();
      final prefs = await SharedPreferences.getInstance();
      final skippedInterests = prefs.getBool('skippedInterests') ?? false;
      final serverInterests = data['interests'] ?? '';
      if ((serverInterests as String).isEmpty &&
          _userInterestModels.isNotEmpty) {
        _userName = data['name'];
        _userEmail = data['email'];
        _userLevel = data['level'] ?? 'A1';
        await prefs.setString('userName', _userName ?? '');
        await prefs.setString('userEmail', _userEmail ?? '');
        await prefs.setString('userLevel', _userLevel!);
        
        
        
        final skippedInterests = prefs.getBool('skippedInterests') ?? false;
        _needsInterests = _userInterestModels.isEmpty && !skippedInterests;
        notifyListeners();
        return;
      }
      await _applyProfile(data);
      _needsInterests = _userInterestModels.isEmpty && !skippedInterests;
    } catch (e) {
      if (e is UnauthorizedException) {
        await ApiService.clearToken();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        await prefs.remove('userName');
        await prefs.remove('userEmail');
        await prefs.remove('userLevel');
        await prefs.remove('userInterests');
        _isLoggedIn = false;
        _hasTakenTest = false;
        _isEmailVerified = false;
        _needsInterests = false;
        _userName = null;
        _userEmail = null;
        _userLevel = null;
        _userInterestModels = [];
      } else {
        _isOffline = true;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoggedIn = true;
      }
      notifyListeners();
    }
  }

  Future<void> _applyProfile(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final skippedLevelTest = prefs.getBool('skippedLevelTest') ?? false;
    _userName = data['name'];
    _userEmail = data['email'];
    _userLevel = data['level'] ?? 'A1';
    _isEmailVerified = data['is_email_verified'] == true;
    _hasTakenTest = data['level_test_completed'] == true || skippedLevelTest;
    final raw = data['interests'] ?? '';
    if ((raw as String).isNotEmpty) {
      final labels = raw.split(',');
      _userInterestModels = labels.map((l) => labelToModel(l.trim())).toList();
      await prefs.setString('userInterests', raw);
    } else {
      _userInterestModels = [];
      await prefs.remove('userInterests');
    }
    await prefs.setString('userName', _userName ?? '');
    await prefs.setString('userEmail', _userEmail ?? '');
    await prefs.setString('userLevel', _userLevel!);
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    if (_isRateLimited &&
        _rateLimitUntil != null &&
        _rateLimitUntil!.isAfter(DateTime.now())) {
      _errorMessage =
          'Too many requests. Please wait $rateLimitSecondsRemaining seconds.';
      notifyListeners();
      return false;
    }
    if (email.trim().isEmpty || password.isEmpty) {
      _errorMessage = 'Please fill in all fields';
      notifyListeners();
      return false;
    }
    _setLoading(true);
    _errorMessage = null;
    try {
      await ApiService.clearToken();
      final data = await ApiService.login(
        email: email.trim(),
        password: password,
      );

      final user = data['user'] as Map<String, dynamic>?;
      if (user != null) {
        await _applyProfile(user);
      }

      _clearRateLimit();
      _isLoggedIn = true;
      _needsInterests = _userInterestModels.isEmpty;
      return true;
    } catch (e) {
      final message = e.toString().replaceAll('Exception: ', '');
      _errorMessage = message;
      if (message.contains('Too many requests')) {
        _startRateLimit(const Duration(seconds: 30));
      }
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password,
    String confirm, {
    List<InterestModel>? initialInterests,
  }) async {
    if (_isRateLimited &&
        _rateLimitUntil != null &&
        _rateLimitUntil!.isAfter(DateTime.now())) {
      _errorMessage =
          'Too many requests. Please wait $rateLimitSecondsRemaining seconds.';
      notifyListeners();
      return false;
    }
    if (name.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      _errorMessage = 'Please fill in all fields';
      notifyListeners();
      return false;
    }
    if (password != confirm) {
      _errorMessage = 'Passwords do not match';
      notifyListeners();
      return false;
    }
    if (password.length < 6) {
      _errorMessage = 'Password must be at least 6 characters';
      notifyListeners();
      return false;
    }
    _setLoading(true);
    _errorMessage = null;
    try {
      final data = await ApiService.register(
        name: name.trim(),
        email: email.trim(),
        password: password,
      );
      _lastVerificationDebugCode = data['verification_debug_code']?.toString();
      _userEmail = email.trim();
      _userName = name.trim();
      _isEmailVerified = false;
      _isLoggedIn = false;
      _needsInterests = false;
      _clearRateLimit();
      notifyListeners();
      return true;
    } catch (e) {
      final message = e.toString().replaceAll('Exception: ', '');
      _errorMessage = message;
      if (message.contains('Too many requests')) {
        _startRateLimit(const Duration(seconds: 30));
      }
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyEmail(String email, String code) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await ApiService.verifyEmail(email: email.trim(), code: code);
      final data = await ApiService.getProfile();
      await _applyProfile(data);
      _isLoggedIn = true;
      _isEmailVerified = true;
      _needsInterests = _userInterestModels.isEmpty;
      _lastVerificationDebugCode = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> skipVerification() async {
    _lastVerificationDebugCode = null;
    _isLoggedIn = true;
    try {
      await _refreshProfile();
    } catch (_) {
      _userLevel ??= 'A1';
      final prefs = await SharedPreferences.getInstance();
      final skippedInterests = prefs.getBool('skippedInterests') ?? false;
      _needsInterests = _userInterestModels.isEmpty && !skippedInterests;
    }
    notifyListeners();
  }

  Future<bool> resendVerificationCode(String email) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final data = await ApiService.resendVerificationCode(email: email);
      _lastVerificationDebugCode = data['debug_code']?.toString();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> requestResetCode(String email) async {
    if (email.trim().isEmpty) {
      _errorMessage = 'Please enter your email address';
      notifyListeners();
      return false;
    }
    if (_isRateLimited &&
        _rateLimitUntil != null &&
        _rateLimitUntil!.isAfter(DateTime.now())) {
      _errorMessage =
          'Too many requests. Please wait $rateLimitSecondsRemaining seconds.';
      notifyListeners();
      return false;
    }
    _setLoading(true);
    _errorMessage = null;
    _lastResetDebugCode = null;
    try {
      final data = await ApiService.requestResetCode(email.trim());
      _lastResetDebugCode = data['debug_code']?.toString();
      _clearRateLimit();
      notifyListeners();
      return true;
    } catch (e) {
      final message = e.toString().replaceAll('Exception: ', '');
      _errorMessage = message;
      if (message.contains('Too many requests')) {
        _startRateLimit(const Duration(seconds: 30));
      }
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> confirmResetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    if (code.isEmpty || newPassword.isEmpty) {
      _errorMessage = 'Please fill in all fields';
      notifyListeners();
      return false;
    }
    if (newPassword.length < 6) {
      _errorMessage = 'Password must be at least 6 characters';
      notifyListeners();
      return false;
    }
    if (_isRateLimited &&
        _rateLimitUntil != null &&
        _rateLimitUntil!.isAfter(DateTime.now())) {
      _errorMessage =
          'Too many requests. Please wait $rateLimitSecondsRemaining seconds.';
      notifyListeners();
      return false;
    }
    _setLoading(true);
    _errorMessage = null;
    try {
      await ApiService.confirmResetPassword(
        email: email.trim(),
        code: code.trim(),
        newPassword: newPassword,
      );
      _clearRateLimit();
      notifyListeners();
      return true;
    } catch (e) {
      final message = e.toString().replaceAll('Exception: ', '');
      _errorMessage = message;
      if (message.contains('Too many requests')) {
        _startRateLimit(const Duration(seconds: 30));
      }
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateInterestsModels(List<InterestModel> models) async {
    final List<InterestModel> oldModels = List.from(_userInterestModels);
    try {
      _userInterestModels = List.from(models);
      _errorMessage = null;

      final labelsList = models.map((m) => m.label).toList();
      if (labelsList.isNotEmpty) {
        await ApiService.updateInterests(labelsList);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userInterests', labelsList.join(','));
        await prefs.setBool('skippedInterests', false);
      }

      _needsInterests = false;
      notifyListeners();
      return true;
    } catch (e) {
      _userInterestModels = oldModels;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> skipInterests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('skippedInterests', true);
    _needsInterests = false;
    notifyListeners();
  }

  Future<bool> updateName(String name) async {
    try {
      final data = await ApiService.updateName(name);
      await _applyProfile(data);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateEmail(String email) async {
    try {
      final data = await ApiService.updateEmail(email);
      await _applyProfile(data);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await ApiService.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount(String password) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await ApiService.deleteAccount(password: password);
      await logout();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateLevel(String level) async {
    try {
      _userLevel = level;
      final data = await ApiService.updateLevel(level);
      await _applyProfile(data);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> completeQuiz({String? detectedLevel}) async {
    if (detectedLevel != null) {
      await updateLevel(detectedLevel);
      _hasTakenTest = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('skippedLevelTest', false);
    }
    notifyListeners();
  }

  Future<void> skipLevelTest() async {
    final prefs = await SharedPreferences.getInstance();
    _userLevel ??= 'A1';
    _hasTakenTest = true;
    await prefs.setBool('skippedLevelTest', true);
    await prefs.setString('userLevel', _userLevel!);
    try {
      await ApiService.updateLevel('A1');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiService.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isLoggedIn = false;
    _isEmailVerified = false;
    _hasTakenTest = false;
    _needsInterests = false;
    _userName = null;
    _userEmail = null;
    _userLevel = null;
    _userInterestModels = [];
    _errorMessage = null;
    notifyListeners();
  }

  void _clearRateLimit() {
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;
    _isRateLimited = false;
    _rateLimitUntil = null;
  }

  void _startRateLimit(Duration duration) {
    _isRateLimited = true;
    _rateLimitUntil = DateTime.now().add(duration);
    _rateLimitTimer?.cancel();
    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_rateLimitUntil == null ||
          _rateLimitUntil!.isBefore(DateTime.now())) {
        _clearRateLimit();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _setInitializing(bool val) {
    _isInitializing = val;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _rateLimitTimer?.cancel();
    super.dispose();
  }
}
