import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_api_base.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_subscription.dart';

/// Equivalente mobile do `ProductBase`: convenções CRUD e publicações do Web.
abstract class ProductMobileApiBase<T> extends MeteorApiBase<T> {
  const ProductMobileApiBase({
    required super.transport,
    required super.apiName,
    required super.decode,
    super.collectionName,
  });

  MeteorSubscription subscribeList({
    required String publication,
    Map<String, dynamic> filter = const {},
    Map<String, dynamic> options = const {},
  }) {
    return subscribe(publication, args: [filter, options]);
  }

  MeteorSubscription subscribeDetail({
    required String publication,
    required String id,
  }) {
    return subscribe(
      publication,
      args: [
        <String, dynamic>{'_id': id},
      ],
    );
  }

  MeteorSubscription subscribeCount({
    required String publication,
    Map<String, dynamic> filter = const {},
  }) {
    return subscribe('count$publication', args: [filter]);
  }

  Stream<int> observeCount(String publication) {
    return transport.collection('counts').map((documents) {
      final raw = documents['${publication}Total'];
      if (raw is Map && raw['count'] is num) {
        return (raw['count'] as num).toInt();
      }
      return 0;
    }).distinct();
  }

  Future<String?> insert(Map<String, dynamic> document) async {
    final result = await callMethod('insert', args: [document]);
    return result?.toString();
  }

  Future<void> update(Map<String, dynamic> document) async {
    await callMethod('update', args: [document]);
  }

  Future<void> upsert(Map<String, dynamic> document) async {
    await callMethod('upsert', args: [document]);
  }

  Future<void> remove(String id) async {
    await callMethod(
      'remove',
      args: [
        <String, dynamic>{'_id': id},
      ],
    );
  }

  Future<dynamic> sync(Map<String, dynamic> document) {
    return callMethod('sync', args: [document]);
  }
}
