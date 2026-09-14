import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredMeteorSession {
  const StoredMeteorSession({
    required this.userId,
    required this.token,
    required this.expiresAt,
  });

  final String userId;
  final String token;
  final DateTime expiresAt;

  bool get isExpired => !expiresAt.isAfter(DateTime.now());
}

abstract interface class SessionStorageService {
  Future<StoredMeteorSession?> read();
  Future<void> save(StoredMeteorSession session);
  Future<void> clear();
}

class SecureSessionStorageService implements SessionStorageService {
  const SecureSessionStorageService(this._storage);

  static const _userIdKey = 'meteor.userId';
  static const _tokenKey = 'meteor.loginToken';
  static const _expiresAtKey = 'meteor.loginTokenExpiresAt';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredMeteorSession?> read() async {
    final values = await _storage.readAll();
    final userId = values[_userIdKey];
    final token = values[_tokenKey];
    final rawExpiresAt = values[_expiresAtKey];
    final expiresAt = DateTime.tryParse(rawExpiresAt ?? '');

    if (userId == null || token == null || expiresAt == null) {
      await clear();
      return null;
    }
    return StoredMeteorSession(
      userId: userId,
      token: token,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> save(StoredMeteorSession session) async {
    await _storage.write(key: _userIdKey, value: session.userId);
    await _storage.write(key: _tokenKey, value: session.token);
    await _storage.write(
      key: _expiresAtKey,
      value: session.expiresAt.toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresAtKey);
  }
}

final sessionStorageProvider = Provider<SessionStorageService>((ref) {
  return const SecureSessionStorageService(FlutterSecureStorage());
});
