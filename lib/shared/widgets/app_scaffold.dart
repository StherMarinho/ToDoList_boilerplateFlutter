import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synergia_flutter_meteor_boilerplate/app/auth/auth_controller.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/user_profile/presentation/user_profile_providers.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_transport.dart';

class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.actions = const [],
    super.key,
  });

  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProfileProvider);
    final connected = ref.watch(meteorConnectedProvider);
    final location = GoRouterState.of(context).matchedLocation;

    final selectedIndex = switch (true) {
      _ when location.startsWith('/to-dos') => 1,
      _ => 0,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...actions,
          Tooltip(
            message: connected ? 'Meteor conectado' : 'Meteor desconectado',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.circle,
                size: 10,
                color: connected ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
      drawer: NavigationDrawer(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          Navigator.pop(context);
          switch (index) {
            case 0:
              context.go('/examples');
            case 1:
              context.go('/to-dos');
          }
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(
                    user?.displayName.characters.first.toUpperCase() ?? 'U',
                  ),
                ),
                const SizedBox(height: 12),
                Text(user?.displayName ?? 'Usuário'),
                if (user?.roles.isNotEmpty == true)
                  Text(
                    user!.roles.join(', '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.view_list_outlined),
            selectedIcon: Icon(Icons.view_list),
            label: Text('Exemplos'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.check_box_outlined),
            selectedIcon: Icon(Icons.check_box),
            label: Text('Tarefas'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: () {
              Navigator.pop(context);
              ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}