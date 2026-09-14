import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_error_mapper.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_subscription.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_transport.dart';

typedef MeteorDocumentDecoder<T> = T Function(Map<String, dynamic> document);

/// Equivalente mobile do `ApiBase` do boilerplate Web.
abstract class MeteorApiBase<T> {
  const MeteorApiBase({
    required this.transport,
    required this.apiName,
    required this.decode,
    String? collectionName,
  }) : collectionName = collectionName ?? apiName;

  final MeteorTransport transport;
  final String apiName;
  final String collectionName;
  final MeteorDocumentDecoder<T> decode;

  Stream<List<T>> observeCollection() {
    return transport.collection(collectionName).map((documents) {
      final result = <T>[];
      for (final entry in documents.entries) {
        try {
          final raw = Map<String, dynamic>.from(entry.value);
          raw.putIfAbsent('_id', () => entry.key);
          result.add(decode(raw));
        } catch (error) {
          throw MeteorErrorMapper.map(error);
        }
      }
      return result;
    });
  }

  T? currentById(String id) {
    final raw = transport.collectionValue(collectionName)[id];
    if (raw is! Map) return null;
    return decode(Map<String, dynamic>.from(raw));
  }

  MeteorSubscription subscribe(
    String publication, {
    List<dynamic> args = const [],
  }) {
    return transport.subscribe('$apiName.$publication', args: args);
  }

  Future<dynamic> callMethod(String method, {List<dynamic> args = const []}) {
    return transport.call('$apiName.$method', args: args);
  }
}
