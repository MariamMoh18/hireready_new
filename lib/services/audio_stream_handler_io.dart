import 'dart:async';
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'audio_stream_handler.dart';

class _IoAudioStreamHandler implements AudioStreamHandler {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> start({
    required void Function(Uint8List chunk) onChunk,
    int chunkMilliseconds = 300,
  }) async {
    if (_isRecording) return;

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      throw StateError('Microphone permission is not granted.');
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw StateError('Recorder permission check failed.');
    }

    // Stream raw audio chunks from the microphone. The InterviewSessionPage
    // buffers these bytes and uploads them at "Stop Recording".
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _sub?.cancel();
    _sub = stream.listen(
      (chunk) {
        if (chunk.isNotEmpty) onChunk(chunk);
      },
      onError: (Object e, StackTrace _) {
        // Surface the error by stopping recording; UI will show snackbars from caller.
        unawaited(stop());
      },
      cancelOnError: true,
    );

    _isRecording = true;
  }

  @override
  Future<void> stop() async {
    if (!_isRecording) return;
    _isRecording = false;

    await _sub?.cancel();
    _sub = null;

    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  @override
  void dispose() {
    unawaited(stop());
    _recorder.dispose();
  }
}

AudioStreamHandler createAudioStreamHandlerImpl() => _IoAudioStreamHandler();

