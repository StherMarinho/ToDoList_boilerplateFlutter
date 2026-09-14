import 'package:synergia_flutter_meteor_boilerplate/modules/user_profile/domain/user_profile.dart';

abstract final class SynergiaRoles {
  static const public = 'Publico';
  static const user = 'Usuario';
  static const administrator = 'Administrador';
}

/// Política de autorização da interface, equivalente ao mapa roles → recursos
/// usado pelo frontend React.
///
/// O servidor continua sendo a autoridade final e deve validar toda chamada.
/// Esta política controla apenas navegação, visibilidade e habilitação de ações
/// no cliente. Se o perfil trouxer `resources`, essa lista publicada prevalece;
/// caso contrário é usado o mapa local do boilerplate.
class AccessControlPolicy {
  const AccessControlPolicy({required this.resourcesByRole});

  final Map<String, Set<String>> resourcesByRole;

  Set<String> resourcesFor(UserProfile? profile) {
    if (profile == null || profile.isDisabled) return const {};
    if (profile.resources.isNotEmpty) return profile.resources.toSet();
    return {
      for (final role in profile.roles)
        ...resourcesByRole[role] ?? const <String>{},
    };
  }

  bool canAccessAny(UserProfile? profile, Iterable<String> resources) {
    final required = resources.toSet();
    if (required.isEmpty) return true;
    return resourcesFor(profile).intersection(required).isNotEmpty;
  }

  bool canAccessAll(UserProfile? profile, Iterable<String> resources) {
    final required = resources.toSet();
    if (required.isEmpty) return true;
    return resourcesFor(profile).containsAll(required);
  }
}
