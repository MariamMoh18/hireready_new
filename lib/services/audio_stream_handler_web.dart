import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'audio_stream_handler.dart';

class _WebAudioStreamHandler implements AudioStreamHandler {
  html.MediaRecorder? _recorder;
  html.MediaStream? _mediaStream;
  void Function(html.Event)? _dataListener;
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> start({
    required void Function(Uint8List chunk) onChunk,
    int chunkMilliseconds = 300,
  }) async {
    if (_isRecording) return;

    _mediaStream = await html.window.navigator.mediaDevices!
        .getUserMedia({'audio': true, 'video': false});
    _recorder = html.MediaRecorder(
      _mediaStream!,
      {'mimeType': 'audio/webm;codecs=opus'},
    );

    _dataListener = (html.Event event) async {
      if (event is! html.BlobEvent) return;
      final blob = event.data;
      if (blob == null || blob.size <= 0) return;
      final bytes = await _blobToBytes(blob);
      if (bytes.isNotEmpty) {
        onChunk(bytes);
      }
    };
    _recorder!.addEventListener('dataavailable', _dataListener);

    _recorder!.start(chunkMilliseconds);
    _isRecording = true;
  }

  @override
  Future<void> stop() async {
    if (!_isRecording) return;
    _isRecording = false;

    _recorder?.stop();
    if (_dataListener != null) {
      _recorder?.removeEventListener('dataavailable', _dataListener);
      _dataListener = null;
    }
    _recorder = null;

    _mediaStream?.getTracks().forEach((track) => track.stop());
    _mediaStream = null;
  }

  @override
  void dispose() {
    unawaited(stop());
  }

  Future<Uint8List> _blobToBytes(html.Blob blob) {
    final completer = Completer<Uint8List>();
    final reader = html.FileReader();

    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
        return;
      }
      completer.complete(Uint8List(0));
    });
    reader.onError.listen((_) => completer.complete(Uint8List(0)));

    reader.readAsArrayBuffer(blob);
    return completer.future;
  }
}

AudioStreamHandler createAudioStreamHandlerImpl() => _WebAudioStreamHandler();
