// ABOUTME: Widget test that a GoRouter using universalLinkToRouterPath in its
// ABOUTME: top-level redirect lands on the internal screen for a universal link

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/universal_link_resolver.dart';

class _SearchProbe extends StatelessWidget {
  const _SearchProbe({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) => Text('SEARCH:$query');
}

class _HomeProbe extends StatelessWidget {
  const _HomeProbe();

  @override
  Widget build(BuildContext context) => const Text('HOME');
}

GoRouter _buildRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) => universalLinkToRouterPath(state.uri),
    routes: [
      GoRoute(
        path: '/home/:index',
        builder: (_, _) => const _HomeProbe(),
      ),
      GoRoute(
        path: '/search-results/:query',
        builder: (_, state) => _SearchProbe(
          query: Uri.decodeComponent(state.pathParameters['query'] ?? ''),
        ),
      ),
    ],
  );
}

void main() {
  testWidgets(
    'top-level redirect rewrites a /search/:term universal link to '
    '/search-results/:term and renders the internal screen',
    (tester) async {
      final router = _buildRouter(
        initialLocation: 'https://divine.video/search/music',
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('SEARCH:music'), findsOneWidget);
      expect(find.text('HOME'), findsNothing);
    },
  );

  testWidgets(
    'non-divine.video URIs fall through unchanged and reach a normal route',
    (tester) async {
      final router = _buildRouter(initialLocation: '/home/0');
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    },
  );
}
