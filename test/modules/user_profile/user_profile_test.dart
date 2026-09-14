import 'package:dart_meteor/dart_meteor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synergia_flutter_meteor_boilerplate/app/auth/auth_providers.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/user_profile/data/user_profile_api.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/user_profile/domain/user_profile.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/user_profile/domain/user_profile_resources.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/auth/access_control_policy.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_subscription.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_transport.dart';

void main() {
  test('mantém o contrato básico da coleção userprofile', () {
    final profile = UserProfile.fromMeteor({
      '_id': 'user-1',
      'username': 'Maria',
      'email': 'maria@example.com',
      'photo': 'data:image/png;base64,abc',
      'phone': '3133334444',
      'roles': ['Usuario'],
      'status': 'active',
      'createdat': '2026-07-01T12:00:00.000Z',
      'lastupdate': '2026-07-02T12:00:00.000Z',
      'sincronizadoEm': '2026-07-03T12:00:00.000Z',
      'needSync': true,
      'createdby': 'admin-1',
      'updatedby': 'admin-2',
    });

    expect(profile.id, 'user-1');
    expect(profile.displayName, 'Maria');
    expect(profile.photo, 'data:image/png;base64,abc');
    expect(profile.phone, '3133334444');
    expect(profile.roles, ['Usuario']);
    expect(profile.status, 'active');
    expect(profile.createdAt, DateTime.utc(2026, 7, 1, 12));
    expect(profile.lastUpdate, DateTime.utc(2026, 7, 2, 12));
    expect(profile.syncedAt, DateTime.utc(2026, 7, 3, 12));
    expect(profile.needsSync, isTrue);
    expect(profile.createdBy, 'admin-1');
    expect(profile.updatedBy, 'admin-2');

    final document = profile.toMeteorDocument();
    expect(document['status'], 'active');
    expect(document['roles'], ['Usuario']);
    expect(document, isNot(contains('resources')));
  });

  test('converte roles em recursos como o mapa de segurança do React', () {
    const policy = AccessControlPolicy(
      resourcesByRole: {
        'Usuario': {'EXAMPLE_VIEW', 'EXAMPLE_CREATE'},
      },
    );
    const profile = UserProfile(
      id: 'user-1',
      username: 'Maria',
      email: 'maria@example.com',
      roles: ['Usuario'],
    );

    expect(policy.canAccessAny(profile, ['EXAMPLE_VIEW']), isTrue);
    expect(policy.canAccessAny(profile, ['EXAMPLE_REMOVE']), isFalse);
  });

  test('recursos publicados pelo servidor prevalecem sobre o mapa local', () {
    const policy = AccessControlPolicy(
      resourcesByRole: {
        'Administrador': {'EXAMPLE_VIEW', 'EXAMPLE_REMOVE'},
      },
    );
    const profile = UserProfile(
      id: 'admin-1',
      username: 'Admin',
      email: 'admin@example.com',
      roles: ['Administrador'],
      resources: ['EXAMPLE_VIEW'],
    );

    expect(policy.canAccessAny(profile, ['EXAMPLE_VIEW']), isTrue);
    expect(policy.canAccessAny(profile, ['EXAMPLE_REMOVE']), isFalse);
  });

  test('replica recursos e status básicos do módulo userprofile', () {
    expect(UserProfileResources.all, {
      'USUARIO_VIEW',
      'USUARIO_CREATE',
      'USUARIO_UPDATE',
      'USUARIO_REMOVE',
    });
    expect(UserProfileResources.selfService, {
      'USUARIO_VIEW',
      'USUARIO_UPDATE',
    });
    expect(UserProfileStatus.active, 'active');
    expect(UserProfileStatus.disabled, 'disabled');
  });

  test('provider central registra autoatendimento e administração', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final policy = container.read(accessControlPolicyProvider);

    const user = UserProfile(
      id: 'user-1',
      username: 'Maria',
      email: 'maria@example.com',
      roles: [SynergiaRoles.user],
    );
    const administrator = UserProfile(
      id: 'admin-1',
      username: 'Admin',
      email: 'admin@example.com',
      roles: [SynergiaRoles.administrator],
    );

    expect(
      policy.resourcesFor(user),
      containsAll(UserProfileResources.selfService),
    );
    expect(
      policy.resourcesFor(user),
      isNot(contains(UserProfileResources.create)),
    );
    expect(
      policy.resourcesFor(administrator),
      containsAll(UserProfileResources.all),
    );
  });

  test('perfil desativado não recebe recursos no cliente', () {
    const policy = AccessControlPolicy(
      resourcesByRole: {
        SynergiaRoles.user: {'EXAMPLE_VIEW'},
      },
    );
    const disabled = UserProfile(
      id: 'user-1',
      username: 'Maria',
      email: 'maria@example.com',
      roles: [SynergiaRoles.user],
      status: UserProfileStatus.disabled,
    );

    expect(disabled.isDisabled, isTrue);
    expect(policy.resourcesFor(disabled), isEmpty);
  });

  test('normaliza status legado publicado como lista', () {
    final profile = UserProfile.fromMeteor({
      '_id': 'user-1',
      'username': 'Maria',
      'email': 'maria@example.com',
      'status': ['active'],
    });

    expect(profile.status, UserProfileStatus.active);
  });

  test('seleciona o perfil da sessão em uma coleção compartilhada', () async {
    const api = UserProfileApi(
      transport: _UserProfileTransport({
        'other-user': {
          '_id': 'other-user',
          'username': 'Outro',
          'email': 'outro@example.com',
        },
        'session-user': {
          '_id': 'session-user',
          'username': 'Maria',
          'email': 'maria@example.com',
        },
      }),
    );

    final profile = await api.observeCurrent('session-user').first;

    expect(profile?.id, 'session-user');
    expect(api.current('session-user')?.id, 'session-user');
  });
}

class _UserProfileTransport implements MeteorTransport {
  const _UserProfileTransport(this.documents);

  final Map<String, dynamic> documents;

  @override
  Stream<Map<String, dynamic>> collection(String name) =>
      Stream.value(documents);

  @override
  Map<String, dynamic> collectionValue(String name) => documents;

  @override
  Future<dynamic> call(String method, {List<dynamic> args = const []}) async =>
      null;

  @override
  Stream<DdpConnectionStatus> get connectionStatus => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> get meteorUser => const Stream.empty();

  @override
  Stream<String?> get userId => const Stream.empty();

  @override
  MeteorSubscription subscribe(
    String publication, {
    List<dynamic> args = const [],
  }) => throw UnimplementedError();

  @override
  Future<void> waitUntilConnected({
    Duration timeout = const Duration(seconds: 12),
  }) async {}

  @override
  void reconnect() {}
}
