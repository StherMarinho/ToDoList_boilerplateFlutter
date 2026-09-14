import 'dart:async';
import 'dart:io';

import 'package:dart_meteor/dart_meteor.dart';

enum MeteorFailureKind {
  authentication,
  authorization,
  validation,
  connection,
  timeout,
  unknown,
}

class MeteorFailure implements Exception {
  const MeteorFailure({
    required this.message,
    required this.kind,
    this.code,
    this.cause,
  });

  final String message;
  final MeteorFailureKind kind;
  final String? code;
  final Object? cause;

  @override
  String toString() => message;
}

class MeteorErrorMapper {
  const MeteorErrorMapper._();

  static MeteorFailure map(Object error) {
    if (error is MeteorFailure) return error;
    if (error is TimeoutException) {
      return MeteorFailure(
        message: 'O servidor demorou para responder. Tente novamente.',
        kind: MeteorFailureKind.timeout,
        cause: error,
      );
    }
    if (error is SocketException || error is WebSocketException) {
      return MeteorFailure(
        message: 'Não foi possível conectar ao servidor.',
        kind: MeteorFailureKind.connection,
        cause: error,
      );
    }
    if (error is MeteorError) {
      final code = error.error?.toString();
      final reason = (error.reason ?? error.message ?? '').trim();
      final normalized = '$code $reason'.toLowerCase();

      if (normalized.contains('user-disabled') ||
          normalized.contains('usuário está desativado') ||
          normalized.contains('usuario esta desativado')) {
        return MeteorFailure(
          message: 'Este usuário está desativado.',
          kind: MeteorFailureKind.authentication,
          code: code,
          cause: error,
        );
      }
      if (normalized.contains('profile-not-found') ||
          normalized.contains('perfil vinculado')) {
        return MeteorFailure(
          message: 'Não existe um perfil vinculado a esta conta.',
          kind: MeteorFailureKind.authentication,
          code: code,
          cause: error,
        );
      }
      if (normalized.contains('email') &&
          (normalized.contains('verific') || normalized.contains('verified'))) {
        return MeteorFailure(
          message: 'Confirme seu email antes de entrar.',
          kind: MeteorFailureKind.authentication,
          code: code,
          cause: error,
        );
      }
      if (normalized.contains('incorrect password') ||
          normalized.contains('user not found') ||
          normalized.contains('login forbidden') ||
          code == '403') {
        return MeteorFailure(
          message: 'Email ou senha inválidos.',
          kind: MeteorFailureKind.authentication,
          code: code,
          cause: error,
        );
      }
      if (normalized.contains('acesso negado') ||
          normalized.contains('not-authorized') ||
          normalized.contains('permission')) {
        return MeteorFailure(
          message: reason.isEmpty ? 'Você não tem permissão.' : reason,
          kind: MeteorFailureKind.authorization,
          code: code,
          cause: error,
        );
      }
      if (normalized.contains('obrigat') ||
          normalized.contains('schema') ||
          normalized.contains('validation') ||
          code == '400') {
        return MeteorFailure(
          message: reason.isEmpty ? 'Verifique os dados informados.' : reason,
          kind: MeteorFailureKind.validation,
          code: code,
          cause: error,
        );
      }
      return MeteorFailure(
        message: reason.isEmpty ? 'Ocorreu um erro no servidor.' : reason,
        kind: MeteorFailureKind.unknown,
        code: code,
        cause: error,
      );
    }
    return MeteorFailure(
      message: 'Ocorreu um erro inesperado.',
      kind: MeteorFailureKind.unknown,
      cause: error,
    );
  }
}
