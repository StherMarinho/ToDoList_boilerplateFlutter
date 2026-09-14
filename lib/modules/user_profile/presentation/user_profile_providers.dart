import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synergia_flutter_meteor_boilerplate/app/auth/auth_controller.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/user_profile/domain/user_profile.dart';

/// Equivalente mobile ao valor `user` entregue pelo AuthContext do React.
final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(authControllerProvider.select((state) => state.userProfile));
});

final currentUserRolesProvider = Provider<Set<String>>((ref) {
  return ref.watch(currentUserProfileProvider)?.roles.toSet() ?? const {};
});
