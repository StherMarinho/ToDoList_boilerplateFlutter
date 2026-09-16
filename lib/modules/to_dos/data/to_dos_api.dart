import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/domain/to_do.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_subscription.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_transport.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/product_mobile_api_base.dart';

enum ToDosStatusFilter { all, open, completed }

extension ToDosStatusFilterWire on ToDosStatusFilter {
  String get wireValue => switch (this) {
    ToDosStatusFilter.all => 'todas',
    ToDosStatusFilter.open => 'abertas',
    ToDosStatusFilter.completed => 'concluidas',
  };
}

class ToggleCompletionResult {
  const ToggleCompletionResult({
    required this.completed,
    required this.message,
  });

  factory ToggleCompletionResult.fromMap(Map<String, dynamic> map) {
    return ToggleCompletionResult(
      completed: map['completed'] == true,
      message: map['mensagem']?.toString() ?? 'Tarefa atualizada.',
    );
  }

  final bool completed;
  final String message;
}

class ToDosApi extends ProductMobileApiBase<ToDo> {
  const ToDosApi({required super.transport})
    : super(apiName: 'toDos', decode: ToDo.fromMeteor);

  MeteorSubscription watchList({
    String search = '',
    ToDosStatusFilter status = ToDosStatusFilter.all,
    int page = 1,
  }) {
    return subscribe(
      'toDosList',
      args: [
        <String, dynamic>{
          if (search.trim().isNotEmpty) 'search': search.trim(),
          'status': status.wireValue,
          'page': page,
        },
      ],
    );
  }

  Stream<List<ToDo>> observeList() {
    return transport.collection('toDosListView').map((documents) {
      return [
        for (final entry in documents.entries)
          decode(<String, dynamic>{
            ...Map<String, dynamic>.from(entry.value as Map),
            '_id': entry.key,
          }),
      ];
    });
  }

  Stream<int> observeFilteredTotal() {
    return transport.collection('toDosListMeta').map((documents) {
      final raw = documents['current'];
      return raw is Map && raw['count'] is num
          ? (raw['count'] as num).toInt()
          : 0;
    }).distinct();
  }

  MeteorSubscription watchDetail(String id) {
    return subscribe('toDosDetail', args: [id]);
  }

  Stream<ToDo?> observeDetail(String id) {
    return transport.collection('toDosDetailView').map((documents) {
      return _detailFrom(documents, id);
    }).distinct();
  }

  ToDo? currentDetailById(String id) {
    return _detailFrom(transport.collectionValue('toDosDetailView'), id);
  }

  ToDo? _detailFrom(Map<String, dynamic> documents, String id) {
    final raw = documents[id];
    if (raw is! Map) return null;
    return decode(<String, dynamic>{
      ...Map<String, dynamic>.from(raw),
      '_id': id,
    });
  }

  Future<String?> save(ToDo todo) async {
    final result = await callMethod(
      'saveEditable',
      args: [todo.toEditableMeteorDocument()],
    );
    return result?.toString();
  }

  Future<ToggleCompletionResult> toggleCompletion(String id) async {
    final result = await callMethod('alternarConclusao', args: [id]);
    if (result is! Map) {
      throw const FormatException('Resposta inválida ao alterar conclusão.');
    }
    return ToggleCompletionResult.fromMap(Map<String, dynamic>.from(result));
  }
}

final toDosApiProvider = Provider<ToDosApi>((ref) {
  return ToDosApi(transport: ref.watch(meteorTransportProvider));
});
