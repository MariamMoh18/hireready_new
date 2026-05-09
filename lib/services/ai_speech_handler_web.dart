import 'dart:async';
import 'dart:html' as html;

import 'ai_speech_handler.dart';

class _WebAiSpeechHandler implements AiSpeechHandler {
  html.SpeechSynthesisUtterance? _utterance;
  final html.SpeechSynthesis _synthesis = html.window.speechSynthesis!;
  Completer<void>? _currentCompleter;

  @override
  Future<void> speak(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Future.value();

    // Cancel any existing speech before starting a new one.
    stop();

    final completer = Completer<void>();
    _currentCompleter = completer;
    _utterance = html.SpeechSynthesisUtterance(trimmed);
    _utterance!.lang = 'en-US';

    _utterance!.onEnd.listen((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    _utterance!.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    _synthesis.speak(_utterance!);
    return completer.future;
  }

  @override
  void stop() {
    _utterance = null;
    _synthesis.cancel();
    if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
      _currentCompleter!.complete();
    }
    _currentCompleter = null;
  }
}

AiSpeechHandler createAiSpeechHandlerImpl() => _WebAiSpeechHandler();

