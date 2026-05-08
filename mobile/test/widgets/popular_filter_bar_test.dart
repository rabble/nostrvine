// ABOUTME: Widget tests for the Popular tab time-window chip row.
// ABOUTME: Verifies labels, selected state, and URL-driven tap behavior.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/popular_period_provider.dart';
import 'package:openvine/widgets/popular_filter_bar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

void main() {
  group(PopularFilterBar, () {
    Widget buildSubject({
      List<Override> overrides = const [],
      String initialLocation = '/explore/tab/popular',
      GoRouter? router,
    }) {
      final config =
          router ??
          GoRouter(
            initialLocation: initialLocation,
            routes: [
              GoRoute(
                path: '/explore/tab/popular',
                builder: (_, _) => const Scaffold(body: PopularFilterBar()),
              ),
            ],
          );
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: config,
        ),
      );
    }

    testWidgets('renders 5 chips with localized labels', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(find.text(l10n.popularFilterRightNow), findsOneWidget);
      expect(find.text(l10n.popularFilterToday), findsOneWidget);
      expect(find.text(l10n.popularFilterWeek), findsOneWidget);
      expect(find.text(l10n.popularFilterMonth), findsOneWidget);
      expect(find.text(l10n.popularFilterAllTime), findsOneWidget);
    });

    testWidgets(
      'Right Now chip is selected when popularPeriodProvider is null',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            overrides: [
              popularPeriodProvider.overrideWith((_) => null),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final rightNow = tester.widget<ChoiceChip>(
          find.widgetWithText(
            ChoiceChip,
            lookupAppLocalizations(const Locale('en')).popularFilterRightNow,
          ),
        );
        expect(rightNow.selected, isTrue);

        final week = tester.widget<ChoiceChip>(
          find.widgetWithText(
            ChoiceChip,
            lookupAppLocalizations(const Locale('en')).popularFilterWeek,
          ),
        );
        expect(week.selected, isFalse);
      },
    );

    testWidgets(
      'Week chip is selected when period is LeaderboardPeriod.week',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            overrides: [
              popularPeriodProvider.overrideWith(
                (_) => LeaderboardPeriod.week,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        final week = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, l10n.popularFilterWeek),
        );
        expect(week.selected, isTrue);

        final rightNow = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, l10n.popularFilterRightNow),
        );
        expect(rightNow.selected, isFalse);
      },
    );

    testWidgets(
      'tapping the Month chip pushes /explore/tab/popular?period=month',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/explore/tab/popular',
          routes: [
            GoRoute(
              path: '/explore/tab/popular',
              builder: (_, _) => const Scaffold(body: PopularFilterBar()),
            ),
          ],
        );
        await tester.pumpWidget(buildSubject(router: router));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.popularFilterMonth));
        await tester.pumpAndSettle();

        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          equals('/explore/tab/popular?period=month'),
        );
      },
    );

    testWidgets(
      'tapping the Today chip uses urlSlug "today" not wireValue "day"',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/explore/tab/popular',
          routes: [
            GoRoute(
              path: '/explore/tab/popular',
              builder: (_, _) => const Scaffold(body: PopularFilterBar()),
            ),
          ],
        );
        await tester.pumpWidget(buildSubject(router: router));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.popularFilterToday));
        await tester.pumpAndSettle();

        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          equals('/explore/tab/popular?period=today'),
        );
      },
    );

    testWidgets(
      'tapping the Right Now chip removes the period query param',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/explore/tab/popular?period=week',
          routes: [
            GoRoute(
              path: '/explore/tab/popular',
              builder: (_, _) => const Scaffold(body: PopularFilterBar()),
            ),
          ],
        );
        await tester.pumpWidget(buildSubject(router: router));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.popularFilterRightNow));
        await tester.pumpAndSettle();

        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          equals('/explore/tab/popular'),
        );
      },
    );
  });
}
