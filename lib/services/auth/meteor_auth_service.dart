import 'package:dart_meteor/dart_meteor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/auth/session_storage_service.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_client_provider.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_error_mapper.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_transport.dart';

class MeteorAuthSession {
  const MeteorAuthSession({
    required this.userId,
    required this.token,
    required this.expiresAt,
  });

  factory MeteorAuthSession.fromLoginResult(MeteorClientLoginResult result) {
    return MeteorAuthSession(
      userId: result.userId,
      token: result.token,
      expiresAt: result.tokenExpires,
    );
  }

  final String userId;
  final String token;
  final DateTime expiresAt;
}

class MeteorAuthService {
  const MeteorAuthService({
    required MeteorClient client,
    required MeteorTransport transport,
    required SessionStorageService storage,
  }) : _client = client,
       _transport = transport,
       _storage = storage;

  final MeteorClient _client;
  final MeteorTransport _transport;
  final SessionStorageService _storage;

  Future<MeteorAuthSession?> restoreSession() async {
    final stored = await _storage.read();
    if (stored == null) return null;
    if (stored.isExpired) {
      await _storage.clear();
      return null;
    }

    try {
      await _transport.waitUntilConnected();
      final result = await _client.loginWithToken(
        token: stored.token,
        tokenExpires: stored.expiresAt,
      );
      if (result == null) {
        await _storage.clear();
        return null;
      }
      final session = MeteorAuthSession.fromLoginResult(result);
      await _save(session);
      return session;
    } catch (error) {
      final failure = MeteorErrorMapper.map(error);
      if (failure.kind == MeteorFailureKind.connection ||
          failure.kind == MeteorFailureKind.timeout) {
        // A sessão local ainda é útil para abrir o app offline. O servidor
        // voltará a validá-la assim que a conexão for restabelecida.
        return MeteorAuthSession(
          userId: stored.userId,
          token: stored.token,
          expiresAt: stored.expiresAt,
        );
      }
      // Token rejeitado ou inválido não deve prender o bootstrap.
      await _storage.clear();
      return null;
    }
  }

  Future<MeteorAuthSession> loginWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _transport.waitUntilConnected();
      final result = await _client
          .loginWithPassword(email.trim(), password)
          .timeout(const Duration(seconds: 15));
      final session = MeteorAuthSession.fromLoginResult(result);
      await _save(session);
      return session;
    } catch (error) {
      throw MeteorErrorMapper.map(error);
    }
  }

  Future<void> logout() async {
    try {
      await _client.logout().timeout(const Duration(seconds: 8));
    } catch (_) {
      // A sessão local sempre é eliminada, mesmo com o servidor indisponível.
    } finally {
      await _storage.clear();
    }
  }

  Future<void> _save(MeteorAuthSession session) {
    return _storage.save(
      StoredMeteorSession(
        userId: session.userId,
        token: session.token,
        expiresAt: session.expiresAt,
      ),
    );
  }
}

final meteorAuthServiceProvider = Provider<MeteorAuthService>((ref) {
  return MeteorAuthService(
    client: ref.watch(meteorClientProvider),
    transport: ref.watch(meteorTransportProvider),
    storage: ref.watch(sessionStorageProvider),
  );
});
