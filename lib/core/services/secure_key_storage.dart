import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyStorage {
  final FlutterSecureStorage _storage;

  static const String _privateKeyKey = 'vybin_private_key';

  SecureKeyStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> writeEncryptedPrivateKey(String encryptedKey) async {
    await _storage.write(key: _privateKeyKey, value: encryptedKey);
  }

  Future<String?> readEncryptedPrivateKey() async {
    return await _storage.read(key: _privateKeyKey);
  }

  Future<void> deleteEncryptedPrivateKey() async {
    await _storage.delete(key: _privateKeyKey);
  }

  static const String _rawPrivateKeyKey = 'vybin_raw_private_key';

  Future<void> writeRawPrivateKey(String rawKeyJson) async {
    await _storage.write(key: _rawPrivateKeyKey, value: rawKeyJson);
  }

  Future<String?> readRawPrivateKey() async {
    return await _storage.read(key: _rawPrivateKeyKey);
  }

  Future<void> deleteRawPrivateKey() async {
    await _storage.delete(key: _rawPrivateKeyKey);
  }

  static const String _localSessionIdKey = 'local_session_id';

  Future<void> writeLocalSessionId(String sessionId) async {
    await _storage.write(key: _localSessionIdKey, value: sessionId);
  }

  Future<String?> readLocalSessionId() async {
    return await _storage.read(key: _localSessionIdKey);
  }

  Future<void> deleteLocalSessionId() async {
    await _storage.delete(key: _localSessionIdKey);
  }
}
