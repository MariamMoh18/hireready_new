import 'ai_speech_handler.dart';

class _NoopAiSpeechHandler implements AiSpeechHandler {
  @override
  Future<void> speak(String text) async {
    // No-op on non-web platforms.
  }

  @override
  void stop() {}
}

AiSpeechHandler createAiSpeechHandlerImpl() => _NoopAiSpeechHandler();

