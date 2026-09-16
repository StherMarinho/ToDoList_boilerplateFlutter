import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/domain/example_resources.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/domain/to_do_resources.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/user_profile/domain/user_profile_resources.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/user_profile/presentation/user_profile_providers.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/auth/access_control_policy.dart';

/// Registro central de roles - recursos, equivalente ao `mapRolesRecursos`
final accessControlPolicyProvider = Provider<AccessControlPolicy>((ref) {
  const exampleResources = ExampleResources.all;
  const userSelfServiceResources = UserProfileResources.selfService;
  const toDoResources = ToDoResources.all;

  return const AccessControlPolicy(
    resourcesByRole: {
      SynergiaRoles.public: <String>{},
      SynergiaRoles.user: <String>{
        ...exampleResources,
        ...userSelfServiceResources,
        ...toDoResources,
      },
      SynergiaRoles.administrator: <String>{
        ...exampleResources,
        ...UserProfileResources.all,
        ...toDoResources,
      },
    },
  );
});

final currentUserResourcesProvider = Provider<Set<String>>((ref) {
  final policy = ref.watch(accessControlPolicyProvider);
  return policy.resourcesFor(ref.watch(currentUserProfileProvider));
});

final canAccessResourceProvider = Provider.family<bool, String>((
  ref,
  resource,
) {
  return ref.watch(currentUserResourcesProvider).contains(resource);
});