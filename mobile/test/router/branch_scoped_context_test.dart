// ABOUTME: Proves each StatefulShellRoute branch sees its own scoped pageContext
// ABOUTME: so a kept-alive inactive branch keeps rendering its real content

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
            (ref) => Stream<RouteContext>.value(parseRoute(st.uri.path)),
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
    final scoped = ref.watch(pageContextProvider).asData?.value.type;
    return Text(
      '$label scoped=${scoped?.name ?? 'none'}',
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
  testWidgets('an inactive branch keeps its own scoped pageContext', (
    tester,
  ) async {
    final router = _buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('home scoped=home'), findsOneWidget);

    router.go('/explore');
    await tester.pumpAndSettle();

    // The newly active branch shows its own context...
    expect(find.text('explore scoped=explore'), findsOneWidget);
    // ...and the kept-alive home branch STILL renders its OWN content (it did
    // NOT blank to the active 'explore' route) — that is what gives the
    // cross-fade two live tabs to dissolve between.
    expect(find.text('home scoped=home'), findsOneWidget);
  });

  testWidgets('branch-scoped pageContext ignores query parameters', (
    tester,
  ) async {
    RouteContext? captured;
    final router = GoRouter(
      initialLocation:
          '/profile/npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqlz5yt?utm_source=test',
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
              initialLocation: '/profile/me',
              routes: [
                GoRoute(
                  path: '/profile/:npub',
                  pageBuilder: (context, state) => _scopedPage(
                    state,
                    Consumer(
                      builder: (context, ref, _) {
                        final ctx = ref
                            .watch(pageContextProvider)
                            .asData
                            ?.value;
                        if (ctx != null) captured = ctx;
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    final ctx = captured;
    expect(ctx, isNotNull);
    expect(ctx!.type, RouteType.profile);
    expect(
      ctx.npub,
      'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqlz5yt',
    );
  });
}
