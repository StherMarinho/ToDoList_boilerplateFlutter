import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:synergia_flutter_meteor_boilerplate/app/auth/auth_providers.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/domain/to_do.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/domain/to_do_resources.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/presentation/to_dos_controller.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/user_profile/presentation/user_profile_providers.dart';

class ToDoCard extends ConsumerWidget {
  const ToDoCard({
    super.key,
    required this.todo,
  });

  final ToDo todo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);

    final owns = todo.isOwnedBy(profile?.id);

    final canUpdate = owns &&
        ref.watch(
          canAccessResourceProvider(ToDoResources.update),
        );

    final canRemove = owns &&
        ref.watch(
          canAccessResourceProvider(ToDoResources.remove),
        );

    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final priorityColor = switch (todo.priority) {
      ToDoPriority.high => colors.error,
      ToDoPriority.medium => Colors.amber,
      ToDoPriority.low => colors.secondary,
    };

    final now = DateTime.now();

    final overdue = todo.deadline != null &&
        !todo.completed &&
        todo.deadline!.isBefore(now);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              todo.description,
              style: textTheme.bodyLarge?.copyWith(
                decoration: todo.completed
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    todo.priority.label,
                    style: textTheme.labelSmall?.copyWith(
                      color: priorityColor,
                    ),
                  ),
                ),
                if (todo.personal) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Tarefa pessoal',
                    child: Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: colors.outline,
                    ),
                  ),
                ],
              ],
            ),
            if (todo.deadline != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: overdue
                        ? colors.error
                        : colors.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(todo.deadline!),
                    style: textTheme.labelSmall?.copyWith(
                      color: overdue
                          ? colors.error
                          : colors.outline,
                    ),
                  ),
                  if (overdue) ...[
                    const SizedBox(width: 4),
                    Text(
                      '· Atrasada',
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (todo.authorName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Por ${todo.authorName}',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.outline,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Ver detalhes',
                  onPressed: () =>
                      context.push('/to-dos/${todo.id}'),
                  icon: const Icon(
                    Icons.visibility_outlined,
                  ),
                ),
                if (canUpdate)
                  IconButton(
                    tooltip: todo.completed
                        ? 'Reabrir tarefa'
                        : 'Concluir tarefa',
                    onPressed: () => ref
                        .read(toDosControllerProvider.notifier)
                        .toggleCompletion(todo.id),
                    icon: Icon(
                      todo.completed
                          ? Icons.refresh
                          : Icons.check_circle_outline,
                    ),
                  ),
                if (canUpdate)
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: () => context.push(
                      '/to-dos/${todo.id}/edit',
                    ),
                    icon: const Icon(
                      Icons.edit_outlined,
                    ),
                  ),
                if (canRemove)
                  IconButton(
                    tooltip: 'Excluir',
                    onPressed: () =>
                        _confirmRemove(context, ref),
                    icon: Icon(
                      Icons.delete_outline,
                      color: colors.error,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir tarefa?'),
        content: Text(
          '"${todo.description}" será removida permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref
          .read(toDosControllerProvider.notifier)
          .remove(todo.id);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}