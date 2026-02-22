/// document_upload_button.dart
/// Animated document upload button widget — mirrors MicButton's visual design.
library;

import 'package:flutter/material.dart';
import '../screens/document_upload_screen.dart';

/// A reusable animated document upload button.
///
/// On tap, navigates to [DocumentUploadScreen]. While uploading,
/// a pulse-ring animation plays around the button.
///
/// Example:
/// ```dart
/// DocumentUploadButton(
///   onResult: (result) => debugPrint(result.documentId),
/// )
/// ```
class DocumentUploadButton extends StatefulWidget {
  /// Optional callback invoked with upload result after a successful upload.
  final void Function(String documentId, int chunksStored)? onResult;

  const DocumentUploadButton({super.key, this.onResult});

  @override
  State<DocumentUploadButton> createState() => _DocumentUploadButtonState();
}

class _DocumentUploadButtonState extends State<DocumentUploadButton>
    with SingleTickerProviderStateMixin {
  bool _isUploading = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _setupPulseAnimation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Animation ──────────────────────────────────────────────────────────────

  void _setupPulseAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _openUploadScreen() async {
    setState(() {
      _isUploading = true;
    });
    _pulseController.repeat(reverse: true);

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DocumentUploadScreen()),
    );

    if (mounted) {
      setState(() => _isUploading = false);
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = const Color(0xFF5B9CF6); // soft blue for document
    final idleColor = cs.primary; // gold from theme

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPulsingButton(activeColor, idleColor),
        const SizedBox(height: 10),
        _buildStatusLabel(cs),
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
            if (_isUploading)
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF5B9CF6).withValues(alpha: 0.18),
                  ),
                ),
              ),
            child!,
          ],
        );
      },
      child: _buildMainButton(activeColor, idleColor),
    );
  }

  Widget _buildMainButton(Color activeColor, Color idleColor) {
    final buttonColor = _isUploading ? activeColor : idleColor;

    return GestureDetector(
      onTap: _isUploading ? null : _openUploadScreen,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: buttonColor.withValues(alpha: 0.15),
          border: Border.all(color: buttonColor, width: 2),
          boxShadow: _isUploading
              ? [
                  BoxShadow(
                    color: const Color(0xFF5B9CF6).withValues(alpha: 0.32),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: _isUploading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: buttonColor,
                ),
              )
            : Icon(Icons.folder_open_rounded, color: buttonColor, size: 28),
      ),
    );
  }

  Widget _buildStatusLabel(ColorScheme cs) {
    final label = _isUploading ? 'Open…' : 'Documents';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        label,
        key: ValueKey(label),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _isUploading ? const Color(0xFF5B9CF6) : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
