import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Formats recognized speech text into the standard voice command JSON payload.
Map<String, dynamic> formatVoiceCommandJson(String text) {
  return {
    'type': 'voice_command',
    'text': text,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'device': 'flutter_app',
  };
}

/// Serializes the voice command map to a pretty-printed JSON string.
String encodeVoiceCommandJson(Map<String, dynamic> payload) {
  return const JsonEncoder.withIndent('  ').convert(payload);
}

/// Service that manages speech recognition lifecycle.
///
/// Usage:
/// ```dart
/// final service = VoiceService();
/// await service.initialize();
/// await service.startListening(onResult: (text) { ... });
/// await service.stopListening();
/// ```
class VoiceService {
  final SpeechToText _speech = SpeechToText();

  bool _initialized = false;
  bool _listening = false;

  /// Whether the service has been successfully initialized.
  bool get isInitialized => _initialized;

  /// Whether the microphone is currently capturing speech.
  bool get isListening => _listening;

  // ─── Initialization ────────────────────────────────────────────────────────

  /// Requests microphone permission and initializes the speech engine.
  ///
  /// Returns `true` if initialization succeeded, `false` otherwise.
  Future<bool> initialize() async {
    final permissionStatus = await _requestMicrophonePermission();
    if (!permissionStatus) {
      debugPrint('[VoiceService] Microphone permission denied.');
      return false;
    }

    _initialized = await _initSpeechEngine();
    return _initialized;
  }

  /// Requests the RECORD_AUDIO runtime permission.
  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  /// Initializes the underlying SpeechToText engine.
  Future<bool> _initSpeechEngine() async {
    try {
      final available = await _speech.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
        debugLogging: false,
      );
      if (!available) {
        debugPrint('[VoiceService] Speech recognition not available on device.');
      }
      return available;
    } catch (e) {
      debugPrint('[VoiceService] Initialization error: $e');
      return false;
    }
  }

  // ─── Listening Control ─────────────────────────────────────────────────────

  /// Starts listening to microphone input.
  ///
  /// [onResult] is called with the recognized text whenever a result arrives.
  /// [onListeningStateChanged] is called when the listening state changes.
  Future<void> startListening({
    required void Function(String text) onResult,
    void Function(bool isListening)? onListeningStateChanged,
  }) async {
    if (!_initialized) {
      debugPrint('[VoiceService] Not initialized. Call initialize() first.');
      return;
    }
    if (_listening) return;

    await _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords.trim();
        if (text.isNotEmpty) {
          onResult(text);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );

    _listening = true;
    onListeningStateChanged?.call(true);
    debugPrint('[VoiceService] Listening started.');
  }

  /// Stops the active listening session.
  Future<void> stopListening({
    void Function(bool isListening)? onListeningStateChanged,
  }) async {
    if (!_listening) return;
    await _speech.stop();
    _listening = false;
    onListeningStateChanged?.call(false);
    debugPrint('[VoiceService] Listening stopped.');
  }

  // ─── Internal Callbacks ────────────────────────────────────────────────────

  void _onSpeechError(dynamic error) {
    debugPrint('[VoiceService] Speech error: $error');
    _listening = false;
  }

  void _onSpeechStatus(String status) {
    debugPrint('[VoiceService] Speech status: $status');
    if (status == 'done' || status == 'notListening') {
      _listening = false;
    }
  }

  // ─── Cleanup ───────────────────────────────────────────────────────────────

  /// Releases speech recognition resources.
  Future<void> dispose() async {
    await _speech.cancel();
    _listening = false;
    _initialized = false;
  }
}
