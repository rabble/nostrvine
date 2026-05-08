// ABOUTME: Verifies ExploreScreen syncs ?period= URL param into provider.
// ABOUTME: Covers deep-link reads, clearing on bare URL, and invalid input.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/popular_period_provider.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Minimal harness widget that exercises the production sync helper
/// inside a real `GoRouter`-driven build. We pump this instead of the
/// full [ExploreScreen] because the screen's provider surface is too
/// large to materialize in a unit test, but the URL → provider sync
/// logic itself lives in [syncPopularPeriodFromUrl] which we can test
/// in isolation.
class _SyncHarness extends ConsumerStatefulWidget {
  const _SyncHarness();

  @override
  ConsumerState<_SyncHarness> createState() => _SyncHarnessState();
}

class _SyncHarnessState extends ConsumerState<_SyncHarness> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncPopularPeriodFromUrl(context, ref);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  group('Explore Popular ?period= URL sync', () {
    Widget buildSubject({
      required GoRouter router,
      List<Override> overrides = const [],
    }) {
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    GoRouter buildRouter(String initialLocation) {
      return GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: '/explore/tab/:name',
            builder: (_, _) => const Scaffold(body: _SyncHarness()),
          ),
        ],
      );
    }

    ProviderContainer containerOf(WidgetTester tester) {
      final element = tester.element(find.byType(_SyncHarness));
      return ProviderScope.containerOf(element);
    }

    testWidgets('reads ?period=week into popularPeriodProvider', (
      tester,
    ) async {
      final router = buildRouter('/explore/tab/popular?period=week');
      await tester.pumpWidget(buildSubject(router: router));
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(popularPeriodProvider),
        equals(LeaderboardPeriod.week),
      );
    });

    testWidgets('reads ?period=today as LeaderboardPeriod.day (urlSlug)', (
      tester,
    ) async {
      final router = buildRouter('/explore/tab/popular?period=today');
      await tester.pumpWidget(buildSubject(router: router));
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(popularPeriodProvider),
        equals(LeaderboardPeriod.day),
      );
    });

    testWidgets(
      'clears popularPeriodProvider on /explore/tab/popular without query',
      (tester) async {
        final router = buildRouter('/explore/tab/popular?period=alltime');
        await tester.pumpWidget(
          buildSubject(
            router: router,
            overrides: [
              popularPeriodProvider.overrideWith(
                (_) => LeaderboardPeriod.alltime,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Sanity: starts on alltime.
        expect(
          containerOf(tester).read(popularPeriodProvider),
          equals(LeaderboardPeriod.alltime),
        );

        router.go('/explore/tab/popular');
        await tester.pumpAndSettle();

        expect(containerOf(tester).read(popularPeriodProvider), isNull);
      },
    );

    testWidgets('ignores invalid period values', (tester) async {
      final router = buildRouter('/explore/tab/popular?period=YEAR');
      await tester.pumpWidget(buildSubject(router: router));
      await tester.pumpAndSettle();

      expect(containerOf(tester).read(popularPeriodProvider), isNull);
    });
  });
}
