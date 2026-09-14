import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/domain/example.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_subscription.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_transport.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/product_mobile_api_base.dart';

class ExampleApi extends ProductMobileApiBase<Example> {
  const ExampleApi({required super.transport})
    : super(apiName: 'example', decode: Example.fromMeteor);

  static const listPublication = 'exampleList';
  static const detailPublication = 'exampleDetail';

  MeteorSubscription watchList({
    Map<String, dynamic> filter = const {},
    bool newestFirst = true,
  }) {
    return subscribeList(
      publication: listPublication,
      filter: filter,
      options: <String, dynamic>{
        'sort': <String, dynamic>{'createdat': newestFirst ? -1 : 1},
        'limit': 100,
      },
    );
  }

  MeteorSubscription watchListCount({Map<String, dynamic> filter = const {}}) {
    return subscribeCount(publication: listPublication, filter: filter);
  }

  MeteorSubscription watchDetail(String id) {
    return subscribeDetail(publication: detailPublication, id: id);
  }

  Stream<int> observeListCount() => observeCount(listPublication);

  Future<String?> save(Example example) {
    if (example.id.isEmpty) return insert(example.toMeteorDocument());
    return update(example.toMeteorDocument()).then((_) => example.id);
  }

  Future<Map<String, dynamic>> mobilePull({DateTime? since}) async {
    final result = await callMethod(
      'mobilePull',
      args: [
        <String, dynamic>{'since': ?since},
      ],
    );
    return result is Map ? Map<String, dynamic>.from(result) : const {};
  }

  Future<Map<String, dynamic>> uploadAssetChunk(
    Map<String, dynamic> chunk,
  ) async {
    final result = await callMethod('uploadAssetChunk', args: [chunk]);
    return result is Map ? Map<String, dynamic>.from(result) : const {};
  }

  Future<Map<String, dynamic>> mobileUpsert(Example example) async {
    final result = await callMethod(
      'mobileUpsert',
      args: [
        <String, dynamic>{
          'document': example.toMeteorDocument(),
          if (example.lastUpdate != null) 'baseVersion': example.lastUpdate,
        },
      ],
    );
    return result is Map ? Map<String, dynamic>.from(result) : const {};
  }

  Future<Map<String, dynamic>> mobileAssetsPage({
    String? fileCursor,
    String? legacyCursor,
    bool skipFiles = false,
    bool skipLegacy = false,
  }) async {
    final result = await callMethod(
      'mobileAssetsPage',
      args: [
        <String, dynamic>{
          'fileCursor': ?fileCursor,
          'legacyCursor': ?legacyCursor,
          'skipFiles': skipFiles,
          'skipLegacy': skipLegacy,
          'limit': 200,
        },
      ],
    );
    return result is Map ? Map<String, dynamic>.from(result) : const {};
  }

  Future<Example> mobileGet(String id) async {
    final result = await callMethod(
      'mobileGet',
      args: [
        <String, dynamic>{'_id': id},
      ],
    );
    if (result is! Map) {
      throw const FormatException('Documento remoto inválido.');
    }
    return Example.fromMeteor(Map<String, dynamic>.from(result));
  }

  Future<void> removeAsset(String assetId) async {
    await callMethod(
      'removeAsset',
      args: [
        <String, dynamic>{'assetId': assetId},
      ],
    );
  }
}

final exampleApiProvider = Provider<ExampleApi>((ref) {
  return ExampleApi(transport: ref.watch(meteorTransportProvider));
});
