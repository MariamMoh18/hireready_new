import 'dart:convert';
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
      final response = await ApiService.post(
        '/auth/register',
        body: {
          'name': name,
          'email': email,
          'password': password,
        },
        auth: false,
      );
      final body = jsonDecode(response.body);
      final success = response.statusCode == 201;
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
      final response = await ApiService.post(
        '/auth/login',
        body: {'email': email, 'password': password},
        auth: false,
      );
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          body['access_token'] is String &&
          body['user'] is Map<String, dynamic>) {
        final token = body['access_token'] as String;
        final user = body['user'] as Map<String, dynamic>;
        final userId = user['id'] as int? ?? 0;

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
      await ApiService.post('/auth/logout');
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
}
