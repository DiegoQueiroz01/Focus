import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'focus_access_token';
  static const _expiresAtKey = 'focus_access_token_expires_at';

  final FlutterSecureStorage _storage;
  String? _cachedToken;
  DateTime? _cachedExpiresAt;

  Future<void> save(String token, Duration expiresIn) async {
    final expiresAt = DateTime.now().add(expiresIn);
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _expiresAtKey, value: expiresAt.toIso8601String());
    _cachedToken = token;
    _cachedExpiresAt = expiresAt;
  }

  /// Retorna o token apenas se ainda estiver válido; tokens expirados são descartados.
  Future<String?> read() async {
    _cachedToken ??= await _storage.read(key: _tokenKey);
    if (_cachedToken == null) return null;

    if (_cachedExpiresAt == null) {
      final raw = await _storage.read(key: _expiresAtKey);
      _cachedExpiresAt = raw == null ? null : DateTime.tryParse(raw);
    }

    final expiresAt = _cachedExpiresAt;
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
      await clear();
      return null;
    }
    return _cachedToken;
  }

  Future<void> clear() async {
    _cachedToken = null;
    _cachedExpiresAt = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresAtKey);
  }
}
