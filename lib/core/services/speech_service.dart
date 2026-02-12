import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;

  Future<bool> init() async {
    if (_isInitialized) return true;

    // Request permission explicitly if needed (though initialize often handles it)
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint("Microphone permission denied");
        return false;
      }
    }

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) => debugPrint("Speech error: $error"),
        onStatus: (status) => debugPrint("Speech status: $status"),
      );
    } catch (e) {
      debugPrint("Speech init exception: $e");
      _isInitialized = false;
    }

    return _isInitialized;
  }

  Future<void> listen(Function(String) onResult) async {
    if (!_isInitialized) {
      bool initialized = await init();
      if (!initialized) return;
    }

    if (_speechToText.isNotListening) {
      await _speechToText.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        listenMode: ListenMode.dictation,
        localeId: "es_ES", // Default to Spanish, or make it dynamic
      );
    }
  }

  Future<void> stop() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }

  bool get isListening => _speechToText.isListening;
}
