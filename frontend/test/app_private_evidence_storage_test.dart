import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:frontend/features/evidence/data/app_private_evidence_storage.dart';
import 'package:frontend/features/evidence/domain/evidence_storage_exception.dart';

void main() {
  late Directory tempRootDir;
  late AppPrivateEvidenceStorage storage;

  const testMerchantId = '11111111-1111-1111-1111-111111111111';
  const testEvidenceId = '22222222-2222-2222-2222-222222222222';
  const otherMerchantId = '33333333-3333-3333-3333-333333333333';

  // Real valid file byte fixtures
  final jpegBytes = <int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00];
  final pngBytes = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52];
  final pdfBytes = <int>[0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, 0x0A, 0x25, 0xC4, 0xE5];

  setUp(() async {
    tempRootDir = await Directory.systemTemp.createTemp('storage_test_');
    storage = AppPrivateEvidenceStorage(
      rootDirProvider: () async => tempRootDir,
    );
  });

  tearDown(() async {
    if (await tempRootDir.exists()) {
      await tempRootDir.delete(recursive: true);
    }
  });

  Stream<List<int>> byteStreamOf(List<int> bytes) => Stream.value(bytes);

  test('1. Valid JPEG can be stored', () async {
    final meta = await storage.saveEvidence(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
      byteStream: byteStreamOf(jpegBytes),
      declaredContentType: 'image/jpeg',
      originalFilename: 'receipt.jpg',
    );

    expect(meta.contentType, 'image/jpeg');
    expect(meta.sizeBytes, jpegBytes.length);
    expect(await storage.evidenceExists(merchantId: testMerchantId, evidenceId: testEvidenceId), isTrue);
  });

  test('2. Valid PNG can be stored', () async {
    final meta = await storage.saveEvidence(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
      byteStream: byteStreamOf(pngBytes),
      declaredContentType: 'image/png',
      originalFilename: 'invoice.png',
    );

    expect(meta.contentType, 'image/png');
    expect(meta.sizeBytes, pngBytes.length);
  });

  test('3. Valid PDF can be stored', () async {
    final meta = await storage.saveEvidence(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
      byteStream: byteStreamOf(pdfBytes),
      declaredContentType: 'application/pdf',
      originalFilename: 'statement.pdf',
    );

    expect(meta.contentType, 'application/pdf');
    expect(meta.sizeBytes, pdfBytes.length);
  });

  test('4. Unsupported signature is rejected', () async {
    final fakeExeBytes = <int>[0x4D, 0x5A, 0x90, 0x00]; // MZ header
    expect(
      () => storage.saveEvidence(
        merchantId: testMerchantId,
        evidenceId: testEvidenceId,
        byteStream: byteStreamOf(fakeExeBytes),
        declaredContentType: 'image/png',
        originalFilename: 'malware.png',
      ),
      throwsA(isA<EvidenceStorageValidationException>()),
    );
  });

  test('5. Oversized file is rejected (> 10MB)', () async {
    // Generate a stream yielding chunks totaling > 10MB
    final chunk = List<int>.filled(1024 * 1024, 0xFF); // 1 MB
    chunk[0] = 0xFF;
    chunk[1] = 0xD8;
    chunk[2] = 0xFF;

    Stream<List<int>> oversizedStream() async* {
      for (int i = 0; i < 11; i++) {
        yield chunk;
      }
    }

    expect(
      () => storage.saveEvidence(
        merchantId: testMerchantId,
        evidenceId: testEvidenceId,
        byteStream: oversizedStream(),
        declaredContentType: 'image/jpeg',
        originalFilename: 'large.jpg',
      ),
      throwsA(isA<EvidenceStorageValidationException>()),
    );
  });

  test('6. Empty file is rejected', () async {
    expect(
      () => storage.saveEvidence(
        merchantId: testMerchantId,
        evidenceId: testEvidenceId,
        byteStream: byteStreamOf([]),
        declaredContentType: 'image/png',
        originalFilename: 'empty.png',
      ),
      throwsA(isA<EvidenceStorageValidationException>()),
    );
  });

  test('7. SHA-256 is calculated authoritatively from actual bytes', () async {
    final expectedRealHash = sha256.convert(jpegBytes).toString();
    final meta = await storage.saveEvidence(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
      byteStream: byteStreamOf(jpegBytes),
      declaredContentType: 'image/jpeg',
      originalFilename: 'receipt.jpg',
    );

    expect(meta.sha256Hash, expectedRealHash);
  });

  test('8. Incorrect expected SHA-256 is rejected', () async {
    expect(
      () => storage.saveEvidence(
        merchantId: testMerchantId,
        evidenceId: testEvidenceId,
        byteStream: byteStreamOf(jpegBytes),
        declaredContentType: 'image/jpeg',
        originalFilename: 'receipt.jpg',
        expectedSha256: 'deadbeef00000000000000000000000000000000000000000000000000000000',
      ),
      throwsA(isA<EvidenceStorageValidationException>()),
    );
  });

  test('9. Correct expected SHA-256 succeeds', () async {
    final expectedRealHash = sha256.convert(pngBytes).toString();
    final meta = await storage.saveEvidence(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
      byteStream: byteStreamOf(pngBytes),
      declaredContentType: 'image/png',
      originalFilename: 'invoice.png',
      expectedSha256: expectedRealHash,
    );

    expect(meta.sha256Hash, expectedRealHash);
  });

  test('10. Final file exists only after successful write', () async {
    final existsBefore = await storage.evidenceExists(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
    );
    expect(existsBefore, isFalse);

    await storage.saveEvidence(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
      byteStream: byteStreamOf(pdfBytes),
      declaredContentType: 'application/pdf',
      originalFilename: 'statement.pdf',
    );

    final existsAfter = await storage.evidenceExists(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
    );
    expect(existsAfter, isTrue);
  });

  test('11 & 12. Failed write does not leave valid final file and cleans temp file', () async {
    final badBytes = <int>[0x00, 0x11, 0x22]; // Corrupt / unknown header
    try {
      await storage.saveEvidence(
        merchantId: testMerchantId,
        evidenceId: testEvidenceId,
        byteStream: byteStreamOf(badBytes),
        declaredContentType: 'image/png',
        originalFilename: 'corrupt.png',
      );
    } catch (_) {}

    final exists = await storage.evidenceExists(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
    );
    expect(exists, isFalse);

    final partFile = File('${tempRootDir.path}/evidence/$testMerchantId/$testEvidenceId/original.part');
    expect(await partFile.exists(), isFalse);
  });

  test('13 & 14. Path traversal and absolute path attempts are rejected', () async {
    expect(
      () => storage.getEvidenceFile(
        merchantId: '../../etc',
        evidenceId: testEvidenceId,
      ),
      throwsA(isA<EvidenceStoragePathException>()),
    );

    expect(
      () => storage.getEvidenceFile(
        merchantId: testMerchantId,
        evidenceId: '/etc/passwd',
      ),
      throwsA(isA<EvidenceStoragePathException>()),
    );
  });

  test('15. Evidence IDs cannot escape storage root', () async {
    expect(
      () => storage.getEvidenceFile(
        merchantId: '..\\..\\windows\\system32',
        evidenceId: testEvidenceId,
      ),
      throwsA(isA<EvidenceStoragePathException>()),
    );
  });

  test('16. Merchant A cannot resolve Merchant B evidence path', () async {
    await storage.saveEvidence(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
      byteStream: byteStreamOf(jpegBytes),
      declaredContentType: 'image/jpeg',
      originalFilename: 'receipt.jpg',
    );

    expect(
      await storage.evidenceExists(merchantId: otherMerchantId, evidenceId: testEvidenceId),
      isFalse,
    );

    expect(
      () => storage.getEvidenceFile(merchantId: otherMerchantId, evidenceId: testEvidenceId),
      throwsA(isA<EvidenceStorageNotFoundException>()),
    );
  });

  test('17. Original filename cannot alter physical storage path', () async {
    final meta = await storage.saveEvidence(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
      byteStream: byteStreamOf(jpegBytes),
      declaredContentType: 'image/jpeg',
      originalFilename: '../../../../malicious_name.jpg',
    );

    // Filename sanitized to basename
    expect(meta.originalFilename, 'malicious_name.jpg');
    // Physical file is still at canonical path 'original'
    final file = await storage.getEvidenceFile(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
    );
    expect(file.path.endsWith('original'), isTrue);
  });

  test('18. Delete removes intended evidence only', () async {
    const evidenceId2 = '44444444-4444-4444-4444-444444444444';

    await storage.saveEvidence(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
      byteStream: byteStreamOf(jpegBytes),
      declaredContentType: 'image/jpeg',
      originalFilename: 'one.jpg',
    );

    await storage.saveEvidence(
      merchantId: testMerchantId,
      evidenceId: evidenceId2,
      byteStream: byteStreamOf(pngBytes),
      declaredContentType: 'image/png',
      originalFilename: 'two.png',
    );

    final deleted = await storage.deleteEvidence(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
    );
    expect(deleted, isTrue);

    expect(await storage.evidenceExists(merchantId: testMerchantId, evidenceId: testEvidenceId), isFalse);
    expect(await storage.evidenceExists(merchantId: testMerchantId, evidenceId: evidenceId2), isTrue);
  });

  test('19. Reading unknown evidence returns controlled not-found error', () async {
    expect(
      () => storage.getEvidenceFile(
        merchantId: testMerchantId,
        evidenceId: '99999999-9999-9999-9999-999999999999',
      ),
      throwsA(isA<EvidenceStorageNotFoundException>()),
    );
  });

  test('20. Metadata corresponds to actual stored file', () async {
    await storage.saveEvidence(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
      byteStream: byteStreamOf(jpegBytes),
      declaredContentType: 'image/jpeg',
      originalFilename: 'receipt.jpg',
    );

    final meta = await storage.getMetadata(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
    );

    expect(meta, isNotNull);
    expect(meta!.evidenceId, testEvidenceId);
    expect(meta.merchantId, testMerchantId);
    expect(meta.contentType, 'image/jpeg');
    expect(meta.sizeBytes, jpegBytes.length);
    expect(meta.sha256Hash, sha256.convert(jpegBytes).toString());
    expect(meta.storageVersion, 1);
  });

  test('21. List stored evidence returns merchant-scoped IDs', () async {
    await storage.saveEvidence(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
      byteStream: byteStreamOf(jpegBytes),
      declaredContentType: 'image/jpeg',
      originalFilename: 'receipt.jpg',
    );

    final listA = await storage.listStoredEvidence(merchantId: testMerchantId);
    expect(listA, contains(testEvidenceId));

    final listB = await storage.listStoredEvidence(merchantId: otherMerchantId);
    expect(listB, isEmpty);
  });

  test('22. Export evidence returns verified bytes and metadata with integrity check', () async {
    await storage.saveEvidence(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
      byteStream: byteStreamOf(jpegBytes),
      declaredContentType: 'image/jpeg',
      originalFilename: 'receipt.jpg',
    );

    final exported = await storage.exportEvidence(
      merchantId: testMerchantId,
      evidenceId: testEvidenceId,
    );

    expect(exported['evidence_id'], testEvidenceId);
    expect(exported['merchant_id'], testMerchantId);
    expect(exported['original_filename'], 'receipt.jpg');
    expect(exported['bytes'], jpegBytes);
    expect(exported['sha256_hash'], sha256.convert(jpegBytes).toString());
  });
}
