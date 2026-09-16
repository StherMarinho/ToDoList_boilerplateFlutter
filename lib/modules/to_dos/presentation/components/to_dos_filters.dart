import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/data/to_dos_api.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/presentation/to_dos_controller.dart';

class ToDosFilters extends ConsumerWidget {
  const ToDosFilters({
    super.key,
    required this.state,
  });

  final ToDosListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(toDosControllerProvider.notifier);

    final searchField = TextField(
      maxLength: 80,
      onChanged: controller.setSearch,
      decoration: const InputDecoration(
        labelText: 'Buscar tarefa',
        prefixIcon: Icon(Icons.search),
        counterText: '',
        border: OutlineInputBorder(),
      ),
    );

    final statusField = DropdownButtonFormField<ToDosStatusFilter>(
      initialValue: state.status,
      decoration: const InputDecoration(
        labelText: 'Situação',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: ToDosStatusFilter.all,
          child: Text('Todas'),
        ),
        DropdownMenuItem(
          value: ToDosStatusFilter.open,
          child: Text('Abertas'),
        ),
        DropdownMenuItem(
          value: ToDosStatusFilter.completed,
          child: Text('Concluídas'),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          controller.setStatus(value);
        }
      },
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: LayoutBuilder(
        builder: (_, constraints) {
          if (constraints.maxWidth >= 640) {
            return Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                SizedBox(
                  width: 200,
                  child: statusField,
                ),
              ],
            );
          }

          return Column(
            children: [
              searchField,
              const SizedBox(height: 12),
              statusField,
            ],
          );
        },
      ),
    );
  }
}