import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synergia_flutter_meteor_boilerplate/app/auth/auth_providers.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/domain/example.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/domain/example_resources.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/presentation/example_controller.dart';
import 'package:synergia_flutter_meteor_boilerplate/shared/widgets/app_scaffold.dart';

class ExampleListPage extends ConsumerWidget {
  const ExampleListPage({super.key});

  static const categories = ['Categoria A', 'Categoria B', 'Categoria C'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exampleControllerProvider);
    final canCreate = ref.watch(
      canAccessResourceProvider(ExampleResources.create),
    );
    ref.listen(exampleControllerProvider.select((value) => value.failure), (
      previous,
      next,
    ) {
      if (next == null || next == previous) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      ref.read(exampleControllerProvider.notifier).clearFailure();
    });

    return AppScaffold(
      title: 'Exemplos',
      actions: [
        IconButton(
          tooltip: state.newestFirst
              ? 'Mais antigos primeiro'
              : 'Mais novos primeiro',
          onPressed: ref.read(exampleControllerProvider.notifier).toggleSort,
          icon: Icon(state.newestFirst ? Icons.south : Icons.north),
        ),
        IconButton(
          tooltip: 'Atualizar',
          onPressed: ref.read(exampleControllerProvider.notifier).refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/examples/new'),
              icon: const Icon(Icons.add),
              label: const Text('Novo'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: ref.read(exampleControllerProvider.notifier).refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(child: _Filters(state: state)),
            ),
            if (state.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.examples.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Nenhum exemplo encontrado.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverList.separated(
                  itemCount: state.examples.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _ExampleCard(example: state.examples[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.state});

  final ExampleListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final search = TextField(
          onChanged: ref.read(exampleControllerProvider.notifier).setSearch,
          decoration: const InputDecoration(
            labelText: 'Buscar por nome',
            prefixIcon: Icon(Icons.search),
          ),
        );
        final category = DropdownButtonFormField<String>(
          initialValue: state.category,
          decoration: const InputDecoration(labelText: 'Categoria'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Todas')),
            ...ExampleListPage.categories.map(
              (value) => DropdownMenuItem(value: value, child: Text(value)),
            ),
          ],
          onChanged: ref.read(exampleControllerProvider.notifier).setCategory,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (constraints.maxWidth >= 640)
              Row(
                children: [
                  Expanded(flex: 2, child: search),
                  const SizedBox(width: 12),
                  Expanded(child: category),
                ],
              )
            else ...[
              search,
              const SizedBox(height: 12),
              category,
            ],
            const SizedBox(height: 8),
            Text(
              '${state.total} registro(s)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

class _ExampleCard extends ConsumerWidget {
  const _ExampleCard({required this.example});

  final Example example;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUpdate = ref.watch(
      canAccessResourceProvider(ExampleResources.update),
    );
    final canRemove = ref.watch(
      canAccessResourceProvider(ExampleResources.remove),
    );
    final priorityColor = switch (example.priority) {
      'alta' => Theme.of(context).colorScheme.error,
      'media' => Colors.orange,
      _ => Colors.green,
    };
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/examples/${example.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.inventory_2_outlined),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      example.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(example.type),
                        Text(
                          example.priority.isEmpty
                              ? 'Sem prioridade'
                              : example.priority,
                          style: TextStyle(
                            color: priorityColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: switch (example.syncStatus) {
                  ExampleSyncStatus.synced => 'Sincronizado',
                  ExampleSyncStatus.pending => 'Pendente de sincronização',
                  ExampleSyncStatus.syncing => 'Sincronizando',
                  ExampleSyncStatus.failed =>
                    example.syncError ?? 'Falha na sincronização',
                  ExampleSyncStatus.conflict => 'Conflito de edição',
                },
                child: Icon(
                  switch (example.syncStatus) {
                    ExampleSyncStatus.synced => Icons.cloud_done_outlined,
                    ExampleSyncStatus.pending => Icons.cloud_upload_outlined,
                    ExampleSyncStatus.syncing => Icons.sync,
                    ExampleSyncStatus.failed => Icons.cloud_off_outlined,
                    ExampleSyncStatus.conflict => Icons.warning_amber_rounded,
                  },
                  size: 20,
                  color: example.syncStatus == ExampleSyncStatus.failed
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              if (canUpdate || canRemove)
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'edit') {
                      context.push('/examples/${example.id}/edit');
                      return;
                    }
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Excluir exemplo?'),
                        content: Text('“${example.title}” será removido.'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      ref
                          .read(exampleControllerProvider.notifier)
                          .remove(example.id);
                    }
                  },
                  itemBuilder: (_) => [
                    if (canUpdate)
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    if (canRemove)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Excluir'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
