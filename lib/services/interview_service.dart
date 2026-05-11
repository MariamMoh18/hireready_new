import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:camera/camera.dart';

import 'api_service.dart';

class InterviewService {
  static const List<String> _questionFlow = <String>[
    'behavioral',
    'behavioral',
    'technical',
    'technical',
    'situational',
  ];

  // ── Start session ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> startSession({
    required String jobPosition,
    String experienceLevel = 'Junior',
    String lengthType = 'standard',
    String mode = 'video',
  }) async {
    try {
      final normalizedPosition = jobPosition.trim();
      final parsedPositionId = int.tryParse(normalizedPosition);
      final res = await ApiService.post(
        '/sessions/start',
        body: {
          if (parsedPositionId != null) 'position_id': parsedPositionId,
          if (parsedPositionId == null) 'job_field': normalizedPosition,
          'experience_level': experienceLevel,
          'session_type': lengthType,
          'mode': mode,
        },
        auth: true,
      );
      final body = _decodeMap(res.body);
      if (res.statusCode == 201) {
        if (body['success'] == true && body['data'] is Map<String, dynamic>) {
          final questions = _normalizeQuestions(
            rawQuestions: (body['data']['questions'] as List<dynamic>?) ??
                const <dynamic>[],
            jobPosition: jobPosition,
            desiredCount: _questionCountForLength(lengthType),
          );
          return {
            'success': true,
            'session_id': body['data']['session_id'],
            'expires_at': body['data']['expires_at'],
            'questions': questions,
          };
        }

        // Backward-compatible handling for current backend shape
        final sessionId =
            body['id'] ?? body['session_id'] ?? body['data']?['id'];
        if (sessionId != null) {
          final sessionQuestions =
              await _fetchSessionQuestions(_toInt(sessionId));
          final questions = await _fetchQuestionsForRole(
            jobPosition: jobPosition,
            desiredCount: _questionCountForLength(lengthType),
            seedQuestions: sessionQuestions,
            sessionId: _toInt(sessionId),
          );
          return {
            'success': true,
            'session_id': sessionId,
            'questions': questions,
          };
        }
      }
      return {
        'success': false,
        'message': body['message'] ??
            body['msg'] ??
            'Could not start session (HTTP ${res.statusCode}). Try again or contact support.',
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

  static Future<Map<String, dynamic>> uploadAudioBytesAnswer({
    required int sessionId,
    required int questionId,
    required Uint8List audioBytes,
    String filename = 'answer.webm',
    String questionText = '',
  }) async {
    try {
      final token = await ApiService.getToken();
      http.Response? response;
      for (final uri
          in ApiService.candidateUris('/sessions/$sessionId/answers/audio')) {
        final request = http.MultipartRequest('POST', uri)
          ..fields['question_id'] = '$questionId'
          ..fields['question_text'] = questionText
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              audioBytes,
              filename: filename,
              contentType: _contentTypeForFilename(filename),
            ),
          );
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
        final streamed = await request.send();
        final candidate = await http.Response.fromStream(streamed);
        if (candidate.statusCode == 404) {
          response = candidate;
          continue;
        }
        response = candidate;
        break;
      }
      response ??= http.Response('{"message":"Audio upload failed"}', 500);
      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = null;
      }

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': body,
        };
      }

      final responseSnippet = response.body.length > 400
          ? response.body.substring(0, 400)
          : response.body;

      return {
        'success': false,
        'message': (body is Map<String, dynamic>)
            ? (body['message'] ??
                body['error'] ??
                (body['errors'] != null
                    ? 'Audio upload failed (HTTP ${response.statusCode}). '
                        'Errors: ${body['errors']}'
                    : 'Audio upload failed (HTTP ${response.statusCode}). '
                        'Response: $responseSnippet'))
            : 'Audio upload failed (HTTP ${response.statusCode}). Response: $responseSnippet',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static MediaType? _contentTypeForFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.wav')) return MediaType('audio', 'wav');
    if (lower.endsWith('.webm')) return MediaType('audio', 'webm');
    if (lower.endsWith('.m4a')) return MediaType('audio', 'mp4');
    if (lower.endsWith('.mp3')) return MediaType('audio', 'mpeg');
    return null;
  }

  // ── End session ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> endSession(int sessionId) async {
    try {
      final res = await ApiService.post(
        '/sessions/$sessionId/finalize',
        body: const {},
        auth: true,
        timeoutSeconds: 30,
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return {
          'success': true,
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Could not end session',
      };
    } catch (e) {
      // Scoring might time out if GPT is slow — continue to report page anyway
      return {'success': true, 'timeout': true};
    }
  }

  // ── Get session history ─────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getSessionHistory() async {
    try {
      final res = await ApiService.get('/sessions', auth: true);
      final body = _decodeMap(res.body);
      debugPrint('[History] Raw response: status=${res.statusCode}, body=${body.toString().substring(0, min(body.toString().length, 500))}');
      if (res.statusCode == 200 &&
          body['success'] == true &&
          body['data'] is Map<String, dynamic>) {
        final sessions =
            (body['data']['sessions'] as List<dynamic>? ?? const []);
        debugPrint('[History] Found ${sessions.length} sessions (data.sessions format)');
        for (final s in sessions) {
          final m = s as Map<String, dynamic>;
          debugPrint('[History]   session id=${m['id']}, type=${m['session_type']}, status=${m['status']}, score=${m['overall_score']}');
        }
        return sessions.cast<Map<String, dynamic>>();
      }
      if (res.statusCode == 200 && body['sessions'] is List<dynamic>) {
        final sessions = body['sessions'] as List<dynamic>;
        debugPrint('[History] Found ${sessions.length} sessions (direct sessions format)');
        for (final s in sessions) {
          final m = s as Map<String, dynamic>;
          debugPrint('[History]   session id=${m['id']}, type=${m['session_type']}, status=${m['status']}, score=${m['overall_score']}');
        }
        return sessions.cast<Map<String, dynamic>>();
      }
      debugPrint('[History] Unexpected response format, returning empty list');
      return [];
    } catch (e) {
      debugPrint('[History] Error fetching history: $e');
      return [];
    }
  }

  // ── Generate overall feedback ──────────────────────────────────────
  static Future<Map<String, dynamic>> generateFeedback(int sessionId) async {
    try {
      // Ensure scoring/session closure is up to date before loading report.
      try {
        await ApiService.post('/sessions/$sessionId/finalize',
            timeoutSeconds: 30);
      } catch (_) {
        // Continue to report fetch even if finalize is slow/unavailable.
      }

      final res = await ApiService.get(
        '/sessions/$sessionId/report',
        auth: true,
      ).timeout(const Duration(seconds: 12));
      final body = _decodeMap(res.body);
      if (res.statusCode == 200) {
        return {
          'success': true,
          'feedback': _normalizeFeedbackReport(sessionId, body),
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Could not load feedback report',
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
      final res = await ApiService.get('/dashboard/progress', auth: true)
          .timeout(const Duration(seconds: 10));
      final body = _decodeMap(res.body);
      if (res.statusCode == 200) {
        debugPrint('[Metrics] Dashboard API response: total_practice_minutes=${body['total_practice_minutes']}, total_sessions=${body['total_sessions']}');
        return {'success': true, 'data': body};
      }
    } catch (_) {
      // API call failed — fall through to session history fallback
    }
    // Fallback: compute basic metrics from session history
    try {
      final history = await getSessionHistory();
      int totalSessions = history.length;
      double totalScore = 0;
      int completedWithScore = 0;
      double highestScore = 0;
      int totalMinutes = 0;

      for (var session in history) {
        final dur = session['duration'];
        debugPrint('[Metrics] Session id=${session['id']}, status=${session['status']}, duration=${dur}s, score=${session['overall_score']}');
        if (session['status'] == 'completed' &&
            session['overall_score'] != null) {
          final score = (session['overall_score'] as num).toDouble();
          totalScore += score;
          completedWithScore++;
          if (score > highestScore) highestScore = score;
        }
        if (dur != null) {
          totalMinutes += ((dur as num) / 60).round();
        }
      }
      debugPrint('[Metrics] Fallback computed: totalMinutes=$totalMinutes, totalSessions=$totalSessions');

      return {
        'success': true,
        'data': {
          'total_sessions': totalSessions,
          'avg_score': completedWithScore > 0
              ? (totalScore / completedWithScore).round()
              : 0,
          'best_score': highestScore.round(),
          'total_practice_minutes': totalMinutes,
          'performance_trend': [],
          'category_averages': {
            'voice_tone': 0,
            'facial_expression': 0,
            'content_quality': 0
          },
        }
      };
    } catch (_) {
      return {'success': false, 'message': 'Failed to load metrics'};
    }
  }

  static int _questionCountForLength(String lengthType) {
    switch (lengthType.toLowerCase()) {
      case 'quick':
        return 5;
      case 'full':
        return 15;
      case 'standard':
      default:
        return 10;
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchQuestionsForRole({
    required String jobPosition,
    required int desiredCount,
    List<Map<String, dynamic>> seedQuestions = const <Map<String, dynamic>>[],
    int? sessionId,
  }) async {
    if (seedQuestions.isNotEmpty) {
      final seeded = _normalizeQuestions(
        rawQuestions: seedQuestions,
        jobPosition: jobPosition,
        desiredCount: desiredCount,
      );
      if (seeded.isNotEmpty) return seeded;
    }

    try {
      final encodedRole = Uri.encodeQueryComponent(jobPosition);
      final response =
          await ApiService.get('/questions?role=$encodedRole', auth: false);
      final body = jsonDecode(response.body);
      final rawQuestions = body is List ? body : const <dynamic>[];
      final normalized = _normalizeQuestions(
        rawQuestions: rawQuestions,
        jobPosition: jobPosition,
        desiredCount: desiredCount,
      );
      if (normalized.isNotEmpty) {
        return normalized;
      }
    } catch (_) {}

    return _fallbackQuestions(
      jobPosition: jobPosition,
      desiredCount: desiredCount,
      sessionId: sessionId,
    );
  }

  static List<Map<String, dynamic>> _normalizeQuestions({
    required List<dynamic> rawQuestions,
    required String jobPosition,
    required int desiredCount,
  }) {
    final normalized = <Map<String, dynamic>>[];

    for (var i = 0; i < rawQuestions.length; i++) {
      final item = rawQuestions[i];
      if (item is! Map<String, dynamic>) continue;

      final text =
          (item['question_text'] ?? item['text'] ?? '').toString().trim();
      if (text.isEmpty) continue;

      normalized.add({
        'id': item['id'] ?? (i + 1),
        'text': text,
        'type': _normalizeQuestionType(
          item['type']?.toString() ?? item['question_type']?.toString(),
          index: i,
        ),
      });

      if (normalized.length >= desiredCount) {
        break;
      }
    }

    if (normalized.isEmpty) {
      return _fallbackQuestions(
          jobPosition: jobPosition, desiredCount: desiredCount);
    }

    return normalized;
  }

  static String _normalizeQuestionType(String? rawType, {required int index}) {
    final value = (rawType ?? '').trim().toLowerCase();
    if (value == 'technical') return 'technical';
    if (value == 'behavioral' || value == 'behavioural') return 'behavioral';
    if (value == 'situational') return 'situational';
    return _questionFlow[index % _questionFlow.length];
  }

  static List<Map<String, dynamic>> _fallbackQuestions({
    required String jobPosition,
    required int desiredCount,
    int? sessionId,
  }) {
    final role = jobPosition.trim().isEmpty ? 'this role' : jobPosition.trim();
    final firstQuestion = <String, dynamic>{
      'id': 1,
      'type': 'behavioral',
      'text':
          'Tell me about yourself and what prepared you for a $role position.',
    };

    final rotatingPool = <Map<String, dynamic>>[
      {
        'type': 'behavioral',
        'text':
            'Describe a time you solved a difficult problem while working with a team.',
      },
      {
        'type': 'technical',
        'text':
            'What core technical skills are most important for a $role, and how have you used them?',
      },
      {
        'type': 'technical',
        'text':
            'Walk me through a project where you applied tools or technologies relevant to $role.',
      },
      {
        'type': 'situational',
        'text':
            'If you were assigned a high-priority task in a new $role, how would you approach it?',
      },
      {
        'type': 'technical',
        'text':
            'How would you evaluate the quality of your work in a $role project before delivery?',
      },
      {
        'type': 'situational',
        'text':
            'How would you handle conflicting deadlines while working as a $role?',
      },
      {
        'type': 'behavioral',
        'text':
            'Tell me about a time you received tough feedback and how you improved afterward.',
      },
      {
        'type': 'technical',
        'text':
            'How would you debug a production issue in a $role project with limited information?',
      },
      {
        'type': 'situational',
        'text':
            'How would you prioritize tasks if your manager changed requirements mid-sprint?',
      },
    ];

    final random = Random(sessionId ?? DateTime.now().millisecondsSinceEpoch);
    final shuffled = List<Map<String, dynamic>>.from(rotatingPool)
      ..shuffle(random);
    final selected = <Map<String, dynamic>>[firstQuestion];

    for (final item in shuffled) {
      if (selected.length >= desiredCount) break;
      selected.add(item);
    }

    return selected.asMap().entries.map((entry) {
      return {
        'id': entry.key + 1,
        'type': entry.value['type'],
        'text': entry.value['text'],
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> _fetchSessionQuestions(
      int sessionId) async {
    try {
      final response =
          await ApiService.get('/sessions/$sessionId/questions', auth: true);
      final body = _decodeMap(response.body);
      if (response.statusCode == 200 && body['questions'] is List<dynamic>) {
        return (body['questions'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _normalizeFeedbackReport(
    int sessionId,
    Map<String, dynamic> body,
  ) {
    if (body.containsKey('overallScore') ||
        body.containsKey('questionEvaluations')) {
      return body;
    }

    final answers = (body['answers'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    // Collect strengths and suggestions from per-answer feedback text fields, deduplicated
    final strengths = <String>[];
    final improvements = <String>[];
    final seenStrengths = <String>{};
    final seenImprovements = <String>{};
    for (final answer in answers) {
      final fb = answer['feedback'] as Map<String, dynamic>?;
      if (fb != null) {
        final s = fb['strengths']?.toString().trim();
        if (s != null && s.isNotEmpty && seenStrengths.add(s)) {
          strengths.add(s);
        }
        final w = fb['suggestions']?.toString().trim();
        if (w != null && w.isNotEmpty && seenImprovements.add(w)) {
          improvements.add(w);
        }
      }
    }

    return {
      'interviewId': (body['id'] ?? sessionId).toString(),
      'overallScore': _toInt(body['overall_score']),
      'summary': {
        'voiceTone': _toInt(body['voice_tone_score']),
        'facialExpression': _toInt(body['facial_expression_score']),
        'contentQuality': _toInt(body['content_quality_score']),
      },
      'strengths': strengths,
      'improvements': improvements,
      'questionEvaluations': answers.asMap().entries.map((entry) {
        final item = entry.value;
        final fb = item['feedback'] as Map<String, dynamic>? ?? const {};
        final answerScore = item['score'] as Map<String, dynamic>?;
        return {
          'questionNumber': entry.key + 1,
          'question': item['question_text'] ?? item['question'] ?? '',
          'answer': item['answer_text'] ?? '',
          'score': _toInt(answerScore?['overall_score']),
          'feedback': (fb['suggestions'] ?? fb['weaknesses'] ?? '').toString(),
        };
      }).toList(),
    };
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

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
