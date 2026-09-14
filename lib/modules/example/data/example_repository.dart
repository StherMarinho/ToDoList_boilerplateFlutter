import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/data/example_api.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/data/example_local_store.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/domain/example.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/domain/example_asset.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_subscription.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_transport.dart';
import 'package:uuid/uuid.dart';

class ExampleRepository {
  ExampleRepository({
    required ExampleApi api,
    required ExampleLocalStore localStore,
    required MeteorTransport transport,
    http.Client? httpClient,
  }) : _api = api,
       _local = localStore,
       _transport = transport,
       _http = httpClient ?? http.Client();

  static const _chunkSize = 192 * 1024;
  static const _maxAssetSize = 15 * 1024 * 1024;
  static const _lastPullKey = 'example.lastPull';

  final ExampleApi _api;
  final ExampleLocalStore _local;
  final MeteorTransport _transport;
  final http.Client _http;
  final _uuid = const Uuid();
  MeteorSubscription? _listSubscription;
  StreamSubscription<Map<String, dynamic>>? _remoteCollection;
  StreamSubscription<dynamic>? _connection;
  Timer? _remoteDebounce;
  Timer? _retryTimer;
  bool _syncing = false;
  bool _started = false;

  Stream<List<Example>> watchExamples() => _local.watchExamples();
  Stream<Example?> watchExample(String id) => _local.watchExample(id);
  Stream<List<ExampleAsset>> watchAssets(String id) => _local.watchAssets(id);
  Future<Example?> getExample(String id) => _local.getExample(id);
  Future<ExampleAsset?> getAsset(String id) => _local.getAsset(id);
  String newId() => _uuid.v4();

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _local.database;
    _remoteCollection = _transport.collection('example').listen((_) {
      // Publicações de lista são projeções parciais. Elas servem apenas como
      // gatilho; o merge durável usa mobilePull, que devolve o documento todo.
      _remoteDebounce?.cancel();
      _remoteDebounce = Timer(const Duration(milliseconds: 350), () {
        _syncInBackground();
      });
    });
    _connection = _transport.connectionStatus.listen((status) {
      if (status.connected) _syncInBackground();
    });
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _syncInBackground();
    });
    await refresh();
  }

  Future<void> refresh() async {
    try {
      _listSubscription?.stop();
      _listSubscription = _api.watchList();
      await _listSubscription!.ready
          .firstWhere((ready) => ready)
          .timeout(const Duration(seconds: 12));
      await syncNow();
    } catch (_) {
      // Offline is a normal state: cached data remains usable.
    }
  }

  Future<String> save(Example example) async {
    final id = example.id.isEmpty ? _uuid.v4() : example.id;
    final persisted = example.id.isEmpty
        ? null
        : await _local.getExample(example.id);
    final local = Example(
      id: id,
      title: example.title,
      description: example.description,
      image: example.image,
      type: example.type,
      priority: example.priority,
      date: example.date,
      check: example.check,
      chips: example.chips,
      files: example.files,
      contacts: example.contacts,
      tasks: example.tasks,
      audio: example.audio,
      address: example.address,
      slider: example.slider,
      statusRadio: example.statusRadio,
      statusToggle: example.statusToggle,
      createdAt: example.createdAt ?? persisted?.createdAt,
      lastUpdate: example.lastUpdate ?? persisted?.lastUpdate,
      createdBy: example.createdBy ?? persisted?.createdBy,
      updatedBy: example.updatedBy ?? persisted?.updatedBy,
      assets: example.assets,
      syncStatus: ExampleSyncStatus.pending,
    );
    await _local.saveLocal(local);
    _syncInBackground();
    return id;
  }

  Future<void> remove(String id) async {
    for (final asset in await _local.listAssets(id)) {
      await removeAsset(asset, synchronize: false);
    }
    await _local.removeLocal(id);
    _syncInBackground();
  }

  Future<void> resolveConflictWithServer(String id) async {
    final remote = await _api.mobileGet(id);
    await _local.acceptRemoteConflict(remote);
  }

  Future<void> resolveConflictKeepingLocal(String id) async {
    final remote = await _api.mobileGet(id);
    if (remote.lastUpdate == null) {
      throw StateError('O servidor não informou a versão do documento.');
    }
    await _local.rebaseLocalConflict(id, remote.lastUpdate!);
    await syncNow();
  }

  Future<ExampleAsset> addAsset({
    required String exampleId,
    required String sourcePath,
    required ExampleAssetKind kind,
    required String mimeType,
    String? name,
  }) async {
    final documentAlreadySaved = await _local.getExample(exampleId) != null;
    final source = File(sourcePath);
    final size = await source.length();
    if (size > _maxAssetSize) {
      throw ArgumentError('O arquivo excede o limite de 15 MB.');
    }
    final assetsDirectory = await _assetDirectory(exampleId);
    final id = _uuid.v4();
    final safeName = _safeFileName(name ?? path.basename(sourcePath));
    final localPath = path.join(assetsDirectory.path, '${id}_$safeName');
    if (path.normalize(source.path) != path.normalize(localPath)) {
      await source.copy(localPath);
    }
    final asset = ExampleAsset(
      id: id,
      exampleId: exampleId,
      kind: kind,
      name: safeName,
      mimeType: mimeType,
      size: size,
      localPath: localPath,
      status: ExampleAssetSyncStatus.localOnly,
      createdAt: DateTime.now(),
    );
    await _local.putAsset(asset, enqueue: true);
    if (documentAlreadySaved) _syncInBackground();
    return asset;
  }

  Future<void> removeAsset(
    ExampleAsset asset, {
    bool synchronize = true,
  }) async {
    if (asset.hasLocalCopy) {
      final file = File(asset.localPath!);
      if (await file.exists()) await file.delete();
    }
    await _local.removeAsset(asset.id, enqueue: asset.remoteUrl != null);
    if (synchronize) _syncInBackground();
  }

  Future<void> downloadAttachment(ExampleAsset asset) async {
    if (asset.remoteUrl == null) return;
    try {
      await _downloadAsset(asset);
    } catch (error) {
      await _local.putAsset(
        asset.copyWith(
          status: ExampleAssetSyncStatus.failed,
          error: error.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;
    try {
      await _transport.waitUntilConnected(timeout: const Duration(seconds: 3));
      final queue = await _local.dueQueue();
      // Documents always precede their assets, even if a previous run stopped
      // after the local file was selected.
      queue.sort(
        (a, b) => a.entityType == b.entityType
            ? a.id.compareTo(b.id)
            : a.entityType == 'example'
            ? -1
            : 1,
      );
      for (final item in queue) {
        try {
          await _process(item);
          await _local.completeQueue(item);
        } catch (error) {
          await _local.failQueue(item, error);
          // Connection failures should not burn through every queued item.
          break;
        }
      }
      await _pullChanges();
      for (final asset in await _local.assetsToAutoDownload()) {
        try {
          await downloadAttachment(asset);
        } catch (_) {
          // A media download is retried on the next synchronization. Document
          // data and uploads are not rolled back because of a cache miss.
        }
      }
    } finally {
      _syncing = false;
    }
  }

  void _syncInBackground() {
    unawaited(() async {
      try {
        await syncNow();
      } catch (_) {
        // A fila local e o timer periódico cuidam da próxima tentativa.
      }
    }());
  }

  Future<void> _process(SyncQueueItem item) async {
    if (item.entityType == 'example') {
      if (item.action == 'delete') {
        await _api.remove(item.entityId);
      } else {
        final example = await _local.getExample(item.entityId);
        if (example != null) {
          final result = await _api.mobileUpsert(example);
          final version = Example.fromMeteor(result).lastUpdate;
          await _local.updateServerVersion(item.entityId, version);
        }
      }
      return;
    }
    final asset = await _local.getAsset(item.entityId);
    if (item.action == 'delete') {
      await _api.removeAsset(item.entityId);
    } else if (asset != null) {
      await _uploadAsset(asset);
    }
  }

  Future<void> _uploadAsset(ExampleAsset asset) async {
    final file = File(asset.localPath!);
    if (!await file.exists()) throw StateError('Arquivo local não encontrado.');
    await _local.putAsset(
      asset.copyWith(
        status: ExampleAssetSyncStatus.uploading,
        clearError: true,
      ),
    );
    final checksum = (await sha256.bind(file.openRead()).first).toString();
    final reader = await file.open();
    var offset = 0;
    Map<String, dynamic> response = const {};
    try {
      while (offset < asset.size || (asset.size == 0 && offset == 0)) {
        final remaining = asset.size - offset;
        final bytes = await reader.read(
          remaining <= 0 ? 0 : remaining.clamp(0, _chunkSize),
        );
        final isLast = offset + bytes.length >= asset.size;
        response = await _api.uploadAssetChunk({
          'uploadId': asset.id,
          'assetId': asset.id,
          'exampleId': asset.exampleId,
          'name': asset.name,
          'mimeType': asset.mimeType,
          'kind': asset.kind.name,
          'size': asset.size,
          'checksum': checksum,
          'offset': offset,
          'data': base64Encode(bytes),
          'isLast': isLast,
        });
        offset =
            (response['nextOffset'] as num?)?.toInt() ??
            (offset + bytes.length);
        if (isLast) break;
      }
    } finally {
      await reader.close();
    }
    await _local.putAsset(
      asset.copyWith(
        checksum: checksum,
        remoteUrl: response['url']?.toString(),
        status: ExampleAssetSyncStatus.available,
        clearError: true,
      ),
    );
  }

  Future<void> _pullChanges() async {
    var rawSince = await _local.getMetadata(_lastPullKey);
    var hasMore = false;
    do {
      final since = DateTime.tryParse(rawSince ?? '');
      final response = await _api.mobilePull(since: since);
      for (final raw in (response['documents'] as List? ?? const [])) {
        if (raw is Map) {
          await _local.mergeRemote(
            Example.fromMeteor(Map<String, dynamic>.from(raw)),
          );
        }
      }
      for (final id in (response['deletedIds'] as List? ?? const [])) {
        await _local.applyRemoteDeletion(id.toString());
      }
      final cursor = response['cursor']?.toString();
      if (cursor != null) {
        rawSince = cursor;
        await _local.setMetadata(_lastPullKey, cursor);
      }
      hasMore = response['hasMore'] == true;
    } while (hasMore);
    await _pullAssetCatalog();
  }

  Future<void> _pullAssetCatalog() async {
    String? fileCursor;
    String? legacyCursor;
    var filesDone = false;
    var legacyDone = false;
    final remoteIds = <String>{};
    while (!filesDone || !legacyDone) {
      final response = await _api.mobileAssetsPage(
        fileCursor: filesDone ? null : fileCursor,
        legacyCursor: legacyDone ? null : legacyCursor,
        skipFiles: filesDone,
        skipLegacy: legacyDone,
      );
      for (final raw in (response['assets'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final remote = ExampleAsset.fromMap(Map<String, dynamic>.from(raw));
        remoteIds.add(remote.id);
        final local = await _local.getAsset(remote.id);
        final contentChanged =
            local?.hasLocalCopy == true &&
            ((remote.checksum != null && remote.checksum != local?.checksum) ||
                (remote.checksum == null &&
                    remote.remoteUrl != local?.remoteUrl));
        final stalePath = contentChanged ? local?.localPath : null;
        await _local.putAsset(
          ExampleAsset(
            id: remote.id,
            exampleId: remote.exampleId,
            kind: remote.kind,
            name: remote.name,
            mimeType: remote.mimeType,
            size: remote.size,
            localPath: contentChanged ? null : local?.localPath,
            remoteUrl: remote.remoteUrl,
            checksum: remote.checksum,
            status: local?.hasLocalCopy == true && !contentChanged
                ? ExampleAssetSyncStatus.available
                : remote.status,
            createdAt: remote.createdAt,
          ),
        );
        if (stalePath != null) {
          final staleFile = File(stalePath);
          if (await staleFile.exists()) await staleFile.delete();
        }
      }
      filesDone = response['filesDone'] == true;
      legacyDone = response['legacyDone'] == true;
      fileCursor = response['fileCursor']?.toString();
      legacyCursor = response['legacyCursor']?.toString();
      if ((!filesDone && fileCursor == null) ||
          (!legacyDone && legacyCursor == null)) {
        throw const FormatException('Cursor inválido no catálogo de mídias.');
      }
    }
    final orphanedPaths = await _local.reconcileRemoteAssets(remoteIds);
    for (final orphanedPath in orphanedPaths) {
      final file = File(orphanedPath);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _downloadAsset(ExampleAsset asset) async {
    await _local.putAsset(
      asset.copyWith(status: ExampleAssetSyncStatus.downloading),
    );
    final response = await _http.send(
      http.Request('GET', Uri.parse(asset.remoteUrl!)),
    );
    if (response.statusCode != 200) {
      throw HttpException('Download retornou HTTP ${response.statusCode}.');
    }
    final directory = await _assetDirectory(asset.exampleId);
    final target = path.join(
      directory.path,
      '${asset.id}_${_safeFileName(asset.name)}',
    );
    final partial = File('$target.part');
    final sink = partial.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > _maxAssetSize) {
          throw const FileSystemException('Arquivo remoto maior que 15 MB.');
        }
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (asset.checksum != null) {
      final digest = (await sha256.bind(partial.openRead()).first).toString();
      if (digest != asset.checksum) {
        await partial.delete();
        throw const FormatException('Checksum do download inválido.');
      }
    }
    await partial.rename(target);
    await _local.putAsset(
      asset.copyWith(
        localPath: target,
        status: ExampleAssetSyncStatus.available,
        clearError: true,
      ),
    );
  }

  Future<Directory> _assetDirectory(String exampleId) async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(
      path.join(root.path, 'example_assets', exampleId),
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  String _safeFileName(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  Future<void> dispose() async {
    _remoteDebounce?.cancel();
    _retryTimer?.cancel();
    _listSubscription?.stop();
    await _remoteCollection?.cancel();
    await _connection?.cancel();
    _http.close();
  }
}

final exampleLocalStoreProvider = Provider<ExampleLocalStore>((ref) {
  final store = ExampleLocalStore();
  ref.onDispose(store.close);
  return store;
});

final exampleRepositoryProvider = Provider<ExampleRepository>((ref) {
  final repository = ExampleRepository(
    api: ref.watch(exampleApiProvider),
    localStore: ref.watch(exampleLocalStoreProvider),
    transport: ref.watch(meteorTransportProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});
