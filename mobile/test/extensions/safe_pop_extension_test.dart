import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';

class _BackButtonScreen extends StatelessWidget {
  const _BackButtonScreen({this.fallback});
  final String? fallback;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TextButton(
        onPressed: fallback == null
            ? context.safePop
            : () => context.safePop(fallback: fallback),
        child: const Text('back'),
      ),
    );
  }
}

void main() {
  group('SafePopExtension', () {
    Widget homeScreen() => const Scaffold(body: Text('home'));

    testWidgets(
      'pops the current route when canPop is true',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => homeScreen(),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (_, _) => const _BackButtonScreen(),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        router.go('/home/detail');
        await tester.pumpAndSettle();

        expect(find.text('back'), findsOneWidget);

        await tester.tap(find.text('back'));
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
        expect(find.text('back'), findsNothing);
      },
    );

    test('default fallback is /home/0', () {
      expect(defaultSafePopFallback, equals('/home/0'));
    });

    testWidgets(
      'navigates to defaultSafePopFallback when canPop is false',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/key-management',
          routes: [
            GoRoute(
              path: defaultSafePopFallback,
              builder: (_, _) => homeScreen(),
            ),
            GoRoute(
              path: '/key-management',
              builder: (_, _) => const _BackButtonScreen(),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('back'), findsOneWidget);

        await tester.tap(find.text('back'));
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          equals(defaultSafePopFallback),
        );
      },
    );

    testWidgets(
      'navigates to custom fallback when provided',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/key-management',
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const Scaffold(body: Text('settings')),
            ),
            GoRoute(
              path: '/key-management',
              builder: (_, _) => const _BackButtonScreen(fallback: '/settings'),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        await tester.tap(find.text('back'));
        await tester.pumpAndSettle();

        expect(find.text('settings'), findsOneWidget);
      },
    );

    testWidgets(
      'tearoff is assignable to VoidCallback (e.g. onBackPressed)',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/key-management',
          routes: [
            GoRoute(
              path: '/home/0',
              builder: (_, _) => homeScreen(),
            ),
            GoRoute(
              path: '/key-management',
              builder: (context, _) => Scaffold(
                appBar: AppBar(
                  leading: BackButton(onPressed: context.safePop),
                ),
                body: const Text('key-management'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
      },
    );

    testWidgets(
      'does not throw GoError when stack is empty',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/key-management',
          routes: [
            GoRoute(
              path: '/home/0',
              builder: (_, _) => homeScreen(),
            ),
            GoRoute(
              path: '/key-management',
              builder: (_, _) => const _BackButtonScreen(),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        await tester.tap(find.text('back'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
