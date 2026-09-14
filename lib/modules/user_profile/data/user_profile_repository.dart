import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/user_profile/data/user_profile_api.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/user_profile/domain/user_profile.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_subscription.dart';

abstract interface class UserProfileCache {
  Future<UserProfile?> read(String userId);
  Future<void> save(String userId, UserProfile profile);
  Future<void> clear();
}

class SecureUserProfileCache implements UserProfileCache {
  const SecureUserProfileCache(this._storage);

  static const _profileKey = 'meteor.userProfile';
  final FlutterSecureStorage _storage;

  @override
  Future<UserProfile?> read(String userId) async {
    final raw = await _storage.read(key: _profileKey);
    if (raw == null) return null;
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (decoded['profile'] is Map) {
        if (decoded['sessionUserId'] != userId) return null;
        return UserProfile.fromCache(
          Map<String, dynamic>.from(decoded['profile'] as Map),
        );
      }
      // Compatibilidade com o formato anterior, que armazenava apenas o perfil.
      final legacyProfile = UserProfile.fromCache(decoded);
      return legacyProfile.id == userId ? legacyProfile : null;
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(String userId, UserProfile profile) {
    return _storage.write(
      key: _profileKey,
      value: jsonEncode({
        'sessionUserId': userId,
        'profile': profile.toCacheMap(),
      }),
    );
  }

  @override
  Future<void> clear() => _storage.delete(key: _profileKey);
}

class UserProfileRepository {
  const UserProfileRepository({
    required UserProfileApi api,
    required UserProfileCache cache,
  }) : _api = api,
       _cache = cache;

  final UserProfileApi _api;
  final UserProfileCache _cache;

  MeteorSubscription subscribeCurrent() => _api.subscribeCurrent();
  Stream<UserProfile?> observeCurrent(String userId) =>
      _api.observeCurrent(userId);
  UserProfile? current(String userId) => _api.current(userId);

  Future<UserProfile?> readCached(String userId) => _cache.read(userId);
  Future<void> cache(String userId, UserProfile profile) =>
      _cache.save(userId, profile);
  Future<void> clearCache() => _cache.clear();
}

final userProfileCacheProvider = Provider<UserProfileCache>((ref) {
  return const SecureUserProfileCache(FlutterSecureStorage());
});

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(
    api: ref.watch(userProfileApiProvider),
    cache: ref.watch(userProfileCacheProvider),
  );
});
