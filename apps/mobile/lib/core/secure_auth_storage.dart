import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores Supabase sessions and short-lived PKCE verifiers in native secure
/// storage (Android Keystore-backed encryption and the iOS Keychain).
class SecureAuthStorage extends LocalStorage implements GotrueAsyncStorage {
  SecureAuthStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _pkcePrefix = 'lifeos.auth.pkce.';
  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() =>
      _storage.read(key: supabasePersistSessionKey);

  @override
  Future<bool> hasAccessToken() =>
      _storage.containsKey(key: supabasePersistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) => _storage.write(
    key: supabasePersistSessionKey,
    value: persistSessionString,
  );

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(key: supabasePersistSessionKey);

  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: '$_pkcePrefix$key');

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: '$_pkcePrefix$key', value: value);

  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: '$_pkcePrefix$key');
}
