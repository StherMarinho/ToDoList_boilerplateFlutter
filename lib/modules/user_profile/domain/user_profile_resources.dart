/// Recursos do módulo `userprofile`, com os mesmos valores declarados pelo
/// backend MeteorReactBaseMUI.
abstract final class UserProfileResources {
  static const view = 'USUARIO_VIEW';
  static const create = 'USUARIO_CREATE';
  static const update = 'USUARIO_UPDATE';
  static const remove = 'USUARIO_REMOVE';

  static const all = <String>{view, create, update, remove};
  static const selfService = <String>{view, update};
}

abstract final class UserProfileStatus {
  static const active = 'active';
  static const disabled = 'disabled';
}
