import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_interview/services/api_service.dart';

class UserService {
  static const String _cachedJobFieldKey = 'cached_job_field';
  static const String _cachedTargetRoleKey = 'cached_target_role';
  static const String _cachedExperienceKey = 'cached_experience_level';

  // ── Get Profile ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final profile = await _fetchProfileFromPaths(const ['/users/me', '/me']);
      if (profile != null) {
        final hydrated = await _mergeWithLocalProfileCache(profile);
        await _cacheProfileFields(hydrated);
        return hydrated;
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
      final payload = {
        if (name != null) 'name': name,
        if (fieldOfInterest != null) 'job_field': fieldOfInterest,
        if (targetRole != null) 'target_role': targetRole,
        if (experienceLevel != null) 'experience_level': experienceLevel,
      };

      final response = await ApiService.put('/users/me', body: payload);
      final body = _decodeMap(response.body);
      if (response.statusCode == 404) {
        final patchResponse = await ApiService.patch(
          '/profile',
          body: {
            if (name != null) 'name': name,
            if (experienceLevel != null) 'experience_level': experienceLevel,
          },
        );
        final patchBody = _decodeMap(patchResponse.body);
        if (patchResponse.statusCode == 200) {
          await _cacheProfileFields(payload);
          if (name != null && name.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_name', name);
          }
          return {'success': true, 'data': patchBody};
        }
      }

      if (response.statusCode == 200 &&
          (body['success'] == true || body.isNotEmpty)) {
        await _cacheProfileFields(payload);
        if (name != null && name.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', name);
        }
        return {'success': true, 'data': body['data'] ?? body};
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
      final payload = {
        'job_field': jobField,
        'experience_level': experienceLevel,
        'target_role': targetRole,
        if (name != null && name.isNotEmpty) 'name': name,
        if (skills != null) 'skills': skills,
      };

      final endpoints = <String>[
        '/users/profile-setup',
        '/auth/users/profile-setup',
      ];

      Map<String, dynamic>? body;
      int statusCode = 0;
      for (final endpoint in endpoints) {
        final response = await ApiService.put(endpoint, body: payload, auth: true);
        statusCode = response.statusCode;
        body = _decodeMap(response.body);
        if (statusCode != 404) {
          break;
        }
      }

      if (statusCode == 404) {
        final patchRes = await ApiService.patch(
          '/profile',
          body: {
            if (name != null && name.isNotEmpty) 'name': name,
            'experience_level': experienceLevel,
          },
        );
        statusCode = patchRes.statusCode;
        body = _decodeMap(patchRes.body);
      }

      if (statusCode == 200 && body != null) {
        await _cacheProfileFields(payload);
        if (name != null && name.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', name);
        }
        return {'success': true, 'data': body['data'] ?? body};
      }
      return {
        'success': false,
        'message': body?['message'] ?? 'Failed to setup profile'
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>?> _fetchProfileFromPaths(
    List<String> paths,
  ) async {
    for (final path in paths) {
      final response = await ApiService.get(path);
      if (response.statusCode == 404) {
        continue;
      }
      if (response.statusCode != 200) {
        return null;
      }
      final body = _decodeMap(response.body);
      if (body['success'] == true && body['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(body['data'] as Map<String, dynamic>);
      }
      if (body.isNotEmpty) {
        return body;
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> _mergeWithLocalProfileCache(
    Map<String, dynamic> profile,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      ...profile,
      'job_field': profile['job_field'] ?? prefs.getString(_cachedJobFieldKey),
      'target_role': profile['target_role'] ?? prefs.getString(_cachedTargetRoleKey),
      'experience_level':
          profile['experience_level'] ?? prefs.getString(_cachedExperienceKey),
    };
  }

  static Future<void> _cacheProfileFields(Map<String, dynamic> source) async {
    final prefs = await SharedPreferences.getInstance();
    final jobField = source['job_field']?.toString();
    final targetRole = source['target_role']?.toString();
    final experience = source['experience_level']?.toString();
    if (jobField != null && jobField.isNotEmpty) {
      await prefs.setString(_cachedJobFieldKey, jobField);
    }
    if (targetRole != null && targetRole.isNotEmpty) {
      await prefs.setString(_cachedTargetRoleKey, targetRole);
    }
    if (experience != null && experience.isNotEmpty) {
      await prefs.setString(_cachedExperienceKey, experience);
    }
  }

  static Map<String, dynamic> _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }
}
