import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/presentation/to_dos_controller.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/presentation/components/to_do_card.dart';

class ToDosBody extends ConsumerWidget {
  const ToDosBody({
    super.key,
    required this.state,
  });

  final ToDosListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading && state.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(toDosControllerProvider.notifier).refresh(),
      child: state.items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(
                  height: 320,
                  child: Center(
                    child: Text('Nenhuma tarefa encontrada.'),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: state.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                return ToDoCard(
                  todo: state.items[index],
                );
              },
            ),
    );
  }
}