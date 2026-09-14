import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/user_profile/domain/user_profile.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_api_base.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_subscription.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_transport.dart';

/// Contrato mobile da coleção `userprofile` do MeteorReactBaseMUI.
class UserProfileApi extends MeteorApiBase<UserProfile> {
  const UserProfileApi({required super.transport})
    : super(apiName: 'userprofile', decode: UserProfile.fromMeteor);

  MeteorSubscription subscribeCurrent() => subscribe('getLoggedUserProfile');

  UserProfile? _selectCurrent(
    Iterable<UserProfile> profiles,
    String sessionUserId,
  ) {
    final profileList = profiles.toList(growable: false);
    final sessionProfile = profileList
        .where((profile) => profile.id == sessionUserId)
        .firstOrNull;
    if (sessionProfile != null) return sessionProfile;
    return profileList.length == 1 ? profileList.single : null;
  }

  Stream<UserProfile?> observeCurrent(String sessionUserId) =>
      observeCollection().map(
        (profiles) => _selectCurrent(profiles, sessionUserId),
      );

  UserProfile? current(String sessionUserId) {
    final documents = transport.collectionValue(collectionName);
    final profiles = documents.entries.map((entry) {
      final raw = Map<String, dynamic>.from(entry.value as Map);
      raw.putIfAbsent('_id', () => entry.key);
      return UserProfile.fromMeteor(raw);
    });
    return _selectCurrent(profiles, sessionUserId);
  }
}

final userProfileApiProvider = Provider<UserProfileApi>((ref) {
  return UserProfileApi(transport: ref.watch(meteorTransportProvider));
});
