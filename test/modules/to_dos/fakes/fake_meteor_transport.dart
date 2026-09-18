import 'dart:async';

import 'package:dart_meteor/dart_meteor.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_subscription.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_transport.dart';

class RecordedCall {
  const RecordedCall(this.method, this.args);

  final String method;
  final List<dynamic> args;
}

class FakeMeteorTransport implements MeteorTransport {
  final _calls = <RecordedCall>[];

  final _collections =
      <String, StreamController<Map<String, dynamic>>>{};

  final _collectionValues = <String, Map<String, dynamic>>{};

  final _methodResponses = <String, dynamic>{};
  final _methodErrors = <String, Exception>{};

  List<RecordedCall> get calls => List.unmodifiable(_calls);

  RecordedCall? lastCallTo(String method) {
    for (var i = _calls.length - 1; i >= 0; i--) {
      if (_calls[i].method == method) {
        return _calls[i];
      }
    }

    return null;
  }

  /// Emite documentos numa coleção DDP.
  void emitToCollection(
    String name,
    Map<String, dynamic> docs,
  ) {
    _collectionValues[name] = docs;
    _collectionController(name).add(docs);
  }

  /// Define o retorno de um Method.
  void setMethodResponse(String method, dynamic response) {
    _methodResponses[method] = response;
  }

  /// Faz um Method lançar erro.
  void setMethodError(String method, Exception error) {
    _methodErrors[method] = error;
  }

  @override
  Stream<Map<String, dynamic>> collection(String name) {
    return _collectionController(name).stream;
  }

  @override
  Map<String, dynamic> collectionValue(String name) {
    return _collectionValues[name] ?? {};
  }

  @override
  Future<dynamic> call(
    String method, {
    List<dynamic> args = const [],
  }) async {
    _calls.add(RecordedCall(method, args));

    if (_methodErrors.containsKey(method)) {
      throw _methodErrors[method]!;
    }

    return _methodResponses[method];
  }

  @override
  MeteorSubscription subscribe(
    String name, {
    List<dynamic> args = const [],
  }) {
    final recordedName = name.startsWith('toDos.')
        ? 'subscribe:${name.substring('toDos.'.length)}'
        : 'subscribe:$name';

    _calls.add(RecordedCall(recordedName, args));

    return _FakeSubscription();
  }

  @override
  Stream<DdpConnectionStatus> get connectionStatus =>
      const Stream.empty();

  @override
  Stream<String?> get userId => Stream.value(null);

  @override
  Stream<Map<String, dynamic>?> get meteorUser =>
      Stream.value(null);

  @override
  Future<void> waitUntilConnected({
    Duration timeout = const Duration(seconds: 12),
  }) async {}

  @override
  void reconnect() {}

  StreamController<Map<String, dynamic>> _collectionController(
    String name,
  ) {
    return _collections.putIfAbsent(
      name,
      () => StreamController<Map<String, dynamic>>.broadcast(
        onListen: () {
          final currentValue = _collectionValues[name];

          if (currentValue != null) {
            _collections[name]!.add(currentValue);
          }
        },
      ),
    );
  }

  void dispose() {
    for (final c in _collections.values) {
      c.close();
    }
  }
}

class _FakeSubscription implements MeteorSubscription {
  @override
  Stream<bool> get ready => Stream.value(true);

  @override
  Stream<Object> get errors => const Stream.empty();

  @override
  void stop() {}
}