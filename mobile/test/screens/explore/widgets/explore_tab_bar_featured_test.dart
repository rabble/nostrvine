// ABOUTME: Widget tests for the featured tab's presence in the Explore bar.
// ABOUTME: Absent means absent — no placeholder, no disabled tab.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/explore/widgets/explore_tab_bar.dart';

FeaturedTabConfig _featured({
  Map<String, String> label = const {'default': 'Featured'},
  Map<String, String> disclosureLabel = const {},
  String? after = explorePopularTabName,
}) {
  return FeaturedTabConfig(
    id: 'ft_a1b2c3d4',
    slug: 'featured-slug',
    label: label,
    disclosureLabel: disclosureLabel,
    position: FeaturedTabPosition(after: after),
    startsAt: null,
    endsAt: null,
    enabled: true,
    hasContent: true,
  );
}

void main() {
  group('$ExploreTabBar featured tab', () {
    Future<void> pumpBar(
      WidgetTester tester,
      ExploreTabsState tabsState,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DefaultTabController(
            length: tabsState.tabCount,
            child: Builder(
              builder: (context) => Scaffold(
                body: ExploreTabBar(
                  controller: DefaultTabController.of(context),
                  tabsState: tabsState,
                  onTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders no featured tab when none is configured', (
      tester,
    ) async {
      await pumpBar(tester, const ExploreTabsState());

      expect(find.text('Featured'), findsNothing);
      expect(find.byType(Tab), findsNWidgets(4));
    });

    testWidgets('renders the configured label as a tab', (tester) async {
      await pumpBar(tester, ExploreTabsState(featuredTab: _featured()));

      expect(find.text('Featured'), findsOneWidget);
    });

    testWidgets('places the tab after its configured anchor', (tester) async {
      final state = ExploreTabsState(featuredTab: _featured());
      await pumpBar(tester, state);

      final popularX = tester.getCenter(find.text('Popular')).dx;
      final featuredX = tester.getCenter(find.text('Featured')).dx;
      final categoriesX = tester.getCenter(find.text('Categories')).dx;

      expect(featuredX, greaterThan(popularX));
      expect(featuredX, lessThan(categoriesX));
    });

    testWidgets('renders the disclosure marker when the server sends one', (
      tester,
    ) async {
      await pumpBar(
        tester,
        ExploreTabsState(
          featuredTab: _featured(
            disclosureLabel: const {'default': 'Sponsored'},
          ),
        ),
      );

      expect(find.text('Sponsored'), findsOneWidget);
    });

    testWidgets('renders nothing extra when no disclosure is configured', (
      tester,
    ) async {
      await pumpBar(tester, ExploreTabsState(featuredTab: _featured()));

      // The label renders bare, not wrapped in the marker Row the disclosure
      // path builds.
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Featured'),
            matching: find.byType(Tab),
          ),
          matching: find.byType(Row),
        ),
        findsNothing,
      );
    });

    testWidgets('truncates an overlong label at the narrowest width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpBar(
        tester,
        ExploreTabsState(featuredTab: _featured(label: {'default': 'x' * 200})),
      );

      expect(find.textContaining('…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('drops the tab again when the configuration is cleared', (
      tester,
    ) async {
      await pumpBar(tester, ExploreTabsState(featuredTab: _featured()));
      expect(find.text('Featured'), findsOneWidget);

      await pumpBar(tester, const ExploreTabsState());

      expect(find.text('Featured'), findsNothing);
    });
  });
}
