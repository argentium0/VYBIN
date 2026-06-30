import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:pointycastle/pointycastle.dart';

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
        pair.publicKey as RSAPublicKey,
        pair.privateKey as RSAPrivateKey,
      );
    });
  }

  void loadKeyPair(AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> pair) {
    _inMemoryPublicKey = pair.publicKey;
    _inMemoryPrivateKey = pair.privateKey;
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
    final combined = base64Decode(encryptedBase64);

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

    if (bytes[offset++] != 0x30) throw Exception('Invalid PEM: Not a sequence');
    offset = _skipAsn1Length(bytes, offset);

    if (bytes[offset++] != 0x02) throw Exception('Invalid PEM: Modulus not an integer');
    final modLen = _parseAsn1Length(bytes, offset);
    offset = _skipAsn1LengthBytes(bytes, offset);
    final modBytes = bytes.sublist(offset, offset + modLen);
    offset += modLen;
    final modulus = _parseBigInt(modBytes);

    if (bytes[offset++] != 0x02) throw Exception('Invalid PEM: Exponent not an integer');
    final expLen = _parseAsn1Length(bytes, offset);
    offset = _skipAsn1LengthBytes(bytes, offset);
    final expBytes = bytes.sublist(offset, offset + expLen);
    final exponent = _parseBigInt(expBytes);

    return RSAPublicKey(modulus, exponent);
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

  static SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }
}
