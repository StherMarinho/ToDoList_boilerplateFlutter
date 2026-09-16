import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/data/to_dos_api.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/domain/to_do.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_subscription.dart';

class ToDosRepository {
  ToDosRepository({required ToDosApi api}) : _api = api;

  final ToDosApi _api;
  MeteorSubscription? _listSubscription;
  MeteorSubscription? _detailSubscription;

  Stream<List<ToDo>> watchListTodos() => _api.observeList();

  Stream<int> watchFilteredTotal() => _api.observeFilteredTotal();

  Stream<ToDo?> watchDetailTodo(String id) => _api.observeDetail(id);

  ToDo? currentDetailById(String id) => _api.currentDetailById(id);

  Future<void> subscribeList({
    required String search,
    required ToDosStatusFilter status,
    required int page,
  }) async {
    // Para a subscription anterior antes de iniciar a nova
    // Isso força o servidor a limpar os documentos antigos do cache DDP
    _listSubscription?.stop();
    _listSubscription = null;

    // Pequena pausa para garantir que o teardown do servidor processou
    // os eventos 'removed' antes de iniciar a nova subscription
    await Future<void>.delayed(const Duration(milliseconds: 50));

    _listSubscription = _api.watchList(
      search: search,
      status: status,
      page: page,
    );
    await _listSubscription!.ready
        .firstWhere((ready) => ready)
        .timeout(const Duration(seconds: 12));
  }

  Future<ToDo?> subscribeDetail(String id) async {
    _detailSubscription?.stop();
    _detailSubscription = _api.watchDetail(id);
    await _detailSubscription!.ready
        .firstWhere((ready) => ready)
        .timeout(const Duration(seconds: 12));
    return _api.currentDetailById(id);
  }

  Future<String?> save(ToDo todo) => _api.save(todo);

  Future<ToggleCompletionResult> toggleCompletion(String id) {
    return _api.toggleCompletion(id);
  }

  Future<void> remove(String id) => _api.remove(id);

  void stopList() {
    _listSubscription?.stop();
    _listSubscription = null;
  }

  void stopDetail() {
    _detailSubscription?.stop();
    _detailSubscription = null;
  }

  void dispose() {
    _listSubscription?.stop();
    _detailSubscription?.stop();
  }
}

final toDosRepositoryProvider = Provider<ToDosRepository>((ref) {
  final repository = ToDosRepository(api: ref.watch(toDosApiProvider));
  ref.onDispose(repository.dispose);
  return repository;
});