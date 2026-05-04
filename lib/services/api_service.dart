import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _configuredApiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  // For physical device or iOS simulator, change to your PC's LAN IP.
  static const String _deviceUrl = 'http://192.168.1.10:5000';

  static String get baseUrl {
    if (_configuredApiBase.isNotEmpty) {
      return _configuredApiBase;
    }
    if (kIsWeb) {
      // Chrome runs on the same machine as the backend
      return 'http://localhost:5000/api/v1';
    }
    // For Android physical device, use the LAN IP
    return '$_deviceUrl/api/v1';
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
    final url = Uri.parse('$baseUrl$path');
    final headers = await _headers(auth: auth);
    return http.get(url, headers: headers);
  }

  // ── POST ───────────────────────────────────────────────────────────
  static Future<http.Response> post(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _headers(auth: auth);
    return http.post(url, headers: headers, body: jsonEncode(body));
  }

  // ── PUT ────────────────────────────────────────────────────────────
  static Future<http.Response> put(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _headers(auth: auth);
    return http.put(url, headers: headers, body: jsonEncode(body));
  }

  // ── PATCH ───────────────────────────────────────────────────────────
  static Future<http.Response> patch(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _headers(auth: auth);
    return http.patch(url, headers: headers, body: jsonEncode(body));
  }

  // ── DELETE ──────────────────────────────────────────────────────────
  static Future<http.Response> delete(String path, {bool auth = true}) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _headers(auth: auth);
    return http.delete(url, headers: headers);
  }
}
