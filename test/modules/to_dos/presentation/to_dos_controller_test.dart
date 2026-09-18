import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/data/to_dos_api.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/data/to_dos_repository.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/domain/to_do.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/presentation/to_dos_controller.dart';
import '../fakes/fake_meteor_transport.dart';

class FakeToDosRepository extends ToDosRepository {
  FakeToDosRepository()
      : super(api: ToDosApi(transport: FakeMeteorTransport()));

  final itemsController = StreamController<List<ToDo>>.broadcast();
  final totalController = StreamController<int>.broadcast();
  final subscribeCalls = <Map<String, dynamic>>[];

  String? removedId;
  String? toggledId;
  bool shouldFailSubscribe = false;
  bool shouldFailRemove = false;
  bool shouldFailToggle = false;

  ToggleCompletionResult toggleResult = const ToggleCompletionResult(
    completed: true,
    message: 'Tarefa concluída com sucesso.',
  );

  @override
  Stream<List<ToDo>> watchListTodos() {
    return itemsController.stream;
  }

  @override
  Stream<int> watchFilteredTotal() {
    return totalController.stream;
  }

  @override
  Future<void> subscribeList({
    required String search,
    required ToDosStatusFilter status,
    required int page,
  }) async {
    subscribeCalls.add({
      'search': search,
      'status': status,
      'page': page,
    });
    if (shouldFailSubscribe) {
      throw Exception('Erro ao carregar tarefas.');
    }
  }

  @override
  Future<void> remove(String id) async {
    if (shouldFailRemove) {
      throw Exception('Erro ao excluir tarefa.');
    }
    removedId = id;
  }

  @override
  Future<ToggleCompletionResult> toggleCompletion(String id) async {
    if (shouldFailToggle) {
      throw Exception('Erro ao concluir tarefa.');
    }
    toggledId = id;
    return toggleResult;
  }

  @override
  void stopList() {}

  void disposeFake() {
    itemsController.close();
    totalController.close();
  }
}

void main() {
  late ProviderContainer container;
  late FakeToDosRepository repository;
  late ProviderSubscription<ToDosListState> keepAlive;

  setUp(() {
    repository = FakeToDosRepository();
    container = ProviderContainer(
      overrides: [
        toDosRepositoryProvider.overrideWithValue(repository),
      ],
    );
    keepAlive = container.listen(
      toDosControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
  });

  tearDown(() {
    keepAlive.close();
    container.dispose();
    repository.disposeFake();
  });

  Future<ToDosController> createController() async {
    final controller = container.read(toDosControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    return controller;
  }

  group('estado inicial e carregamento', () {
    test('inicia e faz subscribe da lista', () async {
      final controller = container.read(toDosControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.page, 1);
      expect(controller.state.search, '');
      expect(controller.state.status, ToDosStatusFilter.all);
      expect(repository.subscribeCalls.length, 1);
      expect(repository.subscribeCalls.first['search'], '');
      expect(
        repository.subscribeCalls.first['status'],
        ToDosStatusFilter.all,
      );
      expect(repository.subscribeCalls.first['page'], 1);
      expect(controller.state.loading, isFalse);
    });
  });

  group('dados remotos', () {
    test('atualiza items quando o repository emite tarefas', () async {
      final controller = await createController();
      final todo = ToDo(
        id: 'todo-1',
        description: 'Estudar Flutter',
        priority: ToDoPriority.high,
      );

      repository.itemsController.add([todo]);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.items.length, 1);
      expect(controller.state.items.first.id, 'todo-1');
      expect(controller.state.items.first.description, 'Estudar Flutter');
    });

    test('atualiza total quando o repository emite o total', () async {
      final controller = await createController();

      repository.totalController.add(17);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.total, 17);
      expect(controller.state.pageCount, 5);
    });
  });

  group('setSearch', () {
    test('altera busca e volta para página 1', () async {
      final controller = await createController();
      repository.totalController.add(12);
      await Future<void>.delayed(Duration.zero);

      controller.goToPage(2);
      await Future<void>.delayed(Duration.zero);

      controller.setSearch('reunião');

      expect(controller.state.search, 'reunião');
      expect(controller.state.page, 1);
    });

    test('aguarda debounce antes de fazer nova busca', () async {
      final controller = await createController();
      final initialCalls = repository.subscribeCalls.length;

      controller.setSearch('teste');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repository.subscribeCalls.length, initialCalls);

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(repository.subscribeCalls.length, initialCalls + 1);
      expect(repository.subscribeCalls.last['search'], 'teste');
      expect(repository.subscribeCalls.last['page'], 1);
    });

    test('novo texto cancela o debounce anterior', () async {
      final controller = await createController();
      final initialCalls = repository.subscribeCalls.length;

      controller.setSearch('pri');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      controller.setSearch('primeira');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(repository.subscribeCalls.length, initialCalls + 1);
      expect(repository.subscribeCalls.last['search'], 'primeira');
    });
  });

  group('setStatus', () {
    test('altera status e volta para página 1', () async {
      final controller = await createController();
      repository.totalController.add(12);
      await Future<void>.delayed(Duration.zero);

      controller.goToPage(2);
      await Future<void>.delayed(Duration.zero);

      controller.setStatus(ToDosStatusFilter.completed);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, ToDosStatusFilter.completed);
      expect(controller.state.page, 1);
      expect(
        repository.subscribeCalls.last['status'],
        ToDosStatusFilter.completed,
      );
      expect(repository.subscribeCalls.last['page'], 1);
    });
  });

  group('paginação', () {
    test('avança para uma página válida', () async {
      final controller = await createController();
      repository.totalController.add(12);
      await Future<void>.delayed(Duration.zero);

      controller.goToPage(2);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.page, 2);
      expect(repository.subscribeCalls.last['page'], 2);
    });

    test('não permite página menor que 1', () async {
      final controller = await createController();
      repository.totalController.add(12);
      await Future<void>.delayed(Duration.zero);

      controller.goToPage(0);

      expect(controller.state.page, 1);
    });

    test('não permite página maior que o total de páginas', () async {
      final controller = await createController();
      repository.totalController.add(5);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.pageCount, 2);

      controller.goToPage(10);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.page, 2);
      expect(repository.subscribeCalls.last['page'], 2);
    });
  });

  group('remove', () {
    test('remove tarefa e apresenta mensagem de sucesso', () async {
      final controller = await createController();

      final result = await controller.remove('todo-10');

      expect(result, isTrue);
      expect(repository.removedId, 'todo-10');
      expect(
        controller.state.message,
        'Tarefa excluída com sucesso.',
      );
    });

    test('retorna false e registra falha quando remove falha', () async {
      final controller = await createController();
      repository.shouldFailRemove = true;

      final result = await controller.remove('todo-10');

      expect(result, isFalse);
      expect(controller.state.failure, isNotNull);
      expect(controller.state.loading, isFalse);
    });
  });

  group('toggleCompletion', () {
    test('conclui tarefa e atualiza a lista', () async {
      final controller = await createController();
      final callsBefore = repository.subscribeCalls.length;

      repository.toggleResult = const ToggleCompletionResult(
        completed: true,
        message: 'Tarefa concluída com sucesso.',
      );

      final result = await controller.toggleCompletion('todo-20');
      await Future<void>.delayed(Duration.zero);

      expect(result, isTrue);
      expect(repository.toggledId, 'todo-20');
      expect(repository.subscribeCalls.length, callsBefore + 1);
    });

    test('retorna false quando toggle falha', () async {
      final controller = await createController();
      repository.shouldFailToggle = true;

      final result = await controller.toggleCompletion('todo-20');

      expect(result, isFalse);
      expect(controller.state.failure, isNotNull);
      expect(controller.state.loading, isFalse);
    });
  });

  group('mensagens e falhas', () {
    test('clearMessage remove a mensagem atual', () async {
      final controller = await createController();

      await controller.remove('todo-1');
      expect(controller.state.message, isNotNull);

      controller.clearMessage();
      expect(controller.state.message, isNull);
    });

    test('clearFailure remove a falha atual', () async {
      final controller = await createController();
      repository.shouldFailRemove = true;

      await controller.remove('todo-1');
      expect(controller.state.failure, isNotNull);

      controller.clearFailure();
      expect(controller.state.failure, isNull);
    });

    test('falha ao assinar lista coloca loading como false', () async {
      repository.shouldFailSubscribe = true;

      final controller = container.read(toDosControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.loading, isFalse);
      expect(controller.state.failure, isNotNull);
    });
  });
}