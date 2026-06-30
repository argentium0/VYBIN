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
  Future<AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>> generateKeyPair() async {
    return await Isolate.run(() {
      final secureRandom = _getSecureRandom();
      final keyGen = RSAKeyGenerator()
        ..init(ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
          secureRandom,
        ));
      
      final pair = keyGen.generateKeyPair();
      return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
          pair.publicKey as RSAPublicKey, pair.privateKey as RSAPrivateKey);
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
  RSAPrivateKey decryptPrivateKey(String encryptedBase64, Uint8List derivedKey) {
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

  static SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }
}
