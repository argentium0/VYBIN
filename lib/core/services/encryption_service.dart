import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vybin/core/services/secure_key_storage.dart';

class EncryptionService {
  RSAPrivateKey? _inMemoryPrivateKey;
  RSAPublicKey? _inMemoryPublicKey;

  RSAPrivateKey? get privateKey => _inMemoryPrivateKey;
  RSAPublicKey? get publicKey => _inMemoryPublicKey;

  /// Clears the private key from memory
  void clearPrivateKey() {
    _inMemoryPrivateKey = null;
    _inMemoryPublicKey = null;
  }

  /// Generates an RSA-2048 key pair in an isolate.
  Future<AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>>
  generateKeyPair() async {
    return await Isolate.run(() {
      final secureRandom = _getSecureRandom();
      final keyGen = RSAKeyGenerator()
        ..init(
          ParametersWithRandom(
            RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
            secureRandom,
          ),
        );

      final pair = keyGen.generateKeyPair();
      return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
        pair.publicKey,
        pair.privateKey,
      );
    });
  }

  void loadKeyPair(AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> pair) {
    _inMemoryPublicKey = pair.publicKey;
    _inMemoryPrivateKey = pair.privateKey;
  }

  /// Serializes an RSAPrivateKey into a JSON string.
  String serializePrivateKey(RSAPrivateKey privKey) {
    final Map<String, dynamic> keyData = {
      'n': privKey.modulus?.toRadixString(16),
      'd': privKey.privateExponent?.toRadixString(16),
      'p': privKey.p?.toRadixString(16),
      'q': privKey.q?.toRadixString(16),
    };
    return jsonEncode(keyData);
  }

  /// Deserializes a JSON string into an RSAPrivateKey.
  RSAPrivateKey deserializePrivateKey(String rawJson) {
    final Map<String, dynamic> keyData = jsonDecode(rawJson);
    return RSAPrivateKey(
      BigInt.parse(keyData['n']!, radix: 16),
      BigInt.parse(keyData['d']!, radix: 16),
      BigInt.parse(keyData['p']!, radix: 16),
      BigInt.parse(keyData['q']!, radix: 16),
    );
  }

  /// Derives a 32-byte AES key from password and uid using PBKDF2.
  Uint8List deriveKeyFromPassword(String password, String uid) {
    final salt = utf8.encode(uid);
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(Uint8List.fromList(salt), 100000, 32));

    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Serializes an RSAPrivateKey into a basic string (JSON) and encrypts it using AES-256-GCM.
  String encryptPrivateKey(RSAPrivateKey privKey, Uint8List derivedKey) {
    final Map<String, dynamic> keyData = {
      'n': privKey.modulus?.toRadixString(16),
      'd': privKey.privateExponent?.toRadixString(16),
      'p': privKey.p?.toRadixString(16),
      'q': privKey.q?.toRadixString(16),
    };
    final serializedPem = jsonEncode(keyData);

    final secureRandom = _getSecureRandom();
    final nonce = secureRandom.nextBytes(12); // 96-bit nonce for GCM

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(derivedKey), 128, nonce, Uint8List(0)),
      );

    final plaintext = utf8.encode(serializedPem);
    final ciphertext = cipher.process(Uint8List.fromList(plaintext));

    final combined = Uint8List(nonce.length + ciphertext.length);
    combined.setAll(0, nonce);
    combined.setAll(nonce.length, ciphertext);

    return base64Encode(combined);
  }

  /// Decrypts the AES-256-GCM string back into an RSAPrivateKey.
  RSAPrivateKey decryptPrivateKey(
    String encryptedBase64,
    Uint8List derivedKey,
  ) {
    final sanitizedBase64 = encryptedBase64.replaceAll(RegExp(r'\s+'), '').trim();
    final combined = base64Decode(sanitizedBase64);

    final nonce = combined.sublist(0, 12);
    final ciphertext = combined.sublist(12);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(derivedKey), 128, nonce, Uint8List(0)),
      );

    final plaintext = cipher.process(ciphertext);
    final serializedPem = utf8.decode(plaintext);

    final Map<String, dynamic> keyData = jsonDecode(serializedPem);
    return RSAPrivateKey(
      BigInt.parse(keyData['n'] as String, radix: 16),
      BigInt.parse(keyData['d'] as String, radix: 16),
      BigInt.parse(keyData['p'] as String, radix: 16),
      BigInt.parse(keyData['q'] as String, radix: 16),
    );
  }

  /// Encodes an [RSAPublicKey] to PKCS#1 PEM string.
  String encodePublicKeyToPem(RSAPublicKey publicKey) {
    final modulus = publicKey.modulus!;
    final exponent = publicKey.exponent!;

    final modulusBytes = _encodeBigInt(modulus);
    final exponentBytes = _encodeBigInt(exponent);

    final modulusAsn1 = _encodeAsn1Integer(modulusBytes);
    final exponentAsn1 = _encodeAsn1Integer(exponentBytes);

    final sequenceBytes = Uint8List.fromList([...modulusAsn1, ...exponentAsn1]);
    final sequenceAsn1 = _encodeAsn1Sequence(sequenceBytes);

    final base64String = base64Encode(sequenceAsn1);

    final chunks = [];
    for (var i = 0; i < base64String.length; i += 64) {
      chunks.add(base64String.substring(i, min(i + 64, base64String.length)));
    }

    return '-----BEGIN RSA PUBLIC KEY-----\n${chunks.join('\n')}\n-----END RSA PUBLIC KEY-----';
  }

  /// Decodes a PKCS#1 PEM string back to [RSAPublicKey].
  RSAPublicKey decodePublicKeyFromPem(String pem) {
    final lines = pem.split('\n');
    final base64Lines = lines.where((line) => !line.startsWith('-----')).join();
    final bytes = base64Decode(base64Lines);

    var offset = 0;

    if (bytes[offset++] != 0x30) {
      throw Exception('Invalid PEM: Not a sequence');
    }
    offset = _skipAsn1Length(bytes, offset);

    if (bytes[offset++] != 0x02) {
      throw Exception('Invalid PEM: Modulus not an integer');
    }
    final modLen = _parseAsn1Length(bytes, offset);
    offset = _skipAsn1LengthBytes(bytes, offset);
    final modBytes = bytes.sublist(offset, offset + modLen);
    offset += modLen;
    final modulus = _parseBigInt(modBytes);

    if (bytes[offset++] != 0x02) {
      throw Exception('Invalid PEM: Exponent not an integer');
    }
    final expLen = _parseAsn1Length(bytes, offset);
    offset = _skipAsn1LengthBytes(bytes, offset);
    final expBytes = bytes.sublist(offset, offset + expLen);
    final exponent = _parseBigInt(expBytes);

    return RSAPublicKey(modulus, exponent);
  }

  /// Encrypts a message using AES-256-GCM and encrypts the AES session key using RSA-OAEP
  /// for both the recipient and the sender.
  Map<String, dynamic> encryptMessage({
    required String plaintext,
    required String recipientUid,
    required String recipientPubKeyPEM,
    required String senderUid,
    required String senderPubKeyPEM,
  }) {
    final secureRandom = _getSecureRandom();
    final aesKey = secureRandom.nextBytes(32);
    final iv = secureRandom.nextBytes(12);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(aesKey), 128, iv, Uint8List(0)));

    final plaintextBytes = utf8.encode(plaintext);
    final ciphertextBytes = cipher.process(Uint8List.fromList(plaintextBytes));
    final ciphertextBase64 = base64Encode(ciphertextBytes);
    final ivBase64 = base64Encode(iv);

    // Encrypt AES key for recipient and sender
    final recipientPubKey = decodePublicKeyFromPem(recipientPubKeyPEM);
    final senderPubKey = decodePublicKeyFromPem(senderPubKeyPEM);

    final oaepRecipient = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(recipientPubKey));
    final encryptedKeyRecipient = base64Encode(oaepRecipient.process(aesKey));

    final oaepSender = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(senderPubKey));
    final encryptedKeySender = base64Encode(oaepSender.process(aesKey));

    return {
      'ciphertext': ciphertextBase64,
      'iv': ivBase64,
      'encryptedKeys': {
        recipientUid: encryptedKeyRecipient,
        senderUid: encryptedKeySender,
      },
    };
  }

  /// Encrypts raw media bytes using a newly generated AES-256 session key.
  /// Returns a map containing:
  /// - 'encryptedBytes': Uint8List of encrypted content
  /// - 'iv': base64 of GCM nonce
  /// - 'aesKey': Uint8List session key (so we can use it to encrypt other payloads)
  /// - 'encryptedKeys': Map of uid -> base64(RSA-OAEP encrypted AES key)
  Map<String, dynamic> encryptMediaBytes({
    required Uint8List rawBytes,
    required String recipientUid,
    required String recipientPubKeyPEM,
    required String senderUid,
    required String senderPubKeyPEM,
  }) {
    final secureRandom = _getSecureRandom();
    final aesKey = secureRandom.nextBytes(32);
    final iv = secureRandom.nextBytes(12);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(aesKey), 128, iv, Uint8List(0)));

    final encryptedBytes = cipher.process(rawBytes);

    final recipientPubKey = decodePublicKeyFromPem(recipientPubKeyPEM);
    final senderPubKey = decodePublicKeyFromPem(senderPubKeyPEM);

    final oaepRecipient = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(recipientPubKey));
    final encryptedKeyRecipient = base64Encode(oaepRecipient.process(aesKey));

    final oaepSender = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(senderPubKey));
    final encryptedKeySender = base64Encode(oaepSender.process(aesKey));

    return {
      'encryptedBytes': encryptedBytes,
      'iv': base64Encode(iv),
      'aesKey': aesKey,
      'encryptedKeys': {
        recipientUid: encryptedKeyRecipient,
        senderUid: encryptedKeySender,
      },
    };
  }

  /// Decrypts raw media bytes using the session key decrypted with the local private key.
  Uint8List decryptMediaBytes({
    required Uint8List encryptedBytes,
    required String ivBase64,
    required String encryptedSessionKeyBase64,
  }) {
    try {
      if (_inMemoryPrivateKey == null) {
        throw Exception('Private key not loaded in memory.');
      }

      final oaep = OAEPEncoding.withSHA256(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(_inMemoryPrivateKey!));

      final encryptedSessionKey = base64Decode(encryptedSessionKeyBase64);
      final aesKey = oaep.process(encryptedSessionKey);

      final iv = base64Decode(ivBase64);

      final cipher = GCMBlockCipher(
        AESEngine(),
      )..init(false, AEADParameters(KeyParameter(aesKey), 128, iv, Uint8List(0)));

      return cipher.process(encryptedBytes);
    } catch (_) {
      return Uint8List(0);
    }
  }

  /// Encrypts plaintext string using a pre-existing AES session key.
  /// Returns a map with 'ciphertext' (base64) and 'iv' (base64).
  Map<String, String> encryptPlaintextWithKey({
    required String plaintext,
    required Uint8List aesKey,
  }) {
    final secureRandom = _getSecureRandom();
    final iv = secureRandom.nextBytes(12);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(aesKey), 128, iv, Uint8List(0)));

    final plaintextBytes = utf8.encode(plaintext);
    final ciphertextBytes = cipher.process(Uint8List.fromList(plaintextBytes));

    return {
      'ciphertext': base64Encode(ciphertextBytes),
      'iv': base64Encode(iv),
    };
  }

  /// Decrypts a message using the in-memory private key.
  String decryptMessage({
    required String ciphertextBase64,
    required String ivBase64,
    required String encryptedSessionKeyBase64,
  }) {
    try {
      if (_inMemoryPrivateKey == null) {
        throw Exception('Private key not loaded in memory.');
      }

      // Decrypt the session key
      final oaep = OAEPEncoding.withSHA256(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(_inMemoryPrivateKey!));

      final encryptedSessionKey = base64Decode(encryptedSessionKeyBase64);
      final aesKey = oaep.process(encryptedSessionKey);

      // Decrypt the message
      final iv = base64Decode(ivBase64);
      final ciphertextBytes = base64Decode(ciphertextBase64);

      final cipher = GCMBlockCipher(
        AESEngine(),
      )..init(false, AEADParameters(KeyParameter(aesKey), 128, iv, Uint8List(0)));

      final plaintextBytes = cipher.process(ciphertextBytes);
      return utf8.decode(plaintextBytes);
    } catch (_) {
      return '[DECRYPTION_FAILED]';
    }
  }

  Uint8List _encodeBigInt(BigInt number) {
    var hex = number.toRadixString(16);
    if (hex.length % 2 != 0) {
      hex = '0$hex';
    }
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    if (bytes.isNotEmpty && (bytes[0] & 0x80) != 0) {
      final padded = Uint8List(bytes.length + 1);
      padded[0] = 0x00;
      padded.setAll(1, bytes);
      return padded;
    }
    return bytes;
  }

  Uint8List _encodeAsn1Length(int length) {
    if (length < 128) {
      return Uint8List.fromList([length]);
    }
    final lengthBytes = <int>[];
    var temp = length;
    while (temp > 0) {
      lengthBytes.insert(0, temp & 0xFF);
      temp >>= 8;
    }
    return Uint8List.fromList([0x80 | lengthBytes.length, ...lengthBytes]);
  }

  Uint8List _encodeAsn1Integer(Uint8List value) {
    final lenBytes = _encodeAsn1Length(value.length);
    return Uint8List.fromList([0x02, ...lenBytes, ...value]);
  }

  Uint8List _encodeAsn1Sequence(Uint8List value) {
    final lenBytes = _encodeAsn1Length(value.length);
    return Uint8List.fromList([0x30, ...lenBytes, ...value]);
  }

  int _parseAsn1Length(Uint8List bytes, int offset) {
    final first = bytes[offset];
    if ((first & 0x80) == 0) {
      return first;
    }
    final lenBytesCount = first & 0x7F;
    var length = 0;
    for (var i = 0; i < lenBytesCount; i++) {
      length = (length << 8) | bytes[offset + 1 + i];
    }
    return length;
  }

  int _skipAsn1Length(Uint8List bytes, int offset) {
    final first = bytes[offset];
    if ((first & 0x80) == 0) {
      return offset + 1;
    }
    return offset + 1 + (first & 0x7F);
  }

  int _skipAsn1LengthBytes(Uint8List bytes, int offset) {
    return _skipAsn1Length(bytes, offset);
  }

  BigInt _parseBigInt(Uint8List bytes) {
    var hex = '';
    for (final b in bytes) {
      hex += b.toRadixString(16).padLeft(2, '0');
    }
    return BigInt.parse(hex, radix: 16);
  }

  Future<bool> hasValidLocalPrivateKey(String expectedPublicKey) async {
    try {
      const secureStorage = FlutterSecureStorage();
      final secureKeyStorage = SecureKeyStorage(storage: secureStorage);
      final rawJson = await secureKeyStorage.readRawPrivateKey();
      if (rawJson == null) return false;

      final privKey = deserializePrivateKey(rawJson);
      final pubKey = decodePublicKeyFromPem(expectedPublicKey);

      return privKey.modulus == pubKey.modulus;
    } catch (_) {
      return false;
    }
  }

  static SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }
}
