import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vybin/core/services/encryption_service.dart';

void main() {
  group('EncryptionService Tests', () {
    late EncryptionService encryptionService;

    setUp(() {
      encryptionService = EncryptionService();
    });

    test('generateKeyPair creates a valid RSA-2048 pair', () async {
      final pair = await encryptionService.generateKeyPair();
      
      expect(pair.publicKey, isNotNull);
      expect(pair.privateKey, isNotNull);
      
      // Ensure it's 2048 bit (modulus bitLength should be around 2048)
      expect(pair.privateKey.modulus!.bitLength, closeTo(2048, 2));
    });

    test('deriveKeyFromPassword produces consistent 32-byte key', () {
      final key1 = encryptionService.deriveKeyFromPassword('myPassword123', 'user_123');
      final key2 = encryptionService.deriveKeyFromPassword('myPassword123', 'user_123');
      final key3 = encryptionService.deriveKeyFromPassword('differentPass', 'user_123');

      expect(key1.length, 32);
      expect(key1, equals(key2));
      expect(key1, isNot(equals(key3)));
    });

    test('encrypt and decrypt PrivateKey restores original key', () async {
      final pair = await encryptionService.generateKeyPair();
      final privKey = pair.privateKey;

      final derivedKey = encryptionService.deriveKeyFromPassword('secure_pass', 'uid_abc');

      final encrypted = encryptionService.encryptPrivateKey(privKey, derivedKey);
      expect(encrypted, isNotEmpty);

      final decryptedKey = encryptionService.decryptPrivateKey(encrypted, derivedKey);

      expect(decryptedKey.modulus, equals(privKey.modulus));
      expect(decryptedKey.privateExponent, equals(privKey.privateExponent));
      expect(decryptedKey.p, equals(privKey.p));
      expect(decryptedKey.q, equals(privKey.q));
    });

    test('decryptPrivateKey with wrong key throws or fails', () async {
      final pair = await encryptionService.generateKeyPair();
      final derivedKey1 = encryptionService.deriveKeyFromPassword('pass1', 'uid_1');
      final derivedKey2 = encryptionService.deriveKeyFromPassword('pass2', 'uid_1');

      final encrypted = encryptionService.encryptPrivateKey(pair.privateKey, derivedKey1);

      expect(
        () => encryptionService.decryptPrivateKey(encrypted, derivedKey2),
        throwsException,
      );
    });
    
    test('clearPrivateKey correctly nullifies in-memory keys', () async {
      final pair = await encryptionService.generateKeyPair();
      encryptionService.loadKeyPair(pair);
      
      expect(encryptionService.privateKey, isNotNull);
      expect(encryptionService.publicKey, isNotNull);
      
      encryptionService.clearPrivateKey();
      
      expect(encryptionService.privateKey, isNull);
      expect(encryptionService.publicKey, isNull);
    });
  });
}
