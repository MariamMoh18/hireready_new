import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';

import 'api_service.dart';

class InterviewService {
  // ── Start session ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> startSession({
    required String jobPosition,
    String experienceLevel = 'Junior',
    String lengthType = 'standard',
    String mode = 'video',
  }) async {
    try {
      final res = await ApiService.post(
        '/sessions/start',
        body: {
          'job_field': jobPosition,
          'experience_level': experienceLevel,
          'length_type': lengthType,
          'mode': mode,
        },
        auth: true,
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 201) {
        if (body is Map<String, dynamic> && body['success'] == true) {
          return {
            'success': true,
            'session_id': body['data']['session_id'],
            'expires_at': body['data']['expires_at'],
            'questions': body['data']['questions'],
          };
        }

        // Backward-compatible handling for current backend shape
        if (body is Map<String, dynamic> && body['id'] != null) {
          return {
            'success': true,
            'session_id': body['id'],
            'questions': const <dynamic>[],
          };
        }
      }
      return {
        'success': false,
        'message': (body is Map<String, dynamic>)
            ? (body['message'] ?? 'Could not start session')
            : 'Could not start session',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Upload video answer ────────────────────────────────────────────
  static Future<Map<String, dynamic>> uploadVideoAnswer({
    required int sessionId,
    required int questionId,
    required XFile videoFile,
  }) async {
    try {
      // 1. Upload Media
      final token = await ApiService.getToken();
      final uri = Uri.parse(
          '${ApiService.baseUrl}/sessions/$sessionId/questions/$questionId/upload');

      final request = http.MultipartRequest('POST', uri);

      final bytes = await videoFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: videoFile.name));

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final streamed = await request.send();
      final uploadRes = await http.Response.fromStream(streamed);
      final uploadBody = jsonDecode(uploadRes.body);

      if (uploadRes.statusCode != 201 || uploadBody['success'] != true) {
        return {
          'success': false,
          'message': uploadBody['message'] ?? 'Upload failed'
        };
      }
      final mediaId = uploadBody['data']['media_id'];

      // 2. Transcribe
      final transcribeRes = await ApiService.post('/media/$mediaId/transcribe');
      final transcribeBody = jsonDecode(transcribeRes.body);
      final transcript = transcribeBody['data']?['transcript'] ?? '';

      // 3. Analyze Face
      await ApiService.post('/media/$mediaId/analyze-face');

      // 4. Analyze Voice
      await ApiService.post('/media/$mediaId/analyze-voice');

      // 5. Analyze Content (NLP)
      await ApiService.post(
        '/sessions/$sessionId/questions/$questionId/analyze-content',
        body: {'transcript': transcript},
      );

      // 6. Score
      final scoreRes = await ApiService.post(
          '/sessions/$sessionId/questions/$questionId/score');
      final scoreBody = jsonDecode(scoreRes.body);

      return {
        'success': true,
        'data': {
          'media_id': mediaId,
          'transcript': transcript,
          'score': scoreBody['data'],
        },
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Upload audio answer ────────────────────────────────────────────
  static Future<Map<String, dynamic>> uploadAudioAnswer({
    required int sessionId,
    required int questionId,
    required XFile audioFile,
  }) async {
    try {
      // 1. Upload Media
      final token = await ApiService.getToken();
      final uri = Uri.parse(
          '${ApiService.baseUrl}/sessions/$sessionId/questions/$questionId/upload');

      final request = http.MultipartRequest('POST', uri);

      final bytes = await audioFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: audioFile.name));

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final streamed = await request.send();
      final uploadRes = await http.Response.fromStream(streamed);
      final uploadBody = jsonDecode(uploadRes.body);

      if (uploadRes.statusCode != 201 || uploadBody['success'] != true) {
        return {
          'success': false,
          'message': uploadBody['message'] ?? 'Upload failed'
        };
      }
      final mediaId = uploadBody['data']['media_id'];

      // 2. Transcribe
      final transcribeRes = await ApiService.post('/media/$mediaId/transcribe');
      final transcribeBody = jsonDecode(transcribeRes.body);
      final transcript = transcribeBody['data']?['transcript'] ?? '';

      // 3. Analyze Voice (skip Face)
      await ApiService.post('/media/$mediaId/analyze-voice');

      // 4. Analyze Content (NLP)
      await ApiService.post(
        '/sessions/$sessionId/questions/$questionId/analyze-content',
        body: {'transcript': transcript},
      );

      // 5. Score
      final scoreRes = await ApiService.post(
          '/sessions/$sessionId/questions/$questionId/score');
      final scoreBody = jsonDecode(scoreRes.body);

      return {
        'success': true,
        'data': {
          'media_id': mediaId,
          'transcript': transcript,
          'score': scoreBody['data'],
        },
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── End session ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> endSession(int sessionId) async {
    try {
      final res = await ApiService.post(
        '/sessions/$sessionId/end',
        body: const {},
        auth: true,
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Could not end session',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Get session history ─────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getSessionHistory() async {
    try {
      final res = await ApiService.get('/sessions', auth: true);
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['success'] == true) {
        final sessions = body['data']['sessions'] as List<dynamic>;
        return sessions.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Generate overall feedback ──────────────────────────────────────
  static Future<Map<String, dynamic>> generateFeedback(int sessionId) async {
    try {
      // 1. Calculate final score first
      await ApiService.post('/sessions/$sessionId/final-score');

      // 2. Generate report
      final res = await ApiService.post(
        '/sessions/$sessionId/generate-report',
        auth: true,
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'feedback': body['data'],
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Could not generate feedback',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Delete session ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> deleteSession(int sessionId) async {
    try {
      final res = await ApiService.delete('/sessions/$sessionId', auth: true);
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['success'] == true) {
        return {'success': true};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Could not delete session',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ── Get Dashboard Metrics ──────────────────────────────────────────
  static Future<Map<String, dynamic>> getDashboardMetrics() async {
    try {
      // Fetch history to calculate basic metrics if a dedicated endpoint doesn't exist yet
      final history = await getSessionHistory();

      int totalSessions = history.length;
      double totalScore = 0;
      int completedSessionsWithScore = 0;
      double highestScore = 0;

      for (var session in history) {
        if (session['status'] == 'completed' &&
            session['overall_score'] != null) {
          final score = (session['overall_score'] as num).toDouble();
          totalScore += score;
          completedSessionsWithScore++;
          if (score > highestScore) highestScore = score;
        }
      }

      double averageScore = completedSessionsWithScore > 0
          ? totalScore / completedSessionsWithScore
          : 0;

      // Mocking some advanced metrics that would normally come from a heavier backend aggregation
      return {
        'success': true,
        'data': {
          'total_sessions': totalSessions,
          'average_score': averageScore.round(),
          'improvement_percentage':
              totalSessions > 1 ? 15 : 0, // Mock improvement
          'best_score': highestScore.round(),
          'weakest_category': 'Technical Depth', // Mock category
        }
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to load metrics: $e'};
    }
  }
}
