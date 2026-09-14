import 'dart:async';

import 'package:dart_meteor/dart_meteor.dart';

/// Adaptador pequeno para não espalhar tipos de `dart_meteor` pelos módulos.
class MeteorSubscription {
  MeteorSubscription._(this._handler, this._errorController);

  factory MeteorSubscription.start(
    MeteorClient client,
    String publication, {
    List<dynamic> args = const [],
  }) {
    final errors = StreamController<Object>.broadcast();
    final handler = client.subscribe(
      publication,
      args: args,
      onStop: (dynamic error) {
        if (error != null && !errors.isClosed) errors.add(error as Object);
        return () {};
      },
    );
    return MeteorSubscription._(handler, errors);
  }

  final SubscriptionHandler _handler;
  final StreamController<Object> _errorController;
  bool _stopped = false;

  Stream<bool> get ready => _handler.ready().distinct();
  Stream<Object> get errors => _errorController.stream;

  void stop() {
    if (_stopped) return;
    _stopped = true;
    _handler.stop();
    _errorController.close();
  }
}
