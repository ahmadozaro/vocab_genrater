import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';
import '../models/quiz.dart';
import '../models/notification.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  // ─── TOKEN CACHE ──────────────────────────────────────────────────
  static String? _cachedToken;

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('auth_token');
    return _cachedToken;
  }

  static Future<void> clearToken() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
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
      await saveToken(token);
    }
    return data;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );
    final data = Map<String, dynamic>.from(_handle(res));
    final token = data['access_token'] as String?;
    if (token != null && token.isNotEmpty) {
      await saveToken(token);
    }
    return data;
  }

  // ─── FORGOT PASSWORD (إضافة وتصحيح) ───────────────────────────────

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
      Uri.parse('$baseUrl/auth/verify-email'), // ← غيّر المسار حسب الباك-إند
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
      await saveToken(token);
    }
  }

  // ─── Resend Verification Code ──────────────────────────────────
  static Future<Map<String, dynamic>> resendVerificationCode({
    required String email,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse(
        '$baseUrl/auth/resend-verification',
      ), // ← غيّر المسار حسب الباك-إند
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
    final res = await http.get(Uri.parse('$baseUrl/words'), headers: headers);
    final list = _handle(res) as List;
    return list.map((e) => WordModel.fromJson(e)).toList();
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
    final headers = await _authHeaders();
    final res = await http.delete(
      Uri.parse('$baseUrl/words/$wordId'),
      headers: headers,
    );
    _handle(res);
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

  static Future<Map<String, dynamic>> syncNotifications() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/notifications/sync'),
      headers: headers,
    );
    return _handle(res);
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
