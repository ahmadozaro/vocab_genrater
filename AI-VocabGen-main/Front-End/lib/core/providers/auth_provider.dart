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

  // ✅ مستخدم جديد سجّل للتو ولم يختر اهتماماته بعد
  bool _needsInterests = false;

  String? _errorMessage;
  String? _userName;
  String? _userEmail;
  String? _userLevel;
  String? _lastVerificationDebugCode;
  String? _lastResetDebugCode;
  String? _loginChallengeId;
  String? _lastLoginOtpDebugCode;
  List<InterestModel> _userInterestModels = [];

  bool get isLoggedIn => _isLoggedIn;
  bool get hasTakenTest => _hasTakenTest;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  bool get isEmailVerified => _isEmailVerified;
  bool get needsInterests => _needsInterests; // ✅ جديد
  String? get errorMessage => _errorMessage;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userLevel => _userLevel;
  String? get lastVerificationDebugCode => _lastVerificationDebugCode;
  String? get lastResetDebugCode => _lastResetDebugCode;
  String? get loginChallengeId => _loginChallengeId;
  String? get lastLoginOtpDebugCode => _lastLoginOtpDebugCode;
  List<InterestModel> get userInterestModels => _userInterestModels;
  List<String> get userInterests =>
      _userInterestModels.map((m) => m.label).toList();

  Future<void> loadUser() async {
    _setInitializing(true);
    try {
      final token = await ApiService.getToken();
      final prefs = await SharedPreferences.getInstance();

      _isLoggedIn = token != null;
      _hasTakenTest = prefs.getBool('hasTakenTest') ?? false;
      _isEmailVerified = false;
      _needsInterests = false;

      if (_isLoggedIn) {
        _userName = prefs.getString('userName');
        _userEmail = prefs.getString('userEmail');
        _userLevel = prefs.getString('userLevel') ?? 'A1';

        final saved = prefs.getString('userInterests') ?? '';
        final labels = saved.isEmpty ? <String>[] : saved.split(',');
        _userInterestModels = labels
            .map((l) => labelToModel(l.trim()))
            .toList();

        await _refreshProfile();
      }
    } finally {
      _setInitializing(false);
    }
  }

  Future<void> _refreshProfile() async {
    try {
      final data = await ApiService.getProfile();
      final serverInterests = data['interests'] ?? '';
      if ((serverInterests as String).isEmpty &&
          _userInterestModels.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        _userName = data['name'];
        _userEmail = data['email'];
        _userLevel = data['level'] ?? 'A1';
        await prefs.setString('userName', _userName ?? '');
        await prefs.setString('userEmail', _userEmail ?? '');
        await prefs.setString('userLevel', _userLevel!);
        notifyListeners();
        return;
      }
      await _applyProfile(data);
      _needsInterests =
          _isLoggedIn &&
          _isEmailVerified &&
          _userInterestModels.isEmpty &&
          !_hasTakenTest;
    } catch (_) {
      await ApiService.clearToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('userName');
      await prefs.remove('userEmail');
      await prefs.remove('userLevel');
      await prefs.remove('userInterests');
      await prefs.remove('hasTakenTest');
      _isLoggedIn = false;
      _hasTakenTest = false;
      _isEmailVerified = false;
      _needsInterests = false;
      _userName = null;
      _userEmail = null;
      _userLevel = 'A1';
      _userInterestModels = [];
      notifyListeners();
    }
  }

  Future<void> _applyProfile(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    _userName = data['name'];
    _userEmail = data['email'];
    _userLevel = data['level'] ?? 'A1';
    _isEmailVerified = data['is_email_verified'] == true;
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
      _loginChallengeId = data['challenge_id']?.toString();
      _lastLoginOtpDebugCode = data['debug_code']?.toString();
      if (_loginChallengeId == null || _loginChallengeId!.isEmpty) {
        _errorMessage = 'Login verification could not be started.';
        notifyListeners();
        return false;
      }
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

  Future<bool> verifyLoginOtp(String email, String code) async {
    if (_loginChallengeId == null || _loginChallengeId!.isEmpty) {
      _errorMessage = 'Please login again.';
      notifyListeners();
      return false;
    }
    if (code.trim().length != 6) {
      _errorMessage = 'Please enter the 6-digit code';
      notifyListeners();
      return false;
    }
    _setLoading(true);
    _errorMessage = null;
    try {
      await ApiService.verifyLoginOtp(
        email: email.trim(),
        challengeId: _loginChallengeId!,
        code: code.trim(),
      );
      final data = await ApiService.getProfile();
      final hasSavedLevel =
          data['level'] != null && data['level'].toString().isNotEmpty;
      await _applyProfile(data);
      _isLoggedIn = true;
      _needsInterests = _userInterestModels.isEmpty;
      _hasTakenTest = hasSavedLevel;
      _loginChallengeId = null;
      _lastLoginOtpDebugCode = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasTakenTest', hasSavedLevel);
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

  Future<bool> resendLoginOtp(String email) async {
    if (_loginChallengeId == null || _loginChallengeId!.isEmpty) {
      _errorMessage = 'Please login again.';
      notifyListeners();
      return false;
    }
    _setLoading(true);
    _errorMessage = null;
    try {
      final data = await ApiService.resendLoginOtp(
        email: email.trim(),
        challengeId: _loginChallengeId!,
      );
      _lastLoginOtpDebugCode = data['debug_code']?.toString();
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

  Future<bool> register(
    String name,
    String email,
    String password,
    String confirm, {
    List<InterestModel>? initialInterests,
  }) async {
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
      _isLoggedIn = false;
      _isEmailVerified = false;
      _needsInterests = false;
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

  // ✅ بعد التحقق: isLoggedIn=true + needsInterests=true
  //    → _AppRouter يعرض InterestsScreen وليس TestScreen مباشرة
  Future<bool> verifyEmail(String email, String code) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await ApiService.verifyEmail(email: email.trim(), code: code);
      final data = await ApiService.getProfile();
      await _applyProfile(data);
      _isLoggedIn = true;
      _isEmailVerified = true;
      _hasTakenTest = false;
      _needsInterests = true; // ✅ يجب اختيار الاهتمامات أولاً
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasTakenTest', false);
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
    _setLoading(true);
    _errorMessage = null;
    _lastResetDebugCode = null;
    try {
      final data = await ApiService.requestResetCode(email.trim());
      _lastResetDebugCode = data['debug_code']?.toString();
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
    _setLoading(true);
    _errorMessage = null;
    try {
      await ApiService.confirmResetPassword(
        email: email.trim(),
        code: code.trim(),
        newPassword: newPassword,
      );
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

  // ✅ بعد الحفظ: needsInterests=false → Router يقفز لـ TestScreen
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
      }

      _needsInterests = false; // ✅ انتهى من الاهتمامات
      notifyListeners();
      return true;
    } catch (e) {
      _userInterestModels = oldModels;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // ✅ تخطّي الاهتمامات → needsInterests=false مباشرة
  void skipInterests() {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasTakenTest', true);
    _hasTakenTest = true;
    if (detectedLevel != null) await updateLevel(detectedLevel);
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isLoggedIn = false;
    _isEmailVerified = false;
    _hasTakenTest = false;
    _needsInterests = false;
    _userName = null;
    _userEmail = null;
    _userLevel = 'A1';
    _userInterestModels = [];
    _errorMessage = null;
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
}
