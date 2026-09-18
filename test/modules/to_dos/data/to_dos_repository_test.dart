import 'package:flutter_test/flutter_test.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/data/to_dos_api.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/data/to_dos_repository.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/domain/to_do.dart';
import '../fakes/fake_meteor_transport.dart';

void main() {
  late FakeMeteorTransport transport;
  late ToDosApi api;
  late ToDosRepository repository;

  setUp(() {
    transport = FakeMeteorTransport();
    api = ToDosApi(transport: transport);
    repository = ToDosRepository(api: api);
  });

  tearDown(() {
    repository.dispose();
    transport.dispose();
  });

  group('watchListTodos', () {
    test('observa a lista através da API', () async {
      final stream = repository.watchListTodos();

      transport.emitToCollection('toDosListView', {
        'todo-1': {
          'description': 'Tarefa 1',
          'priority': 'alta',
        },
        'todo-2': {
          'description': 'Tarefa 2',
          'priority': 'baixa',
        },
      });

      final todos = await stream.first;

      expect(todos.length, 2);
      expect(todos.map((todo) => todo.id), containsAll(['todo-1', 'todo-2']));
    });
  });

  group('watchFilteredTotal', () {
    test('observa o total filtrado através da API', () async {
      final stream = repository.watchFilteredTotal();

      transport.emitToCollection('toDosListMeta', {
        'current': {
          'count': 5,
        },
      });

      final total = await stream.first;

      expect(total, 5);
    });
  });

  group('watchDetailTodo', () {
    test('observa o detalhe através da API', () async {
      final stream = repository.watchDetailTodo('todo-1');

      transport.emitToCollection('toDosDetailView', {
        'todo-1': {
          'description': 'Tarefa detalhada',
          'priority': 'media',
        },
      });

      final todo = await stream.first;

      expect(todo, isNotNull);
      expect(todo!.id, 'todo-1');
      expect(todo.description, 'Tarefa detalhada');
      expect(todo.priority, ToDoPriority.medium);
    });
  });

  group('currentDetailById', () {
    test('retorna o detalhe atual através da API', () {
      transport.emitToCollection('toDosDetailView', {
        'todo-1': {
          'description': 'Tarefa atual',
          'priority': 'alta',
        },
      });

      final todo = repository.currentDetailById('todo-1');

      expect(todo, isNotNull);
      expect(todo!.id, 'todo-1');
      expect(todo.description, 'Tarefa atual');
      expect(todo.priority, ToDoPriority.high);
    });

    test('retorna null quando o detalhe não existe', () {
      final todo = repository.currentDetailById('inexistente');

      expect(todo, isNull);
    });
  });

  group('subscribeList', () {
    test('cria subscription com os filtros corretos', () async {
      await repository.subscribeList(
        search: 'reunião',
        status: ToDosStatusFilter.open,
        page: 2,
      );

      final call = transport.lastCallTo('subscribe:toDosList')!;

      final args = call.args.first as Map<String, dynamic>;

      expect(args['search'], 'reunião');
      expect(args['status'], 'abertas');
      expect(args['page'], 2);
    });

    test('pode substituir a subscription anterior', () async {
      await repository.subscribeList(
        search: 'primeira',
        status: ToDosStatusFilter.all,
        page: 1,
      );

      await repository.subscribeList(
        search: 'segunda',
        status: ToDosStatusFilter.completed,
        page: 2,
      );

      final calls = transport.calls
          .where((call) => call.method == 'subscribe:toDosList')
          .toList();

      expect(calls.length, 2);

      final firstArgs = calls[0].args.first as Map<String, dynamic>;
      final secondArgs = calls[1].args.first as Map<String, dynamic>;

      expect(firstArgs['search'], 'primeira');
      expect(firstArgs['page'], 1);

      expect(secondArgs['search'], 'segunda');
      expect(secondArgs['status'], 'concluidas');
      expect(secondArgs['page'], 2);
    });
  });

  group('subscribeDetail', () {
    test('cria subscription e retorna o detalhe atual', () async {
      transport.emitToCollection('toDosDetailView', {
        'todo-42': {
          'description': 'Detalhe da tarefa',
          'priority': 'alta',
        },
      });

      final todo = await repository.subscribeDetail('todo-42');

      final call = transport.lastCallTo('subscribe:toDosDetail')!;

      expect(call.args.first, 'todo-42');
      expect(todo, isNotNull);
      expect(todo!.id, 'todo-42');
      expect(todo.description, 'Detalhe da tarefa');
    });
  });

  group('save', () {
    test('encaminha o save para a API', () async {
      transport.setMethodResponse('toDos.saveEditable', 'todo-10');

      final todo = ToDo(
        id: '',
        description: 'Nova tarefa',
        priority: ToDoPriority.medium,
      );

      final result = await repository.save(todo);

      expect(result, 'todo-10');

      final call = transport.lastCallTo('toDos.saveEditable')!;
      final document = call.args.first as Map<String, dynamic>;

      expect(document['description'], 'Nova tarefa');
      expect(document['priority'], 'media');
    });
  });

  group('toggleCompletion', () {
    test('encaminha a alteração de conclusão para a API', () async {
      transport.setMethodResponse('toDos.alternarConclusao', {
        'completed': true,
        'mensagem': 'Tarefa concluída com sucesso.',
      });

      final result = await repository.toggleCompletion('todo-20');

      expect(result.completed, isTrue);
      expect(result.message, 'Tarefa concluída com sucesso.');

      final call = transport.lastCallTo('toDos.alternarConclusao')!;

      expect(call.args.first, 'todo-20');
    });
  });

  group('remove', () {
    test('encaminha a remoção para a API', () async {
      await repository.remove('todo-30');

      final call = transport.lastCallTo('toDos.remove')!;

      expect((call.args.first as Map)['_id'], 'todo-30');
    });
  });

  group('stopList', () {
    test('pode parar a subscription da lista', () async {
      await repository.subscribeList(
        search: '',
        status: ToDosStatusFilter.all,
        page: 1,
      );

      repository.stopList();

      expect(true, isTrue);
    });
  });

  group('stopDetail', () {
    test('pode parar a subscription do detalhe', () async {
      await repository.subscribeDetail('todo-1');

      repository.stopDetail();

      expect(true, isTrue);
    });
  });

  group('dispose', () {
    test('pode encerrar as subscriptions', () async {
      await repository.subscribeList(
        search: '',
        status: ToDosStatusFilter.all,
        page: 1,
      );

      await repository.subscribeDetail('todo-1');

      repository.dispose();

      expect(true, isTrue);
    });
  });
}