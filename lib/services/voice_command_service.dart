import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/voice_intent.dart';
import 'voice_intent_parser.dart';

class VoiceCommandService {
  VoiceCommandService({VoiceIntentParser? parser})
    : _parser = parser ?? VoiceIntentParser();

  final SpeechToText _speech = SpeechToText();
  final VoiceIntentParser _parser;
  final StreamController<VoiceCommand> _commandController =
      StreamController<VoiceCommand>.broadcast();
  final StreamController<bool> _listeningController =
      StreamController<bool>.broadcast();

  Timer? _restartTimer;
  bool _initialised = false;
  bool _shouldKeepListening = false;
  bool _starting = false;
  bool _disposed = false;
  int _generation = 0;
  String? _localeId;
  String _lastProcessedText = '';
  DateTime? _lastProcessedAt;

  Stream<VoiceCommand> get commands => _commandController.stream;
  Stream<bool> get listeningStatus => _listeningController.stream;
  bool get isListening => _speech.isListening;

  Future<bool> initialise() async {
    if (_initialised) return true;

    final bool available = await _speech.initialize(
      onStatus: _handleStatus,
      onError: (_) {
        _scheduleRestart();
      },
    );

    _initialised = available;
    return available;
  }

  Future<bool> start({String? localeId}) async {
    if (_disposed) return false;

    if (_shouldKeepListening) return true;
    final int generation = ++_generation;
    _localeId = localeId;
    _shouldKeepListening = true;

    final bool available = await initialise();
    if (_disposed || generation != _generation) return false;
    if (!available) {
      _shouldKeepListening = false;
      return false;
    }

    _listeningController.add(true);
    await _startListeningSession();
    return true;
  }

  Future<void> stop() async {
    ++_generation;
    _shouldKeepListening = false;
    _restartTimer?.cancel();
    if (_speech.isListening) await _speech.stop();
    if (!_disposed) _listeningController.add(false);
  }

  Future<void> cancel() async {
    ++_generation;
    _shouldKeepListening = false;
    _restartTimer?.cancel();
    if (_speech.isListening) await _speech.cancel();
    if (!_disposed) _listeningController.add(false);
  }

  Future<void> _startListeningSession() async {
    if (_disposed ||
        !_shouldKeepListening ||
        _starting ||
        _speech.isListening) {
      return;
    }

    _starting = true;
    try {
      await _speech.listen(
        onResult: _handleResult,
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: _localeId,
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.confirmation,
        ),
      );
      // Keep the UI enabled throughout the recogniser's short session gaps.
    } finally {
      _starting = false;
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    if (!result.finalResult) return;

    final String recognisedText = result.recognizedWords.trim();
    if (recognisedText.isEmpty || _isDuplicate(recognisedText)) return;

    _lastProcessedText = recognisedText;
    _lastProcessedAt = DateTime.now();

    final VoiceCommand command = _parser.parse(recognisedText);
    if (command.intent != VoiceIntent.none && !_disposed) {
      _commandController.add(command);
    }
  }

  bool _isDuplicate(String text) {
    if (_lastProcessedAt == null) return false;
    return text.toLowerCase() == _lastProcessedText.toLowerCase() &&
        DateTime.now().difference(_lastProcessedAt!) <
            const Duration(seconds: 2);
  }

  void _handleStatus(String status) {
    if (_disposed) return;
    if (status == 'done' || status == 'notListening') _scheduleRestart();
  }

  void _scheduleRestart() {
    if (_disposed || !_shouldKeepListening) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(
      const Duration(milliseconds: 1200),
      () => unawaited(_startListeningSession()),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _shouldKeepListening = false;
    _restartTimer?.cancel();
    if (_speech.isListening) await _speech.cancel();
    await _commandController.close();
    await _listeningController.close();
  }
}
