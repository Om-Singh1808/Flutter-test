/// document_upload_service.dart
/// Handles multipart document upload (PDF / DOCX / PPTX) to the FastAPI backend.
library;

import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// ── Backend config ────────────────────────────────────────────────────────────
// Default to 10.0.2.2 (Android Emulator) if nothing is found in SharedPreferences.
const String _kDefaultHost = '10.0.2.2';
const int _kBackendPort = 8000;

Future<String> _getBaseUrl() async {
  final prefs = await SharedPreferences.getInstance();
  final host = prefs.getString('mqttHost') ?? _kDefaultHost;
  return 'http://$host:$_kBackendPort';
}

/// Supported document extensions.
const Set<String> kSupportedExtensions = {'.pdf', '.docx', '.pptx'};

// ── Result type ───────────────────────────────────────────────────────────────

/// Result returned from a successful document upload.
class DocumentUploadResult {
  final String documentId;
  final int chunksStored;
  final String fileName;

  const DocumentUploadResult({
    required this.documentId,
    required this.chunksStored,
    required this.fileName,
  });
}

// ── Upload function ───────────────────────────────────────────────────────────

/// Sends a document file to [POST /upload_document] as multipart/form-data.
///
/// Accepted file types: .pdf, .docx, .pptx
/// Throws a [DocumentUploadException] with a human-readable message on failure.
Future<DocumentUploadResult> uploadDocument(String filePath) async {
  final file = File(filePath);
  if (!file.existsSync()) {
    throw DocumentUploadException('File not found at path: $filePath');
  }

  final ext = _extensionOf(filePath).toLowerCase();
  if (!kSupportedExtensions.contains(ext)) {
    throw DocumentUploadException(
      'Unsupported file type "$ext". Supported: .pdf, .docx, .pptx',
    );
  }

  final baseUrl = await _getBaseUrl();
  final fileName = filePath.split(RegExp(r'[/\\]')).last;
  final uri = Uri.parse('$baseUrl/upload_document');
  final request = http.MultipartRequest('POST', uri);

  // Field name matches FastAPI's `file: UploadFile = File(...)`
  request.files.add(await http.MultipartFile.fromPath('file', filePath));

  http.StreamedResponse streamedResponse;
  try {
    streamedResponse = await request.send().timeout(
      const Duration(seconds: 180),
    );
  } on SocketException {
    throw DocumentUploadException(
      'Could not reach server at $baseUrl.\n'
      'Ensure the backend is running and the host/port are correct.',
    );
  } catch (e) {
    throw DocumentUploadException('Network error: $e');
  }

  final body = await streamedResponse.stream.bytesToString();

  if (streamedResponse.statusCode != 200) {
    String detail = 'Unknown error';
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      detail = json['detail']?.toString() ?? detail;
    } catch (_) {}
    throw DocumentUploadException(
      'Server returned ${streamedResponse.statusCode}: $detail',
    );
  }

  final json = jsonDecode(body) as Map<String, dynamic>;
  return DocumentUploadResult(
    documentId: json['document_id'] as String,
    chunksStored: json['chunks_stored'] as int,
    fileName: fileName,
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Extracts the lowercase extension (with dot) from a file path.
String _extensionOf(String filePath) {
  final dot = filePath.lastIndexOf('.');
  if (dot == -1) return '';
  return filePath.substring(dot);
}

// ── Exception type ────────────────────────────────────────────────────────────

/// Typed exception for document upload failures.
class DocumentUploadException implements Exception {
  final String message;
  const DocumentUploadException(this.message);

  @override
  String toString() => 'DocumentUploadException: $message';
}
