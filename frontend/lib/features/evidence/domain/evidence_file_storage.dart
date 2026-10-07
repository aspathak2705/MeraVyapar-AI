import 'dart:io';
import 'stored_evidence_metadata.dart';

abstract class EvidenceFileStorage {
  /// Securely stores raw evidence from a stream or byte source into app-private storage.
  ///
  /// Enforces:
  /// - Strict UUID validation for [merchantId] and [evidenceId]
  /// - Magic-byte inspection for JPEG, PNG, PDF
  /// - Max file size of 10 MB
  /// - Authoritative chunked SHA-256 calculation
  /// - Atomic temporary file writes (.part -> final)
  /// - Metadata persistence alongside the binary
  Future<StoredEvidenceMetadata> saveEvidence({
    required String merchantId,
    required String evidenceId,
    required Stream<List<int>> byteStream,
    required String declaredContentType,
    required String originalFilename,
    String? expectedSha256,
  });

  /// Reads/opens stored evidence binary.
  Future<File> getEvidenceFile({
    required String merchantId,
    required String evidenceId,
  });

  /// Reads stored evidence metadata.
  Future<StoredEvidenceMetadata?> getMetadata({
    required String merchantId,
    required String evidenceId,
  });

  /// Checks if evidence binary exists in app-private storage.
  Future<bool> evidenceExists({
    required String merchantId,
    required String evidenceId,
  });

  /// Deletes evidence binary and metadata safely.
  Future<bool> deleteEvidence({
    required String merchantId,
    required String evidenceId,
  });

  /// Lists all evidence IDs locally stored for an authenticated merchant.
  Future<List<String>> listStoredEvidence({
    required String merchantId,
  });

  /// Exports an authenticated merchant's evidence package (binary bytes + metadata)
  /// without exposing physical filesystem paths.
  Future<Map<String, dynamic>> exportEvidence({
    required String merchantId,
    required String evidenceId,
  });
}
