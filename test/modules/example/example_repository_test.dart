import 'dart:async';

import 'package:dart_meteor/dart_meteor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/data/example_api.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/data/example_local_store.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/data/example_repository.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/domain/example.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_subscription.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_transport.dart';

void main() {
  sqfliteFfiInit();

  test('preserva a versão do servidor ao salvar uma edição local', () async {
    final store = ExampleLocalStore(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final transport = _OfflineTransport();
    final repository = ExampleRepository(
      api: ExampleApi(transport: transport),
      localStore: store,
      transport: transport,
    );
    addTearDown(() async {
      await repository.dispose();
      await store.close();
    });
    final serverVersion = DateTime.utc(2026, 7, 15, 21, 4, 42, 754);
    await store.mergeRemote(
      Example(
        id: 'existing-id',
        title: 'Antes',
        type: 'Categoria A',
        priority: 'media',
        lastUpdate: serverVersion,
      ),
    );

    // Formulários não devem apagar a versão-base mesmo quando enviarem
    // apenas os campos editáveis.
    await repository.save(
      const Example(
        id: 'existing-id',
        title: 'Depois',
        type: 'Categoria A',
        priority: 'media',
      ),
    );

    final saved = await store.getExample('existing-id');
    expect(saved?.title, 'Depois');
    expect(saved?.lastUpdate, serverVersion);
    expect(saved?.syncStatus, ExampleSyncStatus.pending);
  });
}

class _OfflineTransport implements MeteorTransport {
  @override
  Future<dynamic> call(String method, {List<dynamic> args = const []}) =>
      throw TimeoutException('offline');

  @override
  Stream<Map<String, dynamic>> collection(String name) => const Stream.empty();

  @override
  Map<String, dynamic> collectionValue(String name) => const {};

  @override
  Stream<DdpConnectionStatus> get connectionStatus => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> get meteorUser => const Stream.empty();

  @override
  void reconnect() {}

  @override
  MeteorSubscription subscribe(
    String publication, {
    List<dynamic> args = const [],
  }) => throw UnimplementedError();

  @override
  Stream<String?> get userId => const Stream.empty();

  @override
  Future<void> waitUntilConnected({
    Duration timeout = const Duration(seconds: 12),
  }) => throw TimeoutException('offline');
}
