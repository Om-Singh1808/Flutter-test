/// pdf_upload_screen.dart
/// UI screen for picking and uploading PDFs to the memory backend.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/pdf_upload_service.dart';

class PdfUploadScreen extends StatefulWidget {
  const PdfUploadScreen({super.key});

  @override
  State<PdfUploadScreen> createState() => _PdfUploadScreenState();
}

class _PdfUploadScreenState extends State<PdfUploadScreen> {
  // ── State ────────────────────────────────────────────────────────────────
  String? _selectedFilePath;
  String? _selectedFileName;
  bool _uploading = false;
  PdfUploadResult? _lastResult;
  String? _lastError;

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Opens the native file picker filtered to PDFs.
  Future<void> _pickPdf() async {
    setState(() {
      _lastResult = null;
      _lastError = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    if (picked.path == null) {
      _showError('Could not access the selected file path.');
      return;
    }

    setState(() {
      _selectedFilePath = picked.path;
      _selectedFileName = picked.name;
    });
  }

  /// Uploads the selected PDF to the backend.
  Future<void> _upload() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _uploading = true;
      _lastResult = null;
      _lastError = null;
    });

    try {
      final result = await uploadPdf(_selectedFilePath!);
      setState(() {
        _lastResult = result;
        _selectedFilePath = null;
        _selectedFileName = null;
      });
    } on PdfUploadException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Unexpected error: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  void _showError(String message) {
    setState(() => _lastError = message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Memory',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ───────────────────────────────────────────────────
              _buildHeader(cs, tt),
              const SizedBox(height: 32),

              // ── Pick PDF card ─────────────────────────────────────────────
              _buildPickCard(cs, tt),
              const SizedBox(height: 16),

              // ── Upload button ─────────────────────────────────────────────
              _buildUploadButton(cs),
              const SizedBox(height: 32),

              // ── Result / status ───────────────────────────────────────────
              if (_lastResult != null) _buildSuccessCard(cs, tt),
              if (_lastError != null && _lastResult == null) _buildErrorCard(cs, tt),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.psychology_rounded, color: cs.primary, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          'PDF Memory',
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 6),
        Text(
          'Upload a PDF to store its content as semantic memory. '
          'The AI can reference it in future sessions.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildPickCard(ColorScheme cs, TextTheme tt) {
    final hasFile = _selectedFileName != null;

    return GestureDetector(
      onTap: _uploading ? null : _pickPdf,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hasFile
              ? cs.primary.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasFile ? cs.primary.withValues(alpha: 0.4) : cs.outline.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                hasFile ? Icons.picture_as_pdf_rounded : Icons.upload_file_rounded,
                color: cs.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile ? _selectedFileName! : 'Tap to select a PDF',
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: hasFile ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!hasFile) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Supports .pdf files',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            if (hasFile)
              IconButton(
                icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant, size: 20),
                onPressed: _uploading
                    ? null
                    : () => setState(() {
                          _selectedFilePath = null;
                          _selectedFileName = null;
                        }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton(ColorScheme cs) {
    final canUpload = _selectedFilePath != null && !_uploading;

    return FilledButton.icon(
      onPressed: canUpload ? _upload : null,
      icon: _uploading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
            )
          : const Icon(Icons.cloud_upload_rounded),
      label: Text(_uploading ? 'Uploading…' : 'Upload to Memory'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSuccessCard(ColorScheme cs, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2E5C2E), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF5CCC5C), size: 20),
              const SizedBox(width: 8),
              Text(
                'Stored Successfully',
                style: tt.titleSmall?.copyWith(
                  color: const Color(0xFF5CCC5C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            label: 'Document ID',
            value: _lastResult!.documentId,
            mono: true,
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            label: 'Chunks stored',
            value: '${_lastResult!.chunksStored}',
            cs: cs,
            tt: tt,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(ColorScheme cs, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.error.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _lastError!,
              style: tt.bodySmall?.copyWith(color: cs.error, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required ColorScheme cs,
    required TextTheme tt,
    bool mono = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: (mono
                    ? tt.bodySmall?.copyWith(fontFamily: 'monospace')
                    : tt.bodySmall)
                ?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
