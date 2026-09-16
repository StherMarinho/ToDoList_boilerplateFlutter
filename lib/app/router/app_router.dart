import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synergia_flutter_meteor_boilerplate/app/auth/auth_controller.dart';
import 'package:synergia_flutter_meteor_boilerplate/app/auth/auth_providers.dart';
import 'package:synergia_flutter_meteor_boilerplate/app/pages/login_page.dart';
import 'package:synergia_flutter_meteor_boilerplate/app/pages/no_permission_page.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/domain/example_resources.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/presentation/example_detail_page.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/example/presentation/example_list_page.dart';

import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/presentation/to_do_detail_page.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/to_dos/presentation/to_dos_list_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier();
  ref.listen<AuthState>(authControllerProvider, (_, _) => refresh.notify());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/no-permission',
        builder: (_, _) => const NoPermissionPage(),
      ),
      GoRoute(
        path: '/examples',
        builder: (_, _) => const ExampleListPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, _) =>
                const ExampleDetailPage(exampleId: null, editing: true),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => ExampleDetailPage(
              exampleId: state.pathParameters['id'],
              editing: false,
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, state) => ExampleDetailPage(
                  exampleId: state.pathParameters['id'],
                  editing: true,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/to-dos',
        builder: (_, _) => const ToDosListPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, _) => const ToDoDetailPage(
              todoId: null,
              editing: true,
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => ToDoDetailPage(
              todoId: state.pathParameters['id'],
              editing: false,
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, state) => ToDoDetailPage(
                  todoId: state.pathParameters['id'],
                  editing: true,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (_, routerState) {
      final auth = ref.read(authControllerProvider);
      final location = routerState.matchedLocation;
      if (auth.status == AuthStatus.bootstrapping) {
        return location == '/splash' ? null : '/splash';
      }
      if (!auth.isAuthenticated) {
        return location == '/login' ? null : '/login';
      }
      if (location == '/login' || location == '/splash') return '/examples';
      final canViewExamples = ref
          .read(accessControlPolicyProvider)
          .canAccessAny(auth.userProfile, const [ExampleResources.view]);
      if (location.startsWith('/examples') && !canViewExamples) {
        return '/no-permission';
      }
      if (location == '/no-permission' && canViewExamples) return '/examples';
      return null;
    },
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
