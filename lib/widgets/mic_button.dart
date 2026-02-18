import 'package:flutter/material.dart';
import '../services/voice_service.dart';

/// A reusable animated microphone button widget.
///
/// Manages its own [VoiceService] instance. On tap it toggles listening.
/// When a final result is available, [onJsonResult] is called with the
/// structured voice-command JSON map.
///
/// Example:
/// ```dart
/// MicButton(
///   onJsonResult: (json) => debugPrint(jsonEncode(json)),
/// )
/// ```
class MicButton extends StatefulWidget {
  /// Called with the formatted JSON payload when speech is recognized.
  final void Function(Map<String, dynamic> json) onJsonResult;

  const MicButton({super.key, required this.onJsonResult});

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  final VoiceService _voiceService = VoiceService();

  bool _isListening = false;
  bool _isInitialized = false;
  String _statusLabel = 'Tap to speak';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _setupPulseAnimation();
    _initVoiceService();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  // ─── Animation Setup ───────────────────────────────────────────────────────

  void _setupPulseAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  // ─── Voice Service Init ────────────────────────────────────────────────────

  Future<void> _initVoiceService() async {
    final success = await _voiceService.initialize();
    if (mounted) {
      setState(() {
        _isInitialized = success;
        _statusLabel = success ? 'Tap to speak' : 'Mic unavailable';
      });
    }
  }

  // ─── Toggle Listening ──────────────────────────────────────────────────────

  Future<void> _toggleListening() async {
    if (!_isInitialized) {
      _showUnavailableSnackbar();
      return;
    }

    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    await _voiceService.startListening(
      onResult: _onSpeechResult,
      onListeningStateChanged: _onListeningStateChanged,
    );
    if (mounted) {
      setState(() {
        _isListening = true;
        _statusLabel = 'Listening…';
      });
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _stopListening() async {
    await _voiceService.stopListening(
      onListeningStateChanged: _onListeningStateChanged,
    );
    if (mounted) {
      setState(() {
        _isListening = false;
        _statusLabel = 'Tap to speak';
      });
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  // ─── Callbacks ─────────────────────────────────────────────────────────────

  void _onSpeechResult(String text) {
    final payload = formatVoiceCommandJson(text);
    debugPrint('[MicButton] JSON output:\n${encodeVoiceCommandJson(payload)}');
    widget.onJsonResult(payload);
  }

  void _onListeningStateChanged(bool isListening) {
    if (!mounted) return;
    setState(() {
      _isListening = isListening;
      _statusLabel = isListening ? 'Listening…' : 'Tap to speak';
    });
    if (!isListening) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  // ─── UI Helpers ────────────────────────────────────────────────────────────

  void _showUnavailableSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Microphone not available. Check permissions.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = const Color(0xFFFF4D4D);
    final idleColor = colorScheme.primary; // gold

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPulsingButton(activeColor, idleColor),
        const SizedBox(height: 10),
        _buildStatusLabel(colorScheme),
      ],
    );
  }

  Widget _buildPulsingButton(Color activeColor, Color idleColor) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing outer ring (visible only when listening)
            if (_isListening)
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activeColor.withValues(alpha: 0.20),
                  ),
                ),
              ),
            // Main button
            child!,
          ],
        );
      },
      child: _buildMainButton(activeColor, idleColor),
    );
  }

  Widget _buildMainButton(Color activeColor, Color idleColor) {
    final buttonColor = _isListening ? activeColor : idleColor;

    return GestureDetector(
      onTap: _toggleListening,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: buttonColor.withValues(alpha: 0.15),
          border: Border.all(color: buttonColor, width: 2),
          boxShadow: _isListening
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Icon(
          _isListening ? Icons.stop_rounded : Icons.mic_rounded,
          color: buttonColor,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildStatusLabel(ColorScheme colorScheme) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        _statusLabel,
        key: ValueKey(_statusLabel),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _isListening
              ? const Color(0xFFFF4D4D)
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
