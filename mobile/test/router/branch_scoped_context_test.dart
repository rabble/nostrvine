// ABOUTME: Proves each StatefulShellRoute branch sees its own scoped pageContext
// ABOUTME: while activeRouteTypeProvider stays global (so feeds can pause)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/router.dart';

/// Mirrors `_branchPage` in app_router.dart: scopes [pageContextProvider] to
/// this branch's own route so it doesn't read the globally-active route.
Page<void> _scopedPage(GoRouterState st, Widget child) =>
    NoTransitionPage<void>(
      key: st.pageKey,
      child: ProviderScope(
        overrides: [
          pageContextProvider.overrideWith(
            (ref) => Stream<RouteContext>.value(parseRoute(st.uri.toString())),
          ),
        ],
        child: child,
      ),
    );

class _Probe extends ConsumerWidget {
  const _Probe(this.label);

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Scoped: this branch's own route. Global: the actually-active tab.
    final scoped = ref.watch(pageContextProvider).asData?.value.type;
    final active = ref.watch(activeRouteTypeProvider).asData?.value;
    return Text(
      '$label scoped=${scoped?.name ?? 'none'} active=${active?.name ?? 'none'}',
      textDirection: TextDirection.ltr,
    );
  }
}

GoRouter _buildRouter() => GoRouter(
  initialLocation: '/home/0',
  routes: [
    StatefulShellRoute(
      builder: (context, state, shell) => shell,
      navigatorContainerBuilder: (context, shell, children) =>
          AppShellBranchContainer(
            currentIndex: shell.currentIndex,
            children: children,
          ),
      branches: [
        StatefulShellBranch(
          initialLocation: '/home/0',
          routes: [
            GoRoute(
              path: '/home/:index',
              pageBuilder: (context, state) =>
                  _scopedPage(state, const _Probe('home')),
            ),
          ],
        ),
        StatefulShellBranch(
          initialLocation: '/explore',
          routes: [
            GoRoute(
              path: '/explore',
              pageBuilder: (context, state) =>
                  _scopedPage(state, const _Probe('explore')),
            ),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets(
    'inactive branch keeps its scoped context; active type stays global',
    (tester) async {
      final router = _buildRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          // activeRouteTypeProvider derives from goRouterProvider, so point it
          // at the test router.
          overrides: [goRouterProvider.overrideWithValue(router)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // On home: home branch sees its own route AND is the active tab.
      expect(find.text('home scoped=home active=home'), findsOneWidget);

      router.go('/explore');
      await tester.pumpAndSettle();

      // Active branch: its own route, and it is the active tab.
      expect(
        find.text('explore scoped=explore active=explore'),
        findsOneWidget,
      );
      // Kept-alive home branch: still renders its OWN content (scoped=home) so
      // the cross-fade has something to dissolve, but knows it is NOT the
      // active tab (active=explore) — which is what lets the home feed pause.
      expect(find.text('home scoped=home active=explore'), findsOneWidget);
    },
  );
}
