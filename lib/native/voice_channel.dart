/// Voice capability — provides tools for text-to-speech and
/// speech-to-text transcription.
///
/// Channel: none (pure-Dart via `flutter_tts` + `speech_to_text`)
/// Kotlin handler: none
///
/// Tools:
/// - `voice_speak` — Speak text aloud using text-to-speech
/// - `voice_listen` — Listen for speech and transcribe to text
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Handles voice input (speech-to-text) and output (text-to-speech).
/// Uses pure-Dart packages — no Kotlin MethodChannel needed.
class VoiceChannel {
  static final FlutterTts _tts = FlutterTts();
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static bool _ttsInitialized = false;
  static bool _speechInitialized = false;

  VoiceChannel._();

  static Future<void> _ensureTtsInitialized() async {
    if (_ttsInitialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ttsInitialized = true;
  }

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[VoiceChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'voice_speak':
        return _speak(params);
      case 'voice_listen':
        return _listen(params);
      default:
        throw Exception('Unknown voice tool: $toolName');
    }
  }

  /// Speak text aloud using text-to-speech.
  static Future<String> _speak(Map<String, dynamic> params) async {
    await _ensureTtsInitialized();

    final text = params['text'] as String? ?? '';
    if (text.isEmpty) {
      return jsonEncode({'error': 'text is required'});
    }

    final language = params['language'] as String? ?? 'en-US';
    final rate = (params['rate'] as num?)?.toDouble() ?? 0.5;

    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    await _tts.speak(text);

    return jsonEncode({
      'spoken': true,
      'text': text,
      'language': language,
    });
  }

  /// Listen for speech and transcribe to text.
  static Future<String> _listen(Map<String, dynamic> params) async {
    if (!_speechInitialized) {
      _speechInitialized = await _speech.initialize();
    }

    if (!_speechInitialized) {
      return jsonEncode({
        'error': 'Speech recognition not available on this device',
      });
    }

    final language = params['language'] as String? ?? 'en-US';
    final durationSeconds = params['duration_seconds'] as int? ?? 10;

    String finalResult = '';
    bool done = false;

    _speech.listen(
      onResult: (result) {
        finalResult = result.recognizedWords;
        if (result.finalResult) {
          done = true;
        }
      },
      listenFor: Duration(seconds: durationSeconds),
      localeId: language,
    );

    // Wait for final result or timeout
    final deadline =
        DateTime.now().add(Duration(seconds: durationSeconds + 2));
    while (!done && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    return jsonEncode({
      'text': finalResult,
      'language': language,
      'final': done,
    });
  }
}
