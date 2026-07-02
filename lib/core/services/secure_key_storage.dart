import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyStorage {
  final FlutterSecureStorage _storage;
  
  static const String _privateKeyKey = 'vybin_private_key';

  SecureKeyStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Persists the symmetrically encrypted private key to secure storage.
  Future<void> writeEncryptedPrivateKey(String encryptedKey) async {
    await _storage.write(key: _privateKeyKey, value: encryptedKey);
  }

  /// Retrieves the encrypted private key from secure storage.
  Future<String?> readEncryptedPrivateKey() async {
    return await _storage.read(key: _privateKeyKey);
  }

  /// Deletes the encrypted private key from secure storage.
  Future<void> deleteEncryptedPrivateKey() async {
    await _storage.delete(key: _privateKeyKey);
  }

  static const String _rawPrivateKeyKey = 'vybin_raw_private_key';

  /// Persists the raw (decrypted) private key JSON to secure storage.
  Future<void> writeRawPrivateKey(String rawKeyJson) async {
    await _storage.write(key: _rawPrivateKeyKey, value: rawKeyJson);
  }

  /// Retrieves the raw (decrypted) private key JSON from secure storage.
  Future<String?> readRawPrivateKey() async {
    return await _storage.read(key: _rawPrivateKeyKey);
  }

  /// Deletes the raw (decrypted) private key JSON from secure storage.
  Future<void> deleteRawPrivateKey() async {
    await _storage.delete(key: _rawPrivateKeyKey);
  }
}
