import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_meteor/dart_meteor.dart';

const _defaultUrl = 'http://127.0.0.1:3200';

Future<void> main() async {
  final email = Platform.environment['SYNERGIA_TEST_EMAIL'];
  final password = Platform.environment['SYNERGIA_TEST_PASSWORD'];
  final url = Platform.environment['SYNERGIA_METEOR_URL'] ?? _defaultUrl;
  final holdSeconds =
      int.tryParse(Platform.environment['SYNERGIA_TEST_HOLD_SECONDS'] ?? '') ??
      0;

  if (email == null || email.isEmpty || password == null || password.isEmpty) {
    stderr.writeln(
      'Defina SYNERGIA_TEST_EMAIL e SYNERGIA_TEST_PASSWORD com uma conta existente.',
    );
    exitCode = 64;
    return;
  }

  final firstClient = MeteorClient.connect(
    url: url,
    userAgent: 'SynergiaFlutterIntegrationCheck/1.0',
  );
  MeteorClient? resumedClient;
  String? createdId;
  var firstClientDisconnected = false;

  try {
    await _waitForConnection(firstClient);
    final login = await firstClient
        .loginWithPassword(email, password)
        .timeout(const Duration(seconds: 15));
    _check(login.userId.isNotEmpty, 'O login não retornou userId.');
    stdout.writeln('✓ Login por email/senha');

    final profileSubscription = firstClient.subscribe(
      'userprofile.getLoggedUserProfile',
    );
    await _waitForReady(profileSubscription, 'perfil do usuário');
    final profile = await _waitForFirstDocument(firstClient, 'userprofile');
    _check(
      profile['email'] == email,
      'O perfil publicado não corresponde ao login.',
    );
    final roles =
        (profile['roles'] as List?)?.map((role) => '$role').toSet() ?? {};
    _check(
      roles.isNotEmpty,
      'O perfil autenticado não possui papéis de acesso.',
    );
    stdout.writeln('✓ Publicação do perfil autenticado (${roles.join(', ')})');

    final suffix = DateTime.now().microsecondsSinceEpoch;
    final pullCursorBeforeInsert = DateTime.now().toUtc();
    final title = '__flutter_integration_$suffix';
    createdId = (await firstClient.call(
      'example.insert',
      args: [
        <String, dynamic>{
          'title': title,
          'description': 'Criado pelo verificador Flutter',
          'type': 'Categoria A',
          'typeMulti': 'alta',
          'slider': 10,
          'statusToggle': false,
        },
      ],
    )).toString();
    _check(
      createdId.isNotEmpty,
      'example.insert não retornou o identificador.',
    );
    stdout.writeln('✓ example.insert');

    final listSubscription = firstClient.subscribe(
      'example.exampleList',
      args: [
        <String, dynamic>{'title': title},
        <String, dynamic>{
          'sort': <String, dynamic>{'createdat': -1},
          'limit': 100,
        },
      ],
    );
    final countSubscription = firstClient.subscribe(
      'example.countexampleList',
      args: [
        <String, dynamic>{'title': title},
      ],
    );
    await Future.wait([
      _waitForReady(listSubscription, 'lista de exemplos'),
      _waitForReady(countSubscription, 'contador de exemplos'),
    ]);
    final listDocument = await _waitForDocument(
      firstClient,
      'example',
      createdId,
    );
    _check(
      listDocument['title'] == title,
      'A lista não publicou o exemplo criado.',
    );
    final count = await _waitForDocument(
      firstClient,
      'counts',
      'exampleListTotal',
    );
    _check(count['count'] == 1, 'O contador da lista deveria retornar 1.');
    stdout.writeln('✓ example.exampleList e example.countexampleList');

    final detailSubscription = firstClient.subscribe(
      'example.exampleDetail',
      args: [
        <String, dynamic>{'_id': createdId},
      ],
    );
    await _waitForReady(detailSubscription, 'detalhe do exemplo');
    final detail = await _waitForDocument(firstClient, 'example', createdId);
    _check(
      detail['description'] == 'Criado pelo verificador Flutter',
      'O detalhe não publicou os campos completos.',
    );
    stdout.writeln('✓ example.exampleDetail');

    final imageBytes = await File('lib/images/synergia.png').readAsBytes();
    final assets =
        <({String id, String kind, String name, String mime, List<int> bytes})>[
          (
            id: 'integration-image-$suffix',
            kind: 'image',
            name: 'marker.png',
            mime: 'image/png',
            bytes: imageBytes,
          ),
          (
            id: 'integration-audio-$suffix',
            kind: 'audio',
            name: 'voice.wav',
            mime: 'audio/wav',
            bytes: _silentWav(),
          ),
          (
            id: 'integration-file-$suffix',
            kind: 'attachment',
            name: 'evidence.txt',
            mime: 'text/plain',
            bytes: List<int>.generate(400 * 1024, (index) => index % 251),
          ),
        ];
    for (final asset in assets) {
      final digest = sha256.convert(asset.bytes).toString();
      const chunkSize = 128 * 1024;
      var offset = 0;
      var duplicatedFirstChunk = false;
      while (offset < asset.bytes.length) {
        final end = (offset + chunkSize).clamp(0, asset.bytes.length);
        final chunk = asset.bytes.sublist(offset, end);
        final payload = <String, dynamic>{
          'uploadId': asset.id,
          'assetId': asset.id,
          'exampleId': createdId,
          'name': asset.name,
          'mimeType': asset.mime,
          'kind': asset.kind,
          'size': asset.bytes.length,
          'checksum': digest,
          'offset': offset,
          'data': base64Encode(chunk),
          'isLast': end == asset.bytes.length,
        };
        final response = await firstClient.call(
          'example.uploadAssetChunk',
          args: [payload],
        );
        _check(response is Map, 'Resposta de upload inválida.');
        final nextOffset = (response['nextOffset'] as num).toInt();
        if (!duplicatedFirstChunk && asset.bytes.length > chunkSize) {
          final duplicate = await firstClient.call(
            'example.uploadAssetChunk',
            args: [payload],
          );
          _check(
            duplicate is Map && duplicate['nextOffset'] == nextOffset,
            'Repetição idempotente do bloco alterou o offset.',
          );
          duplicatedFirstChunk = true;
        }
        offset = nextOffset;
        if (offset == asset.bytes.length) {
          _check(
            response['complete'] == true,
            'Upload ${asset.kind} não foi concluído.',
          );
        }
      }
    }
    final remoteAssets = await _readAllAssetPages(firstClient);
    for (final expected in assets) {
      final remote = remoteAssets
          .where((item) => item['_id'] == expected.id)
          .firstOrNull;
      if (remote == null) {
        throw StateError('Catálogo não contém ${expected.kind}.');
      }
      _check(
        remote['kind'] == expected.kind,
        'Catálogo não contém ${expected.kind}.',
      );
      await _checkDownload(remote['url'].toString(), expected.bytes.length);
    }
    final pullAfterInsert = await firstClient.call(
      'example.mobilePull',
      args: [
        <String, dynamic>{'since': pullCursorBeforeInsert},
      ],
    );
    _check(
      pullAfterInsert is Map &&
          (pullAfterInsert['documents'] as List).any(
            (document) => document is Map && document['_id'] == createdId,
          ),
      'Pull incremental não devolveu o documento criado.',
    );
    stdout.writeln(
      '✓ upload multipartes/idempotente, catálogo e downloads dos três tipos',
    );
    if (holdSeconds > 0) {
      stdout.writeln(
        '⏸ Documento $createdId mantido por $holdSeconds s para inspeção no app',
      );
      await Future<void>.delayed(Duration(seconds: holdSeconds));
    }

    final conflictBase = await firstClient.call(
      'example.mobileGet',
      args: [
        <String, dynamic>{'_id': createdId},
      ],
    );
    _check(conflictBase is Map, 'Snapshot para conflito inválido.');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await firstClient.call(
      'example.update',
      args: [
        <String, dynamic>{
          '_id': createdId,
          'title': title,
          'description': 'Alteração concorrente da Web',
          'type': 'Categoria A',
          'typeMulti': 'alta',
          'slider': 10,
          'statusToggle': false,
        },
      ],
    );
    var conflictDetected = false;
    try {
      await firstClient.call(
        'example.mobileUpsert',
        args: [
          <String, dynamic>{
            'document': <String, dynamic>{
              '_id': createdId,
              'title': title,
              'description': 'Alteração offline concorrente',
              'type': 'Categoria A',
              'typeMulti': 'alta',
              'slider': 10,
              'statusToggle': false,
            },
            'baseVersion': conflictBase['lastupdate'],
          },
        ],
      );
    } catch (error) {
      conflictDetected =
          error.toString().contains('sync-conflict') ||
          error.toString().contains('alterado no servidor');
    }
    _check(conflictDetected, 'Conflito otimista não foi detectado.');
    stdout.writeln('✓ conflito otimista sem sobrescrita silenciosa');

    await firstClient.call(
      'example.update',
      args: [
        <String, dynamic>{
          '_id': createdId,
          'title': title,
          'description': 'Atualizado pelo verificador Flutter',
          'type': 'Categoria B',
          'typeMulti': 'media',
          'slider': 42,
          'statusToggle': true,
        },
      ],
    );
    await _waitForDocument(
      firstClient,
      'example',
      createdId,
      predicate: (document) =>
          document['description'] == 'Atualizado pelo verificador Flutter' &&
          document['type'] == 'Categoria B',
    );
    stdout.writeln('✓ example.update reativo');

    final pullCursorBeforeRemoval = DateTime.now().toUtc();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await firstClient.call(
      'example.remove',
      args: [
        <String, dynamic>{'_id': createdId},
      ],
    );
    await _waitForRemoval(firstClient, 'example', createdId);
    final pullAfterRemoval = await firstClient.call(
      'example.mobilePull',
      args: [
        <String, dynamic>{'since': pullCursorBeforeRemoval},
      ],
    );
    _check(
      pullAfterRemoval is Map &&
          (pullAfterRemoval['deletedIds'] as List).contains(createdId),
      'Tombstone da exclusão não foi publicado.',
    );
    createdId = null;
    stdout.writeln('✓ example.remove reativo e tombstone incremental');

    // Simula o encerramento do processo do app antes de uma nova abertura.
    // Não mantenha duas conexões compartilhando o mesmo resume token durante
    // o logout, pois esse não é o ciclo de vida real de uma aplicação mobile.
    firstClient.disconnect();
    firstClientDisconnected = true;
    await Future<void>.delayed(const Duration(milliseconds: 300));

    resumedClient = MeteorClient.connect(
      url: url,
      userAgent: 'SynergiaFlutterResumeCheck/1.0',
    );
    await _waitForConnection(resumedClient);
    final resumed = await resumedClient
        .loginWithToken(token: login.token, tokenExpires: login.tokenExpires)
        .timeout(const Duration(seconds: 15));
    _check(
      resumed?.userId == login.userId,
      'A retomada da sessão retornou outro usuário.',
    );
    stdout.writeln('✓ Retomada da sessão com token Meteor');

    await resumedClient.logout().timeout(const Duration(seconds: 10));
    stdout.writeln('✓ Logout e revogação da sessão');
    stdout.writeln('Integração MeteorReactBaseMUI validada com sucesso.');
  } catch (error, stackTrace) {
    stderr.writeln('Falha na integração MeteorReactBaseMUI: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    if (createdId != null) {
      try {
        await firstClient.call(
          'example.remove',
          args: [
            <String, dynamic>{'_id': createdId},
          ],
        );
      } catch (_) {
        stderr.writeln(
          'Atenção: não foi possível remover o exemplo temporário $createdId.',
        );
      }
    }
    resumedClient?.disconnect();
    if (!firstClientDisconnected) firstClient.disconnect();
  }
}

List<int> _silentWav() {
  const sampleRate = 8000;
  const durationSeconds = 1;
  const channelCount = 1;
  const bitsPerSample = 16;
  const dataLength = sampleRate * durationSeconds * 2;
  final bytes = Uint8List(44 + dataLength);
  final data = ByteData.sublistView(bytes);

  void writeAscii(int offset, String value) {
    bytes.setRange(offset, offset + value.length, ascii.encode(value));
  }

  writeAscii(0, 'RIFF');
  data.setUint32(4, 36 + dataLength, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channelCount, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, bitsPerSample, Endian.little);
  writeAscii(36, 'data');
  data.setUint32(40, dataLength, Endian.little);
  return bytes;
}

Future<List<Map<String, dynamic>>> _readAllAssetPages(
  MeteorClient client,
) async {
  String? fileCursor;
  String? legacyCursor;
  var filesDone = false;
  var legacyDone = false;
  final result = <Map<String, dynamic>>[];
  while (!filesDone || !legacyDone) {
    final page = await client.call(
      'example.mobileAssetsPage',
      args: [
        <String, dynamic>{
          'fileCursor': ?fileCursor,
          'legacyCursor': ?legacyCursor,
          'skipFiles': filesDone,
          'skipLegacy': legacyDone,
          'limit': 200,
        },
      ],
    );
    _check(page is Map, 'Página de ativos inválida.');
    for (final raw in page['assets'] as List? ?? const []) {
      if (raw is Map) result.add(Map<String, dynamic>.from(raw));
    }
    filesDone = page['filesDone'] == true;
    legacyDone = page['legacyDone'] == true;
    fileCursor = page['fileCursor']?.toString();
    legacyCursor = page['legacyCursor']?.toString();
  }
  return result;
}

Future<void> _checkDownload(String url, int expectedSize) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    final bytes = await response.fold<List<int>>(
      <int>[],
      (all, chunk) => all..addAll(chunk),
    );
    _check(
      response.statusCode == 200,
      'Download de mídia retornou HTTP ${response.statusCode}.',
    );
    _check(
      bytes.length == expectedSize,
      'Download de mídia retornou tamanho diferente.',
    );
  } finally {
    client.close(force: true);
  }
}

Future<void> _waitForConnection(MeteorClient client) async {
  await client
      .status()
      .firstWhere((status) => status.connected)
      .timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw TimeoutException('Conexão DDP não foi estabelecida.'),
      );
}

Future<void> _waitForReady(
  SubscriptionHandler subscription,
  String description,
) async {
  await subscription
      .ready()
      .firstWhere((ready) => ready)
      .timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
          'A publicação de $description não ficou pronta.',
        ),
      );
}

Future<Map<String, dynamic>> _waitForFirstDocument(
  MeteorClient client,
  String collection,
) async {
  final documents = await client
      .collection(collection)
      .firstWhere((value) => value.isNotEmpty)
      .timeout(const Duration(seconds: 15));
  return Map<String, dynamic>.from(documents.values.first as Map);
}

Future<Map<String, dynamic>> _waitForDocument(
  MeteorClient client,
  String collection,
  String id, {
  bool Function(Map<String, dynamic> document)? predicate,
}) async {
  final documents = await client
      .collection(collection)
      .firstWhere((value) {
        final raw = value[id];
        if (raw is! Map) return false;
        final document = Map<String, dynamic>.from(raw);
        return predicate?.call(document) ?? true;
      })
      .timeout(const Duration(seconds: 15));
  return Map<String, dynamic>.from(documents[id] as Map);
}

Future<void> _waitForRemoval(
  MeteorClient client,
  String collection,
  String id,
) async {
  await client
      .collection(collection)
      .firstWhere((documents) => !documents.containsKey(id))
      .timeout(const Duration(seconds: 15));
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}
