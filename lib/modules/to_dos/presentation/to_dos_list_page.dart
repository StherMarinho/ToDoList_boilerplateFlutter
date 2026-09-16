import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:synergia_flutter_meteor_boilerplate/app/auth/auth_providers.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/domain/to_do_resources.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/presentation/to_dos_controller.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/presentation/components/to_dos_body.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/presentation/components/to_dos_filters.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/presentation/components/to_dos_pagination.dart';
import 'package:synergia_flutter_meteor_boilerplate/shared/widgets/app_scaffold.dart';

class ToDosListPage extends ConsumerWidget {
  const ToDosListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreate = ref.watch(
      canAccessResourceProvider(ToDoResources.create),
    );

    ref.listen(
      toDosControllerProvider.select((s) => s.failure),
      (_, failure) {
        if (failure == null) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );

        ref.read(toDosControllerProvider.notifier).clearFailure();
      },
    );

    ref.listen(
      toDosControllerProvider.select((s) => s.message),
      (_, message) {
        if (message == null) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );

        ref.read(toDosControllerProvider.notifier).clearMessage();
      },
    );

    return AppScaffold(
      title: 'Minhas tarefas',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: () =>
              ref.read(toDosControllerProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/to-dos/new'),
              icon: const Icon(Icons.add),
              label: const Text('Nova tarefa'),
            )
          : null,
      body: Consumer(
        builder: (_, ref, _) {
          final state = ref.watch(toDosControllerProvider);

          return Column(
            children: [
              ToDosFilters(state: state),
              Expanded(
                child: ToDosBody(state: state),
              ),
              ToDosPagination(state: state),
            ],
          );
        },
      ),
    );
  }
}