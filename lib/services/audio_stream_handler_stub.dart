import 'dart:typed_data';

import 'audio_stream_handler.dart';

class _UnsupportedAudioStreamHandler implements AudioStreamHandler {
  @override
  bool get isRecording => false;

  @override
  Future<void> start({
    required void Function(Uint8List chunk) onChunk,
    int chunkMilliseconds = 300,
  }) {
    throw UnsupportedError(
      'Microphone streaming is not supported on this platform build.',
    );
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

AudioStreamHandler createAudioStreamHandlerImpl() =>
    _UnsupportedAudioStreamHandler();
