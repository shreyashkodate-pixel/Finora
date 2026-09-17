import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure token and session storage wrapper per SRS §3.3a & §3.6.
/// Provides encrypted storage on mobile/desktop with graceful in-memory fallback.
class SessionStorage {
  static final SessionStorage _instance = SessionStorage._internal();
  factory SessionStorage() => _instance;
  SessionStorage._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // In-memory fallback map for platforms or test environments where Keychain is unavailable
  final Map<String, String> _memoryFallback = {};

  static const String keyAccessToken = 'auth_access_token';
  static const String keyRefreshToken = 'auth_refresh_token';
  static const String keyUserProfile = 'auth_user_profile';

  Future<void> write(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {
      _memoryFallback[key] = value;
    }
  }

  Future<String?> read(String key) async {
    try {
      final val = await _secureStorage.read(key: key);
      if (val != null) return val;
    } catch (_) {}
    return _memoryFallback[key];
  }

  Future<void> delete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {}
    _memoryFallback.remove(key);
  }

  Future<void> clearSession() async {
    await delete(keyAccessToken);
    await delete(keyRefreshToken);
    await delete(keyUserProfile);
  }

  // Convenience accessors
  Future<String?> getAccessToken() => read(keyAccessToken);
  Future<void> setAccessToken(String token) => write(keyAccessToken, token);

  Future<String?> getRefreshToken() => read(keyRefreshToken);
  Future<void> setRefreshToken(String token) => write(keyRefreshToken, token);

  Future<Map<String, dynamic>?> getUserProfile() async {
    final raw = await read(keyUserProfile);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setUserProfile(Map<String, dynamic> profile) =>
      write(keyUserProfile, jsonEncode(profile));
}
