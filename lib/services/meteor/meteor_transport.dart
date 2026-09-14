import 'dart:async';

import 'package:dart_meteor/dart_meteor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_client_provider.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_error_mapper.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_subscription.dart';

abstract interface class MeteorTransport {
  Stream<DdpConnectionStatus> get connectionStatus;
  Stream<String?> get userId;
  Stream<Map<String, dynamic>?> get meteorUser;

  Stream<Map<String, dynamic>> collection(String name);
  Map<String, dynamic> collectionValue(String name);
  Future<dynamic> call(String method, {List<dynamic> args = const []});
  MeteorSubscription subscribe(
    String publication, {
    List<dynamic> args = const [],
  });
  Future<void> waitUntilConnected({Duration timeout});
  void reconnect();
}

class DartMeteorTransport implements MeteorTransport {
  const DartMeteorTransport(this.client);

  final MeteorClient client;

  @override
  Stream<DdpConnectionStatus> get connectionStatus => client.status();

  @override
  Stream<String?> get userId => client.userId();

  @override
  Stream<Map<String, dynamic>?> get meteorUser => client.user();

  @override
  Stream<Map<String, dynamic>> collection(String name) =>
      client.collection(name);

  @override
  Map<String, dynamic> collectionValue(String name) {
    return client.collectionCurrentValue(name) ?? <String, dynamic>{};
  }

  @override
  Future<dynamic> call(String method, {List<dynamic> args = const []}) async {
    try {
      return await client.call(method, args: args);
    } catch (error) {
      throw MeteorErrorMapper.map(error);
    }
  }

  @override
  MeteorSubscription subscribe(
    String publication, {
    List<dynamic> args = const [],
  }) {
    return MeteorSubscription.start(client, publication, args: args);
  }

  @override
  Future<void> waitUntilConnected({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      await connectionStatus
          .firstWhere((status) => status.connected)
          .timeout(timeout);
    } catch (error) {
      throw MeteorErrorMapper.map(error);
    }
  }

  @override
  void reconnect() => client.reconnect();
}

final meteorTransportProvider = Provider<MeteorTransport>((ref) {
  return DartMeteorTransport(ref.watch(meteorClientProvider));
});

/// Estado de conexão global, equivalente ao `Meteor.status()` observado pelos
/// providers/hooks do frontend React.
final meteorConnectionStatusProvider = StreamProvider<DdpConnectionStatus>((
  ref,
) {
  return ref.watch(meteorTransportProvider).connectionStatus;
});

final meteorConnectedProvider = Provider<bool>((ref) {
  return ref
      .watch(meteorConnectionStatusProvider)
      .when(
        data: (status) => status.connected,
        loading: () => false,
        error: (_, _) => false,
      );
});
