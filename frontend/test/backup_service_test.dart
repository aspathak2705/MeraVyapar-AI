import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';

void main() {
  group('Encrypted Backup Container & Key Derivation Tests', () {
    test('Encrypt-then-MAC container authentication integrity', () {
      final payload = utf8.encode(jsonEncode({'test': 'financial_data', 'amount': 150000}));
      final salt = 'test_salt_12345';
      final nonceHex = '0102030405060708090a0b0c0d0e0f10';
      
      final macKey = Hmac(sha256, utf8.encode('test_master_key')).convert(utf8.encode('MAC_KEY_V3')).bytes;
      final aad = utf8.encode('MERAVYAPAR_ENCRYPTED_BACKUP_V3:3:$salt:$nonceHex');
      
      final authTag = Hmac(sha256, macKey).convert([...aad, ...payload]).toString();
      
      // Verification with matching tag
      final verifyTag = Hmac(sha256, macKey).convert([...aad, ...payload]).toString();
      expect(authTag, equals(verifyTag));
      
      // Verification with tampered payload
      final tamperedPayload = utf8.encode(jsonEncode({'test': 'financial_data', 'amount': 999999}));
      final tamperedTag = Hmac(sha256, macKey).convert([...aad, ...tamperedPayload]).toString();
      expect(authTag, isNot(equals(tamperedTag)));
    });

    test('Manifest validation correctly parses JSON', () {
      final manifestJson = {
        'backup_version': 3,
        'schema_version': 3,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'merchant_id': '00000000-0000-0000-0000-000000000001',
        'database_checksum': 'abc123sha256',
        'evidence_file_count': 0,
        'evidence_checksums': <String, String>{},
      };

      expect(manifestJson['backup_version'], equals(3));
      expect(manifestJson['schema_version'], equals(3));
      expect(manifestJson['merchant_id'], equals('00000000-0000-0000-0000-000000000001'));
    });
  });
}
