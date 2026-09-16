import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/presentation/to_dos_controller.dart';

class ToDosPagination extends ConsumerWidget {
  const ToDosPagination({
    super.key,
    required this.state,
  });

  final ToDosListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      toDosControllerProvider.notifier,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Página anterior',
            onPressed: state.page > 1
                ? () => controller.goToPage(
                      state.page - 1,
                    )
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${state.page} de ${state.pageCount}',
          ),
          IconButton(
            tooltip: 'Próxima página',
            onPressed: state.page < state.pageCount
                ? () => controller.goToPage(
                      state.page + 1,
                    )
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}