import 'ai_speech_handler_stub.dart'
    if (dart.library.html) 'ai_speech_handler_web.dart';

/// Plays AI interview questions automatically (web speech synthesis).
///
/// For non-web platforms this is a no-op so the rest of the interview flow
/// still works end-to-end with REST.
abstract class AiSpeechHandler {
  Future<void> speak(String text);
  void stop();
}

AiSpeechHandler createAiSpeechHandler() => createAiSpeechHandlerImpl();

