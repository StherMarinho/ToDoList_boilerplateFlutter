import 'package:flutter_test/flutter_test.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/domain/to_do.dart';

void main() {
  test('converte o contrato Meteor e preserva os nomes remotos', () {
    final todo = ToDo.fromMeteor({
      '_id': 'todo-1',
      'description': 'Revisar checklist',
      'priority': 'alta',
      'personal': true,
      'completed': false,
      'createdby': 'user-1',
    });

    expect(todo.priority, ToDoPriority.high);
    expect(todo.isOwnedBy('user-1'), isTrue);
    expect(
      todo.toEditableMeteorDocument(),
      containsPair('priority', 'alta'),
    );
    expect(
      todo.toEditableMeteorDocument(),
      isNot(contains('completed')),
    );
  });
}