import 'package:flutter_test/flutter_test.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/data/to_dos_api.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/domain/to_do.dart';
import '../fakes/fake_meteor_transport.dart';

void main() {
  late FakeMeteorTransport transport;
  late ToDosApi api;

  setUp(() {
    transport = FakeMeteorTransport();
    api = ToDosApi(transport: transport);
  });

  tearDown(() => transport.dispose());

  group('watchList', () {
    test('assina toDos.toDosList com search, status e page', () {
      api.watchList(
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

    test('omite search quando vazio', () {
      api.watchList(search: '', status: ToDosStatusFilter.all, page: 1);

      final call = transport.lastCallTo('subscribe:toDosList')!;
      final args = call.args.first as Map<String, dynamic>;

      expect(args.containsKey('search'), isFalse);
    });

    test('status wireValues batem com o contrato do servidor', () {
      for (final entry in {
        ToDosStatusFilter.all: 'todas',
        ToDosStatusFilter.open: 'abertas',
        ToDosStatusFilter.completed: 'concluidas',
      }.entries) {
        api.watchList(status: entry.key, page: 1);
        final call = transport.lastCallTo('subscribe:toDosList')!;
        final args = call.args.first as Map<String, dynamic>;
        expect(args['status'], entry.value,
            reason: '${entry.key} deve virar ${entry.value}');
      }
    });
  });

  group('observeList', () {
    test('emite lista a partir de toDosListView', () async {
      final stream = api.observeList();

      transport.emitToCollection('toDosListView', {
        'abc': {'description': 'Tarefa 1', 'priority': 'alta'},
        'xyz': {'description': 'Tarefa 2', 'priority': 'baixa'},
      });

      final items = await stream.first;
      expect(items.length, 2);
      expect(items.map((t) => t.id), containsAll(['abc', 'xyz']));
    });
  });

  group('observeFilteredTotal', () {
    test('extrai count do documento current de toDosListMeta', () async {
      final stream = api.observeFilteredTotal();

      transport.emitToCollection('toDosListMeta', {
        'current': {'count': 17},
      });

      final total = await stream.first;
      expect(total, 17);
    });

    test('retorna 0 quando não há documento current', () async {
      final stream = api.observeFilteredTotal();
      transport.emitToCollection('toDosListMeta', {});
      final total = await stream.first;
      expect(total, 0);
    });
  });

  group('watchDetail', () {
    test('assina toDos.toDosDetail com string pura, não mapa', () {
      api.watchDetail('todo-99');

      final call = transport.lastCallTo('subscribe:toDosDetail')!;
      expect(call.args.first, 'todo-99'); // string, não {'_id': 'todo-99'}
    });
  });

  group('save', () {
    test('cria chamando saveEditable sem _id', () async {
      transport.setMethodResponse('toDos.saveEditable', 'novo-id');

      final todo = ToDo(
        id: '',
        description: 'Nova tarefa',
        priority: ToDoPriority.medium,
      );

      final id = await api.save(todo);
      expect(id, 'novo-id');

      final call = transport.lastCallTo('toDos.saveEditable')!;
      final doc = call.args.first as Map<String, dynamic>;
      expect(doc.containsKey('_id'), isFalse);
    });

    test('edita chamando saveEditable com _id', () async {
      transport.setMethodResponse('toDos.saveEditable', 'todo-1');

      final todo = ToDo(
        id: 'todo-1',
        description: 'Editada',
        priority: ToDoPriority.high,
      );

      await api.save(todo);

      final call = transport.lastCallTo('toDos.saveEditable')!;
      final doc = call.args.first as Map<String, dynamic>;
      expect(doc['_id'], 'todo-1');
    });

    test('envia deadline null para remover prazo', () async {
      transport.setMethodResponse('toDos.saveEditable', 'todo-1');

      final todo = ToDo(
        id: 'todo-1',
        description: 'Sem prazo',
        priority: ToDoPriority.low,
        deadline: null,
      );

      await api.save(todo);

      final call = transport.lastCallTo('toDos.saveEditable')!;
      final doc = call.args.first as Map<String, dynamic>;
      expect(doc.containsKey('deadline'), isTrue);
      expect(doc['deadline'], isNull);
    });

    test('não envia completed nem authorName', () async {
      transport.setMethodResponse('toDos.saveEditable', 'todo-1');

      final todo = ToDo(
        id: 'todo-1',
        description: 'Teste',
        priority: ToDoPriority.medium,
        completed: true,
        authorName: 'Injetado',
      );

      await api.save(todo);

      final call = transport.lastCallTo('toDos.saveEditable')!;
      final doc = call.args.first as Map<String, dynamic>;
      expect(doc.containsKey('completed'), isFalse);
      expect(doc.containsKey('authorName'), isFalse);
    });
  });

  group('toggleCompletion', () {
    test('chama alternarConclusao com o id correto', () async {
      transport.setMethodResponse('toDos.alternarConclusao', {
        'completed': true,
        'mensagem': 'Tarefa concluída com sucesso.',
      });

      final result = await api.toggleCompletion('todo-42');

      final call = transport.lastCallTo('toDos.alternarConclusao')!;
      expect(call.args.first, 'todo-42');
      expect(result.completed, isTrue);
      expect(result.message, contains('concluída'));
    });
  });

  group('remove', () {
    test('chama toDos.remove com {_id}', () async {
      await api.remove('todo-33');

      final call = transport.lastCallTo('toDos.remove')!;
      expect((call.args.first as Map)['_id'], 'todo-33');
    });
  });
}