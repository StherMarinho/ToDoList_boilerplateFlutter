import 'package:flutter_test/flutter_test.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/domain/to_do.dart';

void main() {
  group('ToDo.fromMeteor', () {
    test('converte campos básicos corretamente', () {
      final todo = ToDo.fromMeteor({
        '_id': 'todo-1',
        'description': 'Revisar checklist',
        'priority': 'alta',
        'personal': true,
        'completed': false,
        'createdby': 'user-1',
      });

      expect(todo.id, 'todo-1');
      expect(todo.description, 'Revisar checklist');
      expect(todo.priority, ToDoPriority.high);
      expect(todo.personal, isTrue);
      expect(todo.completed, isFalse);
      expect(todo.createdBy, 'user-1');
    });

    test('prioridade desconhecida vira medium', () {
      final todo = ToDo.fromMeteor({
        '_id': 'x',
        'description': 'teste',
        'priority': 'invalida',
      });
      expect(todo.priority, ToDoPriority.low);
    });

    test('campos ausentes não quebram o parser', () {
      final todo = ToDo.fromMeteor({'_id': 'x', 'description': 'teste'});
      expect(todo.personal, isFalse);
      expect(todo.completed, isFalse);
      expect(todo.deadline, isNull);
    });

    test('parseia data em formato ISO string', () {
      final todo = ToDo.fromMeteor({
        '_id': 'x',
        'description': 'teste',
        'priority': 'baixa',
        'deadline': '2025-12-31T00:00:00.000Z',
      });
      expect(todo.deadline, isNotNull);
      expect(todo.deadline!.year, 2025);
    });

    test('parseia data em formato \$date do EJSON', () {
      final todo = ToDo.fromMeteor({
        '_id': 'x',
        'description': 'teste',
        'priority': 'baixa',
        'deadline': {r'$date': '2025-06-15T00:00:00.000Z'},
      });
      expect(todo.deadline!.month, 6);
    });
  });

  group('ToDo.toEditableMeteorDocument', () {
    test('não inclui campos controlados pelo servidor', () {
      final todo = ToDo(
        id: 'todo-1',
        description: 'Minha tarefa',
        priority: ToDoPriority.high,
        completed: true,       // controlado pelo servidor
        completedAt: DateTime.now(), // controlado pelo servidor
        authorName: 'João',    // controlado pelo servidor
      );

      final doc = todo.toEditableMeteorDocument();

      expect(doc, isNot(contains('completed')));
      expect(doc, isNot(contains('completedAt')));
      expect(doc, isNot(contains('authorName')));
    });

    test('envia priority com wireValue, não com name do enum', () {
      final todo = ToDo(
        id: 'x',
        description: 'teste',
        priority: ToDoPriority.high,
      );
      final doc = todo.toEditableMeteorDocument();
      expect(doc['priority'], 'alta'); // não 'high'
    });

    test('envia prazo null explicitamente para remover no servidor', () {
      final todo = ToDo(
        id: 'x',
        description: 'teste',
        priority: ToDoPriority.low,
        deadline: null,
      );
      final doc = todo.toEditableMeteorDocument();
      expect(doc.containsKey('deadline'), isTrue);
      expect(doc['deadline'], isNull);
    });

    test('omite _id quando criando', () {
      final todo = ToDo(
        id: '',
        description: 'nova',
        priority: ToDoPriority.medium,
      );
      final doc = todo.toEditableMeteorDocument();
      expect(doc.containsKey('_id'), isFalse);
    });
  });

  group('ToDo.isOwnedBy', () {
    test('retorna true quando userId bate com createdBy', () {
      final todo = ToDo(
        id: 'x',
        description: 'teste',
        priority: ToDoPriority.medium,
        createdBy: 'user-42',
      );
      expect(todo.isOwnedBy('user-42'), isTrue);
      expect(todo.isOwnedBy('user-99'), isFalse);
      expect(todo.isOwnedBy(null), isFalse);
    });
  });

  group('ToDoPriority', () {
    test('wireValues são os contratos do servidor', () {
      expect(ToDoPriority.low.wireValue, 'baixa');
      expect(ToDoPriority.medium.wireValue, 'media');
      expect(ToDoPriority.high.wireValue, 'alta');
    });
  });
}