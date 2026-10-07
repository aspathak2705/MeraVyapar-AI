import 'dart:convert';
import 'dart:io';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/evidence_file_storage.dart';
import '../domain/evidence_storage_exception.dart';
import '../domain/stored_evidence_metadata.dart';

/// Production implementation of app-private mobile evidence storage.
///
/// Physical layout:
/// `<app-private-root>/evidence/<merchant-id>/<evidence-id>/original`
/// `<app-private-root>/evidence/<merchant-id>/<evidence-id>/metadata.json`
class AppPrivateEvidenceStorage implements EvidenceFileStorage {
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  // Magic bytes:
  // JPEG: FF D8 FF
  // PNG:  89 50 4E 47 0D 0A 1A 0A
  // PDF:  25 50 44 46 2D (%PDF-)
  static const List<int> _jpegHeader = [0xFF, 0xD8, 0xFF];
  static const List<int> _pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  static const List<int> _pdfHeader = [0x25, 0x50, 0x44, 0x46, 0x2D];

  final Future<Directory> Function() _rootDirProvider;

  AppPrivateEvidenceStorage({
    Future<Directory> Function()? rootDirProvider,
  }) : _rootDirProvider = rootDirProvider ?? _defaultRootProvider;

  static Future<Directory> _defaultRootProvider() async {
    return await getApplicationDocumentsDirectory();
  }

  void _validateIdentifier(String id, String fieldName) {
    if (!_uuidRegex.hasMatch(id.trim())) {
      throw EvidenceStoragePathException(
        'Invalid $fieldName format: must be valid UUID string',
      );
    }
    if (id.contains('/') || id.contains('\\') || id.contains('..')) {
      throw EvidenceStoragePathException(
        'Security violation: $fieldName contains illegal path traversal characters',
      );
    }
  }

  Future<Directory> _getEvidenceDir(String merchantId, String evidenceId) async {
    _validateIdentifier(merchantId, 'merchantId');
    _validateIdentifier(evidenceId, 'evidenceId');

    final root = await _rootDirProvider();
    final targetPath = p.normalize(
      p.join(root.path, 'evidence', merchantId.trim(), evidenceId.trim()),
    );

    // Root breakout defense
    final rootNormalized = p.normalize(root.path);
    if (!targetPath.startsWith(rootNormalized)) {
      throw const EvidenceStoragePathException(
        'Resolved path escapes application storage root',
      );
    }

    return Directory(targetPath);
  }

  String _detectContentType(List<int> header) {
    if (header.length >= 3 &&
        header[0] == _jpegHeader[0] &&
        header[1] == _jpegHeader[1] &&
        header[2] == _jpegHeader[2]) {
      return 'image/jpeg';
    }
    if (header.length >= 8) {
      bool isPng = true;
      for (int i = 0; i < 8; i++) {
        if (header[i] != _pngHeader[i]) {
          isPng = false;
          break;
        }
      }
      if (isPng) return 'image/png';
    }
    if (header.length >= 5) {
      bool isPdf = true;
      for (int i = 0; i < 5; i++) {
        if (header[i] != _pdfHeader[i]) {
          isPdf = false;
          break;
        }
      }
      if (isPdf) return 'application/pdf';
    }
    throw const EvidenceStorageValidationException(
      'Unsupported or invalid file signature. Only JPEG, PNG, and PDF files are allowed.',
    );
  }

  @override
  Future<StoredEvidenceMetadata> saveEvidence({
    required String merchantId,
    required String evidenceId,
    required Stream<List<int>> byteStream,
    required String declaredContentType,
    required String originalFilename,
    String? expectedSha256,
  }) async {
    final evidenceDir = await _getEvidenceDir(merchantId, evidenceId);
    await evidenceDir.create(recursive: true);

    final finalFile = File(p.join(evidenceDir.path, 'original'));
    final partFile = File(p.join(evidenceDir.path, 'original.part'));
    final metaFile = File(p.join(evidenceDir.path, 'metadata.json'));

    if (await partFile.exists()) {
      await partFile.delete();
    }

    final sink = partFile.openWrite();
    final outputDigestSink = AccumulatorSink<Digest>();
    final sha256Sink = sha256.startChunkedConversion(outputDigestSink);

    int totalBytes = 0;
    final List<int> headerBytes = [];

    try {
      await for (final chunk in byteStream) {
        if (chunk.isEmpty) continue;

        if (headerBytes.length < 8) {
          final needed = 8 - headerBytes.length;
          final takeCount = chunk.length < needed ? chunk.length : needed;
          headerBytes.addAll(chunk.sublist(0, takeCount));
        }

        totalBytes += chunk.length;
        if (totalBytes > maxFileSizeBytes) {
          throw const EvidenceStorageValidationException(
            'File exceeds maximum permitted size of 10 MB',
          );
        }

        sink.add(chunk);
        sha256Sink.add(chunk);
      }

      await sink.flush();
      await sink.close();
      sha256Sink.close();

      if (totalBytes == 0 || headerBytes.isEmpty) {
        throw const EvidenceStorageValidationException(
          'Empty file payload rejected',
        );
      }

      // Authoritative magic bytes detection
      final detectedType = _detectContentType(headerBytes);
      final normalizedDeclared = declaredContentType.toLowerCase().trim();
      if (normalizedDeclared.isNotEmpty &&
          normalizedDeclared != 'application/octet-stream' &&
          normalizedDeclared != detectedType) {
        // Normalizing image/jpg -> image/jpeg
        final isJpgVariant = (normalizedDeclared == 'image/jpg' && detectedType == 'image/jpeg');
        if (!isJpgVariant) {
          throw EvidenceStorageValidationException(
            "Declared type '$declaredContentType' does not match detected format '$detectedType'",
          );
        }
      }

      final calculatedHash = outputDigestSink.events.single.toString();
      if (expectedSha256 != null &&
          expectedSha256.trim().isNotEmpty &&
          expectedSha256.trim().toLowerCase() != calculatedHash.toLowerCase()) {
        throw EvidenceStorageValidationException(
          'Integrity check failed: calculated hash $calculatedHash does not match expected $expectedSha256',
        );
      }

      // Atomic rename
      await partFile.rename(finalFile.path);

      // Persist local metadata
      // Sanitize original filename to not include path elements
      final safeOriginalFilename = p.basename(originalFilename);
      final metadata = StoredEvidenceMetadata(
        evidenceId: evidenceId,
        merchantId: merchantId,
        originalFilename: safeOriginalFilename,
        contentType: detectedType,
        sizeBytes: totalBytes,
        sha256Hash: calculatedHash,
        createdAt: DateTime.now().toUtc(),
      );

      await metaFile.writeAsString(
        jsonEncode(metadata.toJson()),
        flush: true,
      );

      return metadata;
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      if (await partFile.exists()) {
        try {
          await partFile.delete();
        } catch (_) {}
      }
      if (await finalFile.exists()) {
        try {
          await finalFile.delete();
        } catch (_) {}
      }
      if (e is EvidenceStorageException) {
        rethrow;
      }
      throw EvidenceStorageUnavailableException(
        'Failed to securely store evidence: ${e.toString()}',
      );
    }
  }

  @override
  Future<File> getEvidenceFile({
    required String merchantId,
    required String evidenceId,
  }) async {
    final evidenceDir = await _getEvidenceDir(merchantId, evidenceId);
    final file = File(p.join(evidenceDir.path, 'original'));
    if (!await file.exists()) {
      throw const EvidenceStorageNotFoundException('Evidence file not found');
    }
    return file;
  }

  @override
  Future<StoredEvidenceMetadata?> getMetadata({
    required String merchantId,
    required String evidenceId,
  }) async {
    final evidenceDir = await _getEvidenceDir(merchantId, evidenceId);
    final metaFile = File(p.join(evidenceDir.path, 'metadata.json'));
    if (!await metaFile.exists()) {
      return null;
    }
    try {
      final jsonStr = await metaFile.readAsString();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return StoredEvidenceMetadata.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> evidenceExists({
    required String merchantId,
    required String evidenceId,
  }) async {
    final evidenceDir = await _getEvidenceDir(merchantId, evidenceId);
    final file = File(p.join(evidenceDir.path, 'original'));
    return await file.exists();
  }

  @override
  Future<bool> deleteEvidence({
    required String merchantId,
    required String evidenceId,
  }) async {
    final evidenceDir = await _getEvidenceDir(merchantId, evidenceId);
    if (await evidenceDir.exists()) {
      try {
        await evidenceDir.delete(recursive: true);
        return true;
      } catch (e) {
        throw EvidenceStorageUnavailableException('Failed to delete evidence directory: $e');
      }
    }
    return false;
  }
}
