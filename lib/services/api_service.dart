import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _configuredApiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  // Default to loopback and use adb reverse for Android physical devices.
  static const String _deviceUrl = 'http://192.168.1.7:5000';
  static const String _webUrl = 'http://localhost:5000';

  static String get baseUrl {
    if (_configuredApiBase.isNotEmpty) {
      return _configuredApiBase;
    }
    if (kIsWeb) {
      return _webUrl;
    }
    return _deviceUrl;
  }

  // ── Token helpers ──────────────────────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_name');
    await prefs.remove('user_id');
    // Clear cached profile data to prevent leaking across users
    await prefs.remove('cached_job_field');
    await prefs.remove('cached_target_role');
    await prefs.remove('cached_experience_level');
  }

  // ── Auth headers ───────────────────────────────────────────────────
  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // ── GET ────────────────────────────────────────────────────────────
  static Future<http.Response> get(String path, {bool auth = true}) async {
    return _requestWithFallback(
      path: path,
      auth: auth,
      sender: (url, headers) => http.get(url, headers: headers),
    );
  }

  // ── POST ───────────────────────────────────────────────────────────
  static Future<http.Response> post(String path,
      {Map<String, dynamic>? body, bool auth = true, int timeoutSeconds = 8}) async {
    final encoded = jsonEncode(body);
    return _requestWithFallback(
      path: path,
      auth: auth,
      timeoutSeconds: timeoutSeconds,
      sender: (url, headers) => http.post(url, headers: headers, body: encoded),
    );
  }

  // ── PUT ────────────────────────────────────────────────────────────
  static Future<http.Response> put(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final encoded = jsonEncode(body);
    return _requestWithFallback(
      path: path,
      auth: auth,
      sender: (url, headers) => http.put(url, headers: headers, body: encoded),
    );
  }

  // ── PATCH ───────────────────────────────────────────────────────────
  static Future<http.Response> patch(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final encoded = jsonEncode(body);
    return _requestWithFallback(
      path: path,
      auth: auth,
      sender: (url, headers) => http.patch(url, headers: headers, body: encoded),
    );
  }

  // ── DELETE ──────────────────────────────────────────────────────────
  static Future<http.Response> delete(String path, {bool auth = true}) async {
    return _requestWithFallback(
      path: path,
      auth: auth,
      sender: (url, headers) => http.delete(url, headers: headers),
    );
  }

  static List<Uri> candidateUris(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final hasApiPrefix = normalized.startsWith('/api/');
    if (hasApiPrefix) {
      return <Uri>[Uri.parse('$baseUrl$normalized')];
    }
    return <Uri>[
      Uri.parse('$baseUrl/api/v1$normalized'),
      Uri.parse('$baseUrl$normalized'),
    ];
  }

  static Future<http.Response> _requestWithFallback({
    required String path,
    required bool auth,
    int timeoutSeconds = 8,
    required Future<http.Response> Function(
      Uri url,
      Map<String, String> headers,
    ) sender,
  }) async {
    final headers = await _headers(auth: auth);

    final uris = candidateUris(path);
    http.Response? last404;

    for (var i = 0; i < uris.length; i++) {
      final url = uris[i];
      final isLast = i == uris.length - 1;

      try {
        final response = await sender(url, headers).timeout(
          Duration(seconds: timeoutSeconds),
        );
        if (response.statusCode == 404) {
          last404 = response;
          if (!isLast) continue; // Try next URL pattern
        }
        return response;
      } catch (e) {
        if (isLast) rethrow; // Real endpoint failed — propagate
        // Prefix URL failed — silently continue to try real URL
      }
    }

    if (last404 != null) return last404;
    throw Exception('Network error');
  }
}
