import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'user_service.dart';

class AuthService {
  // ── Register ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _postWithPaths(
        const ['/auth/register', '/register'],
        body: {
          'name': name,
          'email': email,
          'password': password,
        },
      );
      final body = _decodeBody(response.body);
      final success = response.statusCode == 201 || response.statusCode == 200;
      final message = body['message'] ??
          (success ? 'Registered successfully' : 'Registration failed');

      return {
        'success': success,
        'message': message,
        if (success) 'user': body['user'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Login ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _postWithPaths(
        const ['/auth/login', '/login'],
        body: {'email': email, 'password': password},
      );
      final body = _decodeBody(response.body);

      if (response.statusCode == 200 &&
          body['access_token'] is String &&
          body['user'] is Map<String, dynamic>) {
        final token = body['access_token'] as String;
        final user = body['user'] as Map<String, dynamic>;
        final userId = _toInt(user['id']);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setInt('user_id', userId);
        await prefs.setString('user_name', user['name'] as String? ?? '');

        final userProfile = await UserService.getProfile();
        final profileData = userProfile ?? user;
        final name = profileData['name'] as String? ?? '';
        final profileCompleted = (profileData['experience_level'] as String?) != null;

        return {
          'success': true,
          'name': name,
          'user': profileData,
          'profile_completed': profileCompleted,
        };
      } else {
        final message = body['message'] ?? 'Invalid credentials';
        return {
          'success': false,
          'message': message,
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────
  static Future<void> logout() async {
    try {
      await _postWithPaths(
        const ['/auth/logout', '/logout'],
        body: const {},
        auth: true,
      );
    } catch (_) {}
    await ApiService.clearToken();
  }

  // ── Status helpers ─────────────────────────────────────────────────
  static Future<bool> isLoggedIn() async {
    final token = await ApiService.getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name') ?? 'User';
  }

  static Future<int> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id') ?? 0;
  }

  static Future<http.Response> _postWithPaths(
    List<String> paths, {
    required Map<String, dynamic> body,
    bool auth = false,
  }) async {
    http.Response? lastResponse;
    for (final path in paths) {
      final res = await ApiService.post(path, body: body, auth: auth);
      if (res.statusCode == 404) {
        lastResponse = res;
        continue;
      }
      return res;
    }
    return lastResponse ?? await ApiService.post(paths.first, body: body, auth: auth);
  }

  static Map<String, dynamic> _decodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
