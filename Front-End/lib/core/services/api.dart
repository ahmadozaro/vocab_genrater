import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';
import '../models/quiz.dart';
import '../models/notification.dart';

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Unauthorized']);

  @override
  String toString() => message;
}

class RateLimitException implements Exception {
  final String message;
  RateLimitException(
      [this.message = 'Too many requests. Please try again later.']);

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;
  NetworkException([this.message = 'Network error. Please try again.']);

  @override
  String toString() => message;
}

class ApiService {
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  // ─── TOKEN CACHE ──────────────────────────────────────────────────
  static String? _cachedToken;
  static String? _cachedRefreshToken;

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> saveAuthTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    _cachedToken = accessToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _cachedRefreshToken = refreshToken;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString('refresh_token', refreshToken);
    }
  }

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('auth_token');
    return _cachedToken;
  }

  static Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null) return _cachedRefreshToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedRefreshToken = prefs.getString('refresh_token');
    return _cachedRefreshToken;
  }

  static Future<void> clearToken() async {
    _cachedToken = null;
    _cachedRefreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }

  static Future<void> logout() async {
    final refreshToken = await getRefreshToken();
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        );
      }
    } catch (_) {
      // Local logout must still succeed even when the network is unavailable.
    } finally {
      await clearToken();
    }
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic _decodeBody(http.Response res) {
    final body = utf8.decode(res.bodyBytes);
    if (body.trim().isEmpty) return {};
    return jsonDecode(body);
  }

  static Future<bool> _refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final data = _decodeBody(res);
      final access = data is Map ? data['access_token'] as String? : null;
      final refresh = data is Map ? data['refresh_token'] as String? : null;
      if (access == null || access.isEmpty) return false;
      await saveAuthTokens(accessToken: access, refreshToken: refresh);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<dynamic> _handleAuthed(
    http.Response res,
    Future<http.Response> Function() retry,
  ) async {
    if (res.statusCode == 401 && await _refreshAccessToken()) {
      return _handle(await retry());
    }
    return _handle(res);
  }

  // ─── AUTH ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    final data = Map<String, dynamic>.from(_handle(res));
    final token = data['access_token'] as String?;
    if (token != null && token.isNotEmpty) {
      await saveAuthTokens(
        accessToken: token,
        refreshToken: data['refresh_token'] as String?,
      );
    }
    return data;
  }

  // ✅ الإصلاح: تغيير Content-Type لـ JSON وإرسال email بدل username
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = Map<String, dynamic>.from(_handle(res));
    final token = data['access_token'] as String?;
    if (token != null && token.isNotEmpty) {
      await saveAuthTokens(
        accessToken: token,
        refreshToken: data['refresh_token'] as String?,
      );
    }
    return data;
  }

  // ─── FORGOT PASSWORD ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> requestResetCode(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return Map<String, dynamic>.from(_handle(response));
  }

  static Future<void> confirmResetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(data['detail'] ?? 'فشل إعادة تعيين كلمة المرور');
    }
  }

  // ─── Verify Email OTP ──────────────────────────────────────────
  static Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ?? data['message'] ?? 'Invalid verification code.',
      );
    }
    final token = data['access_token'];
    if (token is String && token.isNotEmpty) {
      await saveAuthTokens(
        accessToken: token,
        refreshToken: data['refresh_token'] as String?,
      );
    }
  }

  // ─── Resend Verification Code ──────────────────────────────────
  static Future<Map<String, dynamic>> resendVerificationCode({
    required String email,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/resend-verification'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            data['message'] ??
            'Failed to resend verification code.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  // ─── USER PROFILE ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getProfile() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: headers,
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> updateName(String name) async {
    final headers = await _authHeaders();
    final res = await http.patch(
      Uri.parse('$baseUrl/users/me'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> updateEmail(String email) async {
    final headers = await _authHeaders();
    final res = await http.patch(
      Uri.parse('$baseUrl/users/me'),
      headers: headers,
      body: jsonEncode({'email': email}),
    );
    return _handle(res);
  }

  static Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final headers = await _authHeaders();
    final res = await http.patch(
      Uri.parse('$baseUrl/users/me/password'),
      headers: headers,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    if (res.statusCode != 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final detail = data['detail'];
      throw Exception(detail is String ? detail : 'Failed to update password');
    }
  }

  static Future<Map<String, dynamic>> updateLevel(String level) async {
    final headers = await _authHeaders();
    final res = await http.patch(
      Uri.parse('$baseUrl/users/me/level'),
      headers: headers,
      body: jsonEncode({'level': level}),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> updateInterests(
    List<String> interests,
  ) async {
    final headers = await _authHeaders();
    final res = await http.patch(
      Uri.parse('$baseUrl/users/me/interests'),
      headers: headers,
      body: jsonEncode({'interests': interests.join(',')}),
    );
    return _handle(res);
  }

  // ─── WORDS ────────────────────────────────────────────────────────

  static Future<WordModel> createWord({
    required String text,
    String? arabicMeaning,
    String? audio,
    String? source,
    List<String> examples = const [],
  }) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/words'),
      headers: headers,
      body: jsonEncode({
        'text': text,
        'arabicMeaning': arabicMeaning,
        'audio': audio,
        'source': source,
        'examples': examples,
      }),
    );
    return WordModel.fromJson(_handle(res));
  }

  static Future<WordModel> lookupWord(String text) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/words/lookup'),
      headers: headers,
      body: jsonEncode({'text': text}),
    );
    return WordModel.fromJson(_handle(res));
  }

  static Future<Map<String, dynamic>> translateInstant(String text) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(
      '$baseUrl/words/translate-instant',
    ).replace(queryParameters: {'text': text});
    final res = await http.get(uri, headers: headers);
    return Map<String, dynamic>.from(_handle(res));
  }

  static Future<List<WordModel>> getWords() async {
    final headers = await _authHeaders();
    Future<http.Response> send() async =>
        http.get(Uri.parse('$baseUrl/words'), headers: await _authHeaders());
    final res = await http.get(Uri.parse('$baseUrl/words'), headers: headers);
    final list = await _handleAuthed(res, send) as List;
    return list.map((e) => WordModel.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> getWordsPage({
    int page = 1,
    int limit = 50,
    String? search,
    String? status,
  }) async {
    Uri uri() => Uri.parse('$baseUrl/words').replace(queryParameters: {
          'page': '$page',
          'limit': '$limit',
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          if (status != null && status.trim().isNotEmpty)
            'status': status.trim(),
        });
    Future<http.Response> send() async =>
        http.get(uri(), headers: await _authHeaders());
    final res = await send();
    final data = await _handleAuthed(res, send);
    if (data is List) {
      return {
        'words': data.map((e) => WordModel.fromJson(e)).toList(),
        'total': data.length,
        'page': 1,
        'pages': 1,
      };
    }
    final map = Map<String, dynamic>.from(data as Map);
    return {
      'words': (map['words'] as List? ?? [])
          .map((e) => WordModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      'total': map['total'] ?? 0,
      'page': map['page'] ?? page,
      'pages': map['pages'] ?? 1,
    };
  }

  static Future<WordModel> getWord(int wordId) async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/words/$wordId'),
      headers: headers,
    );
    return WordModel.fromJson(Map<String, dynamic>.from(_handle(res)));
  }

  static Future<void> deleteWord(int wordId) async {
    Future<http.Response> send() async => http.delete(
          Uri.parse('$baseUrl/words/$wordId'),
          headers: await _authHeaders(),
        );
    await _handleAuthed(await send(), send);
  }

  static Future<WordModel> restoreWord(int wordId) async {
    Future<http.Response> send() async => http.post(
          Uri.parse('$baseUrl/words/$wordId/restore'),
          headers: await _authHeaders(),
        );
    return WordModel.fromJson(
        Map<String, dynamic>.from(await _handleAuthed(await send(), send)));
  }

  // ─── QUIZ ─────────────────────────────────────────────────────────

  static Future<QuizModel> createQuiz() async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/quizzes'),
      headers: headers,
    );
    return QuizModel.fromJson(Map<String, dynamic>.from(_handle(res)));
  }

  static Future<QuizModel> createAiReviewQuiz() async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/quizzes/ai-review'),
      headers: headers,
    );
    return QuizModel.fromJson(Map<String, dynamic>.from(_handle(res)));
  }

  static Future<List<QuizHistory>> getQuizHistory() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$baseUrl/quizzes'), headers: headers);
    final list = _handle(res) as List;
    return list.map((e) => QuizHistory.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> submitQuiz({
    required int quizId,
    required List<String> answers,
  }) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/quizzes/$quizId/submit'),
      headers: headers,
      body: jsonEncode({'answers': answers}),
    );
    return _handle(res);
  }

  // ─── AI SUGGESTIONS THROUGH BACKEND ──────────────────────────────

  static Future<List<Map<String, dynamic>>> suggestWords({
    required String level,
    required List<String> interests,
    required List<String> existingWords,
  }) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/ai/suggest-words'),
      headers: headers,
      body: jsonEncode({
        'level': level,
        'interests': interests,
        'existingWords': existingWords,
        'limit': 20,
      }),
    );
    final list = _handle(res) as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // ─── SM2 REVIEW QUIZ ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> startSm2Quiz() async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/sm2/quizzes/start'),
      headers: headers,
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> submitSm2Quiz({
    required int quizId,
    required List<Map<String, dynamic>> answers,
    bool confirmEmptyAsWrong = false,
  }) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/sm2/quizzes/$quizId/submit'),
      headers: headers,
      body: jsonEncode({
        'answers': answers,
        'confirmEmptyAsWrong': confirmEmptyAsWrong,
      }),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getSm2DueSummary() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/sm2/due-summary'),
      headers: headers,
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> abandonSm2Quiz(int quizId) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/sm2/quizzes/$quizId/abandon'),
      headers: headers,
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getProgress() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/progress/me'),
      headers: headers,
    );
    return _handle(res);
  }

  // ─── NOTIFICATIONS ──────────────────────────────────────────────

  static Future<List<AppNotification>> getNotifications() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: headers,
    );
    final list = _handle(res) as List;
    return list.map((e) => AppNotification.fromJson(e)).toList();
  }

  static Future<List<AppNotification>> syncNotifications() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/notifications/sync'),
      headers: headers,
    );
    final list = _handle(res) as List;
    return list.map((e) => AppNotification.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> markNotificationRead(int id) async {
    final headers = await _authHeaders();
    final res = await http.put(
      Uri.parse('$baseUrl/notifications/$id/read'),
      headers: headers,
    );
    return Map<String, dynamic>.from(_handle(res));
  }

  static Future<void> markAllNotificationsRead() async {
    final headers = await _authHeaders();
    await http.put(
      Uri.parse('$baseUrl/notifications/read-all'),
      headers: headers,
    );
  }

  static Future<Map<String, dynamic>> getUnreadNotificationCount() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/notifications/unread-count'),
      headers: headers,
    );
    return Map<String, dynamic>.from(_handle(res));
  }

  // ─── ERROR HANDLER ────────────────────────────────────────────────

  static dynamic _handle(http.Response res) {
    dynamic decoded;
    try {
      decoded = _decodeBody(res);
    } catch (_) {
      if (res.statusCode >= 200 && res.statusCode < 300) return {};
      throw NetworkException('Invalid server response (${res.statusCode})');
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
    if (res.statusCode == 401) throw UnauthorizedException();
    if (res.statusCode == 429) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw RateLimitException(
        detail?.toString() ?? 'Too many requests. Please try again later.',
      );
    }
    final detail = decoded is Map ? decoded['detail'] : null;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map) {
        final loc = first['loc'];
        final field = loc is List && loc.isNotEmpty ? loc.last : 'unknown';
        final msg = first['msg'] ?? '';
        throw Exception('Error in ($field): $msg');
      }
    }
    throw Exception(detail?.toString() ?? 'Server error (${res.statusCode})');
  }

  // ignore: unused_element
  static dynamic _handleLegacy(http.Response res) {
    final String body = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(body);
    }
    try {
      final err = jsonDecode(body);
      final detail = err['detail'];
      if (detail == null) throw Exception('حدث خطأ غير متوقع');
      if (detail is List && detail.isNotEmpty) {
        final field = detail[0]['loc']?.last ?? 'unknown';
        final msg = detail[0]['msg'] ?? '';
        throw Exception('خطأ في ($field): $msg');
      }
      throw Exception(detail.toString());
    } on FormatException {
      throw Exception('خطأ في السيرفر (${res.statusCode})');
    }
  }
}
