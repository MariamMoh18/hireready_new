import 'dart:typed_data';

import 'audio_stream_handler_stub.dart'
    if (dart.library.html) 'audio_stream_handler_web.dart'
    if (dart.library.io) 'audio_stream_handler_io.dart';

abstract class AudioStreamHandler {
  bool get isRecording;

  Future<void> start({
    required void Function(Uint8List chunk) onChunk,
    int chunkMilliseconds = 300,
  });

  Future<void> stop();

  void dispose();
}

AudioStreamHandler createAudioStreamHandler() => createAudioStreamHandlerImpl();
