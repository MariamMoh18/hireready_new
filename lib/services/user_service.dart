import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_interview/services/api_service.dart';

class UserService {
  // ── Get Profile ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await ApiService.get('/users/me');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          // The new V1 returns the user dict directly in data.
          return body['data'] as Map<String, dynamic>?;
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Get Progress ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getProgress() async {
    try {
      final response = await ApiService.get('/users/me/progress');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return body['data'] as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Update Profile ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? fieldOfInterest,
    String? targetRole,
    String? experienceLevel,
  }) async {
    try {
      final response = await ApiService.put(
        '/users/me',
        body: {
          if (name != null) 'name': name,
          if (fieldOfInterest != null) 'job_field': fieldOfInterest,
          if (targetRole != null) 'target_role': targetRole,
          if (experienceLevel != null) 'experience_level': experienceLevel,
        },
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        if (name != null && name.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', name);
        }
        return {'success': true, 'data': body['data']};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Failed to update profile'
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Setup Profile (After Registration) ───────────────────────────
  static Future<Map<String, dynamic>> setupProfile({
    required String jobField,
    required String experienceLevel,
    required String targetRole,
    String? name,
    String? skills,
  }) async {
    try {
      final response = await ApiService.put(
        '/users/profile-setup',
        body: {
          'job_field': jobField,
          'experience_level': experienceLevel,
          'target_role': targetRole,
          if (name != null && name.isNotEmpty) 'name': name,
          if (skills != null) 'skills': skills,
        },
        auth: true,
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        if (name != null && name.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', name);
        }
        return {'success': true, 'data': body['data']};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Failed to setup profile'
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}
