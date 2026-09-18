import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/domain/example.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/domain/example_asset.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_error_mapper.dart';

class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.attempts,
  });

  final int id;
  final String entityType;
  final String entityId;
  final String action;
  final int attempts;
}

/// Fonte de verdade local do módulo Example.
///
/// Todas as gravações de domínio e de fila são transacionais. A UI observa
/// este store, nunca diretamente a coleção efêmera do DDP.
class ExampleLocalStore {
  ExampleLocalStore({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactory,
      _databasePath = databasePath;

  final DatabaseFactory _factory;
  final String? _databasePath;
  final _changes = StreamController<void>.broadcast();
  Future<Database>? _databaseFuture;

  Future<Database> get database {
    final current = _databaseFuture;
    if (current != null) return current;
    final opening = _openDatabaseAndResetOnFailure();
    _databaseFuture = opening;
    return opening;
  }

  Future<Database> _openDatabaseAndResetOnFailure() async {
    try {
      return await _openDatabase();
    } catch (_) {
      _databaseFuture = null;
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final dbPath = _databasePath ?? await _defaultDatabasePath();
    return _factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE examples (
              id TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              sync_status TEXT NOT NULL,
              sync_error TEXT,
              deleted INTEGER NOT NULL DEFAULT 0,
              local_updated_at TEXT NOT NULL,
              server_updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE example_assets (
              id TEXT PRIMARY KEY,
              example_id TEXT NOT NULL,
              kind TEXT NOT NULL,
              name TEXT NOT NULL,
              mime_type TEXT NOT NULL,
              size INTEGER NOT NULL,
              local_path TEXT,
              remote_url TEXT,
              checksum TEXT,
              status TEXT NOT NULL,
              error TEXT,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE sync_queue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              action TEXT NOT NULL,
              attempts INTEGER NOT NULL DEFAULT 0,
              next_attempt_at TEXT,
              last_error TEXT,
              created_at TEXT NOT NULL,
              UNIQUE(entity_type, entity_id, action)
            )
          ''');
          await db.execute('''
            CREATE TABLE sync_metadata (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_assets_example ON example_assets(example_id)',
          );
          await db.execute(
            'CREATE INDEX idx_queue_retry ON sync_queue(next_attempt_at, id)',
          );
        },
      ),
    );
  }

  Future<String> _defaultDatabasePath() async {
    final directory = await getDatabasesPath();
    return path.join(directory, 'synergia_offline_v1.db');
  }

  Stream<List<Example>> watchExamples() async* {
    yield await listExamples();
    yield* _changes.stream.asyncMap((_) => listExamples());
  }

  Stream<Example?> watchExample(String id) async* {
    yield await getExample(id);
    yield* _changes.stream.asyncMap((_) => getExample(id));
  }

  Stream<List<ExampleAsset>> watchAssets(String exampleId) async* {
    yield await listAssets(exampleId);
    yield* _changes.stream.asyncMap((_) => listAssets(exampleId));
  }

  Future<List<ExampleAsset>> listAssets(String exampleId) async {
    final db = await database;
    final rows = await db.query(
      'example_assets',
      where: 'example_id = ?',
      whereArgs: [exampleId],
      orderBy: 'created_at',
    );
    return rows.map(_decodeAsset).toList();
  }

  Future<List<Example>> listExamples() async {
    final db = await database;
    final rows = await db.query(
      'examples',
      where: 'deleted = 0',
      orderBy: 'local_updated_at DESC',
    );
    final result = <Example>[];
    for (final row in rows) {
      result.add(await _decodeExample(db, row));
    }
    return result;
  }

  Future<Example?> getExample(String id) async {
    final db = await database;
    final rows = await db.query(
      'examples',
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _decodeExample(db, rows.first);
  }

  Future<void> saveLocal(Example example) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert('examples', {
        'id': example.id,
        'payload': jsonEncode(
          _jsonSafe({
            ...example.toMeteorDocument(),
            if (example.lastUpdate != null) 'lastupdate': example.lastUpdate,
            if (example.createdAt != null) 'createdat': example.createdAt,
          }),
        ),
        'sync_status': ExampleSyncStatus.pending.name,
        'sync_error': null,
        'deleted': 0,
        'local_updated_at': now,
        'server_updated_at': example.lastUpdate?.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _enqueueTxn(txn, 'example', example.id, 'upsert', now);
    });
    _notify();
  }

  Future<void> removeLocal(String id) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'examples',
        {
          'deleted': 1,
          'sync_status': ExampleSyncStatus.pending.name,
          'local_updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _enqueueTxn(txn, 'example', id, 'delete', now);
    });
    _notify();
  }

  Future<void> mergeRemote(Example remote) async {
    final db = await database;
    final current = await db.query(
      'examples',
      columns: ['sync_status', 'server_updated_at'],
      where: 'id = ?',
      whereArgs: [remote.id],
      limit: 1,
    );
    if (current.isNotEmpty &&
        current.first['sync_status'] != ExampleSyncStatus.synced.name) {
      // Local wins while queued. The server version is retained as the base
      // version and conflict is resolved explicitly during push.
      return;
    }
    await db.insert('examples', {
      'id': remote.id,
      'payload': jsonEncode(
        _jsonSafe({
          ...remote.toMeteorDocument(),
          if (remote.lastUpdate != null) 'lastupdate': remote.lastUpdate,
          if (remote.createdAt != null) 'createdat': remote.createdAt,
        }),
      ),
      'sync_status': ExampleSyncStatus.synced.name,
      'sync_error': null,
      'deleted': 0,
      'local_updated_at': (remote.lastUpdate ?? DateTime.now())
          .toUtc()
          .toIso8601String(),
      'server_updated_at': remote.lastUpdate?.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _notify();
  }

  Future<void> acceptRemoteConflict(Example remote) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'sync_queue',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: ['example', remote.id],
      );
      await txn.insert('examples', {
        'id': remote.id,
        'payload': jsonEncode(
          _jsonSafe({
            ...remote.toMeteorDocument(),
            if (remote.lastUpdate != null) 'lastupdate': remote.lastUpdate,
            if (remote.createdAt != null) 'createdat': remote.createdAt,
          }),
        ),
        'sync_status': ExampleSyncStatus.synced.name,
        'sync_error': null,
        'deleted': 0,
        'local_updated_at': DateTime.now().toUtc().toIso8601String(),
        'server_updated_at': remote.lastUpdate?.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    _notify();
  }

  Future<void> rebaseLocalConflict(String id, DateTime serverVersion) async {
    final db = await database;
    final rows = await db.query(
      'examples',
      columns: ['payload'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final payload = Map<String, dynamic>.from(
      jsonDecode(rows.first['payload'] as String) as Map,
    );
    payload['lastupdate'] = serverVersion.toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'examples',
        {
          'payload': jsonEncode(payload),
          'sync_status': ExampleSyncStatus.pending.name,
          'sync_error': null,
          'server_updated_at': serverVersion.toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'sync_queue',
        {'attempts': 0, 'next_attempt_at': null, 'last_error': null},
        where: 'entity_type = ? AND entity_id = ? AND action = ?',
        whereArgs: ['example', id, 'upsert'],
      );
    });
    _notify();
  }

  Future<void> applyRemoteDeletion(String id) async {
    final db = await database;
    final pending =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM sync_queue WHERE entity_type = ? AND entity_id = ?',
            ['example', id],
          ),
        ) ??
        0;
    if (pending > 0) return;
    await db.delete('examples', where: 'id = ?', whereArgs: [id]);
    _notify();
  }

  Future<void> updateServerVersion(String id, DateTime? version) async {
    if (version == null) return;
    final db = await database;
    final rows = await db.query(
      'examples',
      columns: ['payload'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final payload = Map<String, dynamic>.from(
      jsonDecode(rows.first['payload'] as String) as Map,
    );
    payload['lastupdate'] = version.toUtc().toIso8601String();
    await db.update(
      'examples',
      {
        'payload': jsonEncode(payload),
        'server_updated_at': version.toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> putAsset(ExampleAsset asset, {bool enqueue = false}) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert('example_assets', {
        'id': asset.id,
        'example_id': asset.exampleId,
        'kind': asset.kind.name,
        'name': asset.name,
        'mime_type': asset.mimeType,
        'size': asset.size,
        'local_path': asset.localPath,
        'remote_url': asset.remoteUrl,
        'checksum': asset.checksum,
        'status': asset.status.name,
        'error': asset.error,
        'created_at': asset.createdAt?.toUtc().toIso8601String() ?? now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (enqueue) {
        await _enqueueTxn(txn, 'asset', asset.id, 'upload', now);
      }
    });
    _notify();
  }

  Future<ExampleAsset?> getAsset(String id) async {
    final db = await database;
    final rows = await db.query(
      'example_assets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _decodeAsset(rows.first);
  }

  Future<void> removeAsset(String id, {bool enqueue = true}) async {
    final db = await database;
    final asset = await getAsset(id);
    if (asset == null) return;
    await db.transaction((txn) async {
      await txn.delete(
        'sync_queue',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: ['asset', id],
      );
      if (enqueue && asset.remoteUrl != null) {
        await _enqueueTxn(
          txn,
          'asset',
          id,
          'delete',
          DateTime.now().toUtc().toIso8601String(),
        );
        await txn.update(
          'example_assets',
          {'status': ExampleAssetSyncStatus.localOnly.name},
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await txn.delete('example_assets', where: 'id = ?', whereArgs: [id]);
      }
    });
    _notify();
  }

  Future<List<ExampleAsset>> assetsToAutoDownload() async {
    final db = await database;
    final rows = await db.query(
      'example_assets',
      where: 'kind != ? AND local_path IS NULL AND remote_url IS NOT NULL',
      whereArgs: [ExampleAssetKind.attachment.name],
    );
    return rows.map(_decodeAsset).toList();
  }

  Future<List<String>> reconcileRemoteAssets(Set<String> remoteIds) async {
    final db = await database;
    final where = remoteIds.isEmpty
        ? 'remote_url IS NOT NULL AND status = ?'
        : 'remote_url IS NOT NULL AND status = ? AND id NOT IN (${List.filled(remoteIds.length, '?').join(',')})';
    final args = <Object?>[
      ExampleAssetSyncStatus.available.name,
      if (remoteIds.isNotEmpty) ...remoteIds,
    ];
    final removedRows = await db.query(
      'example_assets',
      columns: ['local_path'],
      where: where,
      whereArgs: args,
    );
    if (remoteIds.isEmpty) {
      await db.delete('example_assets', where: where, whereArgs: args);
    } else {
      await db.delete('example_assets', where: where, whereArgs: args);
    }
    _notify();
    return removedRows
        .map((row) => row['local_path']?.toString())
        .whereType<String>()
        .toList();
  }

  Future<List<SyncQueueItem>> dueQueue({int limit = 20}) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await db.query(
      'sync_queue',
      where: 'next_attempt_at IS NULL OR next_attempt_at <= ?',
      whereArgs: [now],
      orderBy: 'id',
      limit: limit,
    );
    return rows
        .map(
          (row) => SyncQueueItem(
            id: row['id'] as int,
            entityType: row['entity_type'] as String,
            entityId: row['entity_id'] as String,
            action: row['action'] as String,
            attempts: row['attempts'] as int,
          ),
        )
        .toList();
  }

  Future<void> completeQueue(SyncQueueItem item) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sync_queue', where: 'id = ?', whereArgs: [item.id]);
      if (item.entityType == 'example' && item.action == 'upsert') {
        await txn.update(
          'examples',
          {'sync_status': ExampleSyncStatus.synced.name, 'sync_error': null},
          where: 'id = ?',
          whereArgs: [item.entityId],
        );
      } else if (item.entityType == 'example' && item.action == 'delete') {
        await txn.delete(
          'examples',
          where: 'id = ?',
          whereArgs: [item.entityId],
        );
      } else if (item.entityType == 'asset' && item.action == 'delete') {
        await txn.delete(
          'example_assets',
          where: 'id = ?',
          whereArgs: [item.entityId],
        );
      }
    });
    _notify();
  }

  Future<void> failQueue(SyncQueueItem item, Object error) async {
    final db = await database;
    final attempts = item.attempts + 1;
    final conflict = error is MeteorFailure && error.code == 'sync-conflict';
    final seconds = (1 << attempts.clamp(0, 8)).clamp(2, 300);
    final next = conflict
        ? DateTime.utc(9999).toIso8601String()
        : DateTime.now()
              .toUtc()
              .add(Duration(seconds: seconds))
              .toIso8601String();
    await db.update(
      'sync_queue',
      {
        'attempts': attempts,
        'next_attempt_at': next,
        'last_error': error.toString(),
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
    if (item.entityType == 'example') {
      await db.update(
        'examples',
        {
          'sync_status': conflict
              ? ExampleSyncStatus.conflict.name
              : ExampleSyncStatus.failed.name,
          'sync_error': error.toString(),
        },
        where: 'id = ?',
        whereArgs: [item.entityId],
      );
    } else {
      await db.update(
        'example_assets',
        {
          'status': ExampleAssetSyncStatus.failed.name,
          'error': error.toString(),
        },
        where: 'id = ?',
        whereArgs: [item.entityId],
      );
    }
    _notify();
  }

  Future<String?> getMetadata(String key) async {
    final db = await database;
    final rows = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setMetadata(String key, String value) async {
    final db = await database;
    await db.insert('sync_metadata', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _enqueueTxn(
    DatabaseExecutor db,
    String type,
    String id,
    String action,
    String now,
  ) async {
    await db.insert('sync_queue', {
      'entity_type': type,
      'entity_id': id,
      'action': action,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.update(
      'sync_queue',
      {'attempts': 0, 'next_attempt_at': null, 'last_error': null},
      where: 'entity_type = ? AND entity_id = ? AND action = ?',
      whereArgs: [type, id, action],
    );
  }

  Future<Example> _decodeExample(
    DatabaseExecutor db,
    Map<String, Object?> row,
  ) async {
    final payload = Map<String, dynamic>.from(
      jsonDecode(row['payload'] as String) as Map,
    );
    payload['_id'] = row['id'];
    payload['_syncStatus'] = row['sync_status'];
    payload['_syncError'] = row['sync_error'];
    final assetRows = await db.query(
      'example_assets',
      where: 'example_id = ?',
      whereArgs: [row['id']],
      orderBy: 'created_at',
    );
    payload['assets'] = assetRows
        .map(_decodeAsset)
        .map((asset) => asset.toMap())
        .toList();
    return Example.fromMeteor(payload);
  }

  ExampleAsset _decodeAsset(Map<String, Object?> row) {
    return ExampleAsset.fromMap({
      'id': row['id'],
      'exampleId': row['example_id'],
      'kind': row['kind'],
      'name': row['name'],
      'mimeType': row['mime_type'],
      'size': row['size'],
      'localPath': row['local_path'],
      'remoteUrl': row['remote_url'],
      'checksum': row['checksum'],
      'status': row['status'],
      'error': row['error'],
      'createdAt': row['created_at'],
    });
  }

  dynamic _jsonSafe(dynamic value) {
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _jsonSafe(item)),
      );
    }
    if (value is Iterable) return value.map(_jsonSafe).toList();
    return value;
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> close() async {
    final databaseFuture = _databaseFuture;
    Database? openedDatabase;
    if (databaseFuture != null) {
      try {
        openedDatabase = await databaseFuture;
      } catch (_) {
        // Não há banco aberto para fechar quando a inicialização falha.
      }
    }
    await openedDatabase?.close();
    await _changes.close();
  }
}