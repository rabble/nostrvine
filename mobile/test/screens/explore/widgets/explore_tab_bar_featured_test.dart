// ABOUTME: Widget tests for the featured tab's presence in the Explore bar.
// ABOUTME: Absent means absent — no placeholder, no disabled tab.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/explore/widgets/explore_tab_bar.dart';

FeaturedTabConfig _featured({
  Map<String, String> label = const {'default': 'Featured'},
  Map<String, String> pillLabel = const {'default': 'Skate Week'},
  Map<String, String> disclosureLabel = const {},
}) {
  return FeaturedTabConfig(
    id: 'ft_a1b2c3d4',
    slug: 'featured-slug',
    label: label,
    pillLabel: pillLabel,
    disclosureLabel: disclosureLabel,
    startsAt: null,
    endsAt: null,
    enabled: true,
    hasContent: true,
  );
}

/// Colour the pill's text is painted in, which is what separates the
/// sponsored state from the unsponsored one.
Color? _pillTextColor(WidgetTester tester, String pillText) =>
    tester.widget<Text>(find.text(pillText)).style?.color;

void main() {
  group('$ExploreTabBar featured tab', () {
    Future<void> pumpBar(
      WidgetTester tester,
      ExploreTabsState tabsState,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
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

    testWidgets('places the tab between New and Popular', (tester) async {
      await pumpBar(tester, ExploreTabsState(featuredTab: _featured()));

      final newX = tester.getCenter(find.text('New')).dx;
      final featuredX = tester.getCenter(find.text('Featured')).dx;
      final popularX = tester.getCenter(find.text('Popular')).dx;

      expect(featuredX, greaterThan(newX));
      expect(featuredX, lessThan(popularX));
    });

    testWidgets('renders the collection name in a pill beside the label', (
      tester,
    ) async {
      await pumpBar(tester, ExploreTabsState(featuredTab: _featured()));

      expect(find.text('Featured'), findsOneWidget);
      expect(find.text('Skate Week'), findsOneWidget);
    });

    testWidgets('renders no pill when the server sends no pill label', (
      tester,
    ) async {
      await pumpBar(
        tester,
        ExploreTabsState(featuredTab: _featured(pillLabel: const {})),
      );

      expect(find.text('Featured'), findsOneWidget);
      expect(find.text('Skate Week'), findsNothing);
    });

    testWidgets('tints the pill yellow when the collection is unsponsored', (
      tester,
    ) async {
      await pumpBar(tester, ExploreTabsState(featuredTab: _featured()));

      expect(
        _pillTextColor(tester, 'Skate Week'),
        equals(VineTheme.darkColors.accentChipYellow.onContainer),
      );
    });

    testWidgets('tints the pill pink when a sponsor is configured', (
      tester,
    ) async {
      await pumpBar(
        tester,
        ExploreTabsState(
          featuredTab: _featured(
            disclosureLabel: const {'default': 'Acme Bikes'},
          ),
        ),
      );

      expect(
        _pillTextColor(tester, 'Skate Week'),
        equals(VineTheme.darkColors.accentChipPink.onContainer),
      );
    });

    testWidgets('speaks the sponsored state rather than relying on colour', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpBar(
        tester,
        ExploreTabsState(
          featuredTab: _featured(
            disclosureLabel: const {'default': 'Acme Bikes'},
          ),
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      // Matched as a substring: Tab merges its children into one node, so the
      // pill's label arrives joined to the tab's own.
      expect(
        find.bySemanticsLabel(
          RegExp(
            RegExp.escape(
              l10n.exploreFeaturedSponsoredPillSemanticLabel('Skate Week'),
            ),
          ),
        ),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('truncates an overlong pill harder than the label', (
      tester,
    ) async {
      await pumpBar(
        tester,
        ExploreTabsState(
          featuredTab: _featured(pillLabel: {'default': 'x' * 40}),
        ),
      );

      // 16 graphemes, the last of which is the ellipsis.
      expect(find.text('${'x' * 15}…'), findsOneWidget);
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

      expect(find.textContaining('…'), findsWidgets);
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
