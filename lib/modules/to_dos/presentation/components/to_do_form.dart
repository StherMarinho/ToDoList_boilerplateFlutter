import 'package:flutter/material.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/domain/to_do.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/presentation/components/to_do_info_row.dart';

class ToDoForm extends StatelessWidget {
  const ToDoForm({
    required this.formKey,
    required this.descriptionController,
    required this.priority,
    required this.deadline,
    required this.personal,
    required this.todo,
    required this.canEdit,
    required this.onPriorityChanged,
    required this.onPickDeadline,
    required this.onRemoveDeadline,
    required this.onPersonalChanged,
    required this.formatDate,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController descriptionController;
  final ToDoPriority priority;
  final DateTime? deadline;
  final bool personal;
  final ToDo? todo;
  final bool canEdit;

  final ValueChanged<ToDoPriority?> onPriorityChanged;
  final VoidCallback onPickDeadline;
  final VoidCallback onRemoveDeadline;
  final ValueChanged<bool> onPersonalChanged;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: descriptionController,
              enabled: canEdit,
              minLines: 2,
              maxLines: 5,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final size = value?.trim().length ?? 0;

                if (size < 3 || size > 200) {
                  return 'Informe entre 3 e 200 caracteres.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ToDoPriority>(
              initialValue: priority,
              decoration: const InputDecoration(
                labelText: 'Prioridade',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final priority in ToDoPriority.values)
                  DropdownMenuItem(
                    value: priority,
                    child: Text(priority.label),
                  ),
              ],
              onChanged: canEdit ? onPriorityChanged : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    deadline != null
                        ? 'Prazo: ${formatDate(deadline!)}'
                        : 'Sem prazo definido',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (canEdit) ...[
                  TextButton.icon(
                    onPressed: onPickDeadline,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: const Text('Definir prazo'),
                  ),
                  if (deadline != null)
                    IconButton(
                      tooltip: 'Remover prazo',
                      onPressed: onRemoveDeadline,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: personal,
              onChanged: canEdit ? onPersonalChanged : null,
              title: const Text('Tarefa pessoal'),
              subtitle: const Text(
                'Somente você poderá visualizá-la.',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            if (todo != null) ...[
              const Divider(height: 32),
              if (todo!.authorName != null)
                ToDoInfoRow(
                  label: 'Criada por',
                  value: todo!.authorName!,
                ),
              if (todo!.createdAt != null)
                ToDoInfoRow(
                  label: 'Criada em',
                  value: formatDate(todo!.createdAt!),
                ),
              ToDoInfoRow(
                label: 'Situação',
                value: todo!.completed ? 'Concluída' : 'Aberta',
              ),
              if (todo!.completedAt != null)
                ToDoInfoRow(
                  label: 'Concluída em',
                  value: formatDate(todo!.completedAt!),
                ),
            ],
          ],
        ),
      ),
    );
  }
}