import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:frontend/features/evidence/data/app_private_evidence_storage.dart';
import 'package:frontend/features/evidence/domain/stored_evidence_metadata.dart';
import 'package:frontend/features/evidence/domain/evidence_storage_exception.dart';

void main() {
  late Directory tempDir;
  late AppPrivateEvidenceStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hemopi_evidence_test_');
    storage = AppPrivateEvidenceStorage(
      rootDirProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HemoPI Local Storage Pattern - Evidence Storage & Lifecycle Tests', () {
    const merchantId = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';
    const evidenceId = 'b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e';

    test('Store, retrieve, and verify SHA-256 integrity for PDF statement', () async {
      // PDF header: %PDF- (25 50 44 46 2D)
      final pdfBytes = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, 0x0A, ...utf8.encode('Test statement data')];
      final expectedHash = sha256.convert(pdfBytes).toString();

      final metadata = await storage.saveEvidence(
        merchantId: merchantId,
        evidenceId: evidenceId,
        originalFilename: 'statement_nov2026.pdf',
        declaredContentType: 'application/pdf',
        byteStream: Stream.value(pdfBytes),
      );

      expect(metadata.evidenceId, evidenceId);
      expect(metadata.merchantId, merchantId);
      expect(metadata.contentType, 'application/pdf');
      expect(metadata.sizeBytes, pdfBytes.length);
      expect(metadata.sha256Hash, expectedHash);

      // Verify file existence on disk
      final exists = await storage.evidenceExists(merchantId: merchantId, evidenceId: evidenceId);
      expect(exists, isTrue);

      // Read back file and check contents
      final retrievedFile = await storage.getEvidenceFile(merchantId: merchantId, evidenceId: evidenceId);
      final readBytes = await retrievedFile.readAsBytes();
      expect(readBytes, pdfBytes);

      // Export package check
      final exported = await storage.exportEvidence(merchantId: merchantId, evidenceId: evidenceId);
      expect(exported['sha256_hash'], expectedHash);
      expect(exported['bytes'], pdfBytes);
    });

    test('Path traversal attempts are rejected and raise security exceptions', () async {
      final dummyBytes = [0xFF, 0xD8, 0xFF, 0x00]; // JPEG header
      expect(
        () => storage.saveEvidence(
          merchantId: '../hack_merchant',
          evidenceId: evidenceId,
          originalFilename: 'test.jpg',
          declaredContentType: 'image/jpeg',
          byteStream: Stream.value(dummyBytes),
        ),
        throwsA(isA<EvidenceStoragePathException>()),
      );

      expect(
        () => storage.saveEvidence(
          merchantId: merchantId,
          evidenceId: 'invalid-id-format',
          originalFilename: 'test.jpg',
          declaredContentType: 'image/jpeg',
          byteStream: Stream.value(dummyBytes),
        ),
        throwsA(isA<EvidenceStoragePathException>()),
      );
    });

    test('Detect and reject corrupted file during export', () async {
      final pdfBytes = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34];
      await storage.saveEvidence(
        merchantId: merchantId,
        evidenceId: evidenceId,
        originalFilename: 'doc.pdf',
        declaredContentType: 'application/pdf',
        byteStream: Stream.value(pdfBytes),
      );

      // Intentionally tamper with disk file
      final file = await storage.getEvidenceFile(merchantId: merchantId, evidenceId: evidenceId);
      await file.writeAsBytes([0x00, 0x00, 0x00], flush: true);

      // Export must detect hash discrepancy and abort
      expect(
        () => storage.exportEvidence(merchantId: merchantId, evidenceId: evidenceId),
        throwsA(isA<EvidenceStorageValidationException>()),
      );
    });

    test('Safe deletion removes evidence directory completely', () async {
      final pdfBytes = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34];
      await storage.saveEvidence(
        merchantId: merchantId,
        evidenceId: evidenceId,
        originalFilename: 'doc.pdf',
        declaredContentType: 'application/pdf',
        byteStream: Stream.value(pdfBytes),
      );

      final deleted = await storage.deleteEvidence(merchantId: merchantId, evidenceId: evidenceId);
      expect(deleted, isTrue);

      final exists = await storage.evidenceExists(merchantId: merchantId, evidenceId: evidenceId);
      expect(exists, isFalse);

      final meta = await storage.getMetadata(merchantId: merchantId, evidenceId: evidenceId);
      expect(meta, isNull);
    });
  });
}
