import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart';

class RealtimeInterviewEvent {
  final String type;
  final String? text;
  final String? audioUrl;
  final Uint8List? audioBytes;
  final Map<String, dynamic> raw;

  const RealtimeInterviewEvent({
    required this.type,
    this.text,
    this.audioUrl,
    this.audioBytes,
    required this.raw,
  });
}

class RealtimeInterviewSocketService {
  static const String _configuredWsUrl = String.fromEnvironment(
    'INTERVIEW_WS_URL',
    defaultValue: '',
  );

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StreamController<RealtimeInterviewEvent> _eventsController =
      StreamController<RealtimeInterviewEvent>.broadcast();

  bool get isConnected => _channel != null;
  Stream<RealtimeInterviewEvent> get events => _eventsController.stream;

  Future<void> connect({
    required int sessionId,
    required String? token,
  }) async {
    if (_channel != null) return;

    final wsUri = _buildWsUri(sessionId: sessionId, token: token);
    _channel = WebSocketChannel.connect(wsUri);

    _subscription = _channel!.stream.listen(
      _handleSocketMessage,
      onError: (error) {
        _eventsController.add(
          RealtimeInterviewEvent(
            type: 'error',
            text: error.toString(),
            raw: {'error': error.toString()},
          ),
        );
      },
      onDone: () {
        _eventsController.add(
          const RealtimeInterviewEvent(
            type: 'closed',
            raw: {'message': 'Socket closed'},
          ),
        );
      },
    );
  }

  void sendStartRecording() {
    _sendJson({'type': 'start_recording'});
  }

  void sendStopRecording() {
    _sendJson({'type': 'stop_recording'});
  }

  void sendEndCall() {
    _sendJson({'type': 'end_call'});
  }

  void sendAudioChunk(Uint8List audioChunk) {
    _sendJson({
      'type': 'user_audio',
      'audio_chunk': base64Encode(audioChunk),
    });
  }

  void _sendJson(Map<String, dynamic> data) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode(data));
  }

  void _handleSocketMessage(dynamic payload) {
    try {
      final decoded = payload is String
          ? jsonDecode(payload) as Map<String, dynamic>
          : <String, dynamic>{};

      final type = (decoded['type'] ?? '').toString();
      final text = decoded['text']?.toString();
      final audioUrl = decoded['audio_url']?.toString();
      final audioBase64 = decoded['audio_base64']?.toString();

      _eventsController.add(
        RealtimeInterviewEvent(
          type: type.isEmpty ? 'message' : type,
          text: text,
          audioUrl: audioUrl,
          audioBytes: audioBase64 != null && audioBase64.isNotEmpty
              ? base64Decode(audioBase64)
              : null,
          raw: decoded,
        ),
      );
    } catch (_) {
      _eventsController.add(
        RealtimeInterviewEvent(
          type: 'message',
          text: payload.toString(),
          raw: {'raw': payload.toString()},
        ),
      );
    }
  }

  Uri _buildWsUri({
    required int sessionId,
    required String? token,
  }) {
    if (_configuredWsUrl.isNotEmpty) {
      final uri = Uri.parse(_configuredWsUrl);
      return uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          'session_id': '$sessionId',
          if (token != null && token.isNotEmpty) 'token': token,
        },
      );
    }

    final apiUri = Uri.parse(ApiService.baseUrl);
    final wsScheme = apiUri.scheme == 'https' ? 'wss' : 'ws';

    return Uri(
      scheme: wsScheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
      path: '/ws/interview',
      queryParameters: {
        'session_id': '$sessionId',
        if (token != null && token.isNotEmpty) 'token': token,
      },
    );
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _eventsController.close();
  }
}
