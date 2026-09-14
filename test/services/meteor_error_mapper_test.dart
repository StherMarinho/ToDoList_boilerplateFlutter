import 'dart:async';

import 'package:dart_meteor/dart_meteor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_error_mapper.dart';

void main() {
  test('traduz erro de credenciais do Accounts', () {
    final error = MeteorError.parse({
      'error': 403,
      'reason': 'Incorrect password',
    });

    final failure = MeteorErrorMapper.map(error);

    expect(failure.kind, MeteorFailureKind.authentication);
    expect(failure.message, 'Email ou senha inválidos.');
  });

  test('traduz timeout de conexão', () {
    final failure = MeteorErrorMapper.map(TimeoutException('timeout'));

    expect(failure.kind, MeteorFailureKind.timeout);
    expect(failure.message, contains('demorou'));
  });

  test('traduz conta desativada sem cair em erro genérico', () {
    final error = MeteorError.parse({
      'error': 'user-disabled',
      'reason': 'Este usuário está desativado.',
    });

    final failure = MeteorErrorMapper.map(error);

    expect(failure.kind, MeteorFailureKind.authentication);
    expect(failure.message, 'Este usuário está desativado.');
  });
}
