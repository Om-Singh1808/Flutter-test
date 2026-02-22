/// pdf_upload_service.dart
/// Handles multipart PDF upload to the FastAPI backend.
library;

import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// ── Backend config ────────────────────────────────────────────────────────────
/// Emulator default — will not work on physical devices.
/// Override via Settings → Backend Host in the app.
const String _kDefaultBase = 'http://10.0.2.2:8000';

/// Builds the backend base URL.
///
/// Priority:
///   1. 'backendHost' pref — if it starts with http/https treat as full base URL.
///                        — otherwise wrap as http://<host>:8000.
///   2. 'mqttHost' pref  — wrapped as http://<host>:8000.
///   3. Emulator default.
Future<String> _getBaseUrl() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('backendHost');
  if (raw != null && raw.isNotEmpty) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw.trimRight().replaceAll(RegExp(r'/$'), '');
    }
    return 'http://$raw:8000';
  }
  final mqttHost = prefs.getString('mqttHost');
  if (mqttHost != null && mqttHost.isNotEmpty) {
    return 'http://$mqttHost:8000';
  }
  return _kDefaultBase;
}

/// Result returned from a successful upload.
class PdfUploadResult {
  final String documentId;
  final int chunksStored;

  const PdfUploadResult({required this.documentId, required this.chunksStored});
}

/// Sends a PDF file to [POST /upload_pdf] as multipart/form-data.
///
/// Throws a [PdfUploadException] with a human-readable message on any failure.
Future<PdfUploadResult> uploadPdf(String filePath) async {
  final file = File(filePath);
  if (!file.existsSync()) {
    throw PdfUploadException('File not found at path: $filePath');
  }

  final baseUrl = await _getBaseUrl();
  final uri = Uri.parse('$baseUrl/upload_pdf');
  final request = http.MultipartRequest('POST', uri);

  // Field name must match FastAPI's `file: UploadFile = File(...)`
  request.files.add(
    await http.MultipartFile.fromPath(
      'file',
      filePath,
      // Explicitly set PDF content type
    ),
  );

  http.StreamedResponse streamedResponse;
  try {
    streamedResponse = await request.send().timeout(
      const Duration(seconds: 120), // large PDFs may take time to process
    );
  } on SocketException {
    throw PdfUploadException(
      'Could not reach the server at $baseUrl.\n'
      'Ensure the backend is running and the host/port are correct.\n'
      'Go to Settings → Backend Host to update the IP for your device.',
    );
  } catch (e) {
    throw PdfUploadException('Network error: $e');
  }

  final body = await streamedResponse.stream.bytesToString();

  if (streamedResponse.statusCode != 200) {
    String detail = 'Unknown error';
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      detail = json['detail']?.toString() ?? detail;
    } catch (_) {}
    throw PdfUploadException(
      'Server returned ${streamedResponse.statusCode}: $detail',
    );
  }

  final json = jsonDecode(body) as Map<String, dynamic>;
  return PdfUploadResult(
    documentId: json['document_id'] as String,
    chunksStored: json['chunks_stored'] as int,
  );
}

/// Typed exception for upload failures.
class PdfUploadException implements Exception {
  final String message;
  const PdfUploadException(this.message);

  @override
  String toString() => 'PdfUploadException: $message';
}
