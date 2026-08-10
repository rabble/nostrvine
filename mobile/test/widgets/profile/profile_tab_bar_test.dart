import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/profile_tab_bar.dart';

void main() {
  group(ProfileTabBar, () {
    late AppLocalizations l10n;

    setUp(() => l10n = lookupAppLocalizations(const Locale('en')));

    List<ProfileTab> tabsFor(AppLocalizations l) => [
      (
        semanticId: SemanticIds.profileVideosTab,
        label: l.profileVideosLabel,
        icon: DivineIconName.play,
      ),
      (
        semanticId: SemanticIds.profileLikedTab,
        label: l.profileLikedLabel,
        icon: DivineIconName.heart,
      ),
      (
        semanticId: SemanticIds.profileCommentsTab,
        label: l.profileCommentsLabel,
        icon: DivineIconName.chatCircle,
      ),
    ];

    /// The own profile's full strip. This is the tightest layout the bar
    /// ships in, so it is what the icon-scaling test measures.
    List<ProfileTab> ownProfileTabsFor(AppLocalizations l) => [
      ...tabsFor(l),
      (
        semanticId: SemanticIds.profileCollabsTab,
        label: l.profileCollabsLabel,
        icon: DivineIconName.users,
      ),
      (
        semanticId: SemanticIds.profileRepostsTab,
        label: l.profileRepostsLabel,
        icon: DivineIconName.repeat,
      ),
      (
        semanticId: SemanticIds.profileListsTab,
        label: l.profileListsLabel,
        icon: DivineIconName.playlist,
      ),
    ];

    Future<void> pumpBar(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
      bool ownProfile = false,
    }) async {
      final tabs = ownProfile
          ? ownProfileTabsFor(lookupAppLocalizations(locale))
          : tabsFor(lookupAppLocalizations(locale));
      final controller = TabController(length: tabs.length, vsync: tester);
      addTearDown(controller.dispose);
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final headerKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(key: headerKey, height: 100),
                ),
                ProfileTabBar(
                  controller: controller,
                  scrollController: scrollController,
                  tabs: tabs,
                  headerKey: headerKey,
                  isRefreshing: false,
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 800)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Read the MERGED SemanticsData, not SemanticsNode.label. `.label` is the
    // node's own pre-merge config; Material's TabBar puts "Tab N of M" there
    // and merges the icon's label up, so only getSemanticsData() shows what
    // the platform accessibility bridge actually receives.
    String mergedLabel(WidgetTester tester, int index) => tester
        .getSemantics(find.byType(Tab).at(index))
        .getSemanticsData()
        .label;

    String mergedIdentifier(WidgetTester tester, int index) => tester
        .getSemantics(find.byType(Tab).at(index))
        .getSemanticsData()
        .identifier;

    testWidgets('announces the localized tab name, not the test anchor', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpBar(tester);

      // `contains`, not equality: Material prepends "Tab N of M", and N/M
      // differ between the own profile (6 tabs) and another profile (5).
      expect(mergedLabel(tester, 1), contains(l10n.profileLikedLabel));
      expect(mergedLabel(tester, 1), isNot(contains('liked_tab')));

      expect(mergedLabel(tester, 0), contains(l10n.profileVideosLabel));
      expect(mergedLabel(tester, 0), isNot(contains('videos_tab')));

      handle.dispose();
    });

    testWidgets('reads the name from l10n rather than a hardcoded string', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpBar(tester, locale: const Locale('de'));

      final de = lookupAppLocalizations(const Locale('de'));
      expect(mergedLabel(tester, 1), contains(de.profileLikedLabel));
      expect(mergedLabel(tester, 1), isNot(contains(l10n.profileLikedLabel)));

      handle.dispose();
    });

    testWidgets('scales its icons with the system text scale', (tester) async {
      // 360dp with all 6 own-profile tabs: the narrowest common phone at the
      // highest tab count, which is where a per-tab slot is tightest. A wider
      // surface or fewer tabs leaves so much slack that the assertion below
      // passes even when the shipping layout clamps the icon flat.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpBar(tester, ownProfile: true);
      final base = tester.getSize(find.byType(DivineIcon).first);

      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpBar(tester, ownProfile: true);
      final scaled = tester.getSize(find.byType(DivineIcon).first);

      // DivineIcon caps growth at maxScaleFactor (1.3x) so tight rows do not
      // overflow. A raw SvgPicture at a hardcoded size would not move at all.
      expect(scaled.width, greaterThan(base.width));
      expect(scaled.width, base.width * DivineIcon.maxScaleFactor);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the snake_case identifier as the E2E anchor', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpBar(tester);

      // The identifier survives Material's MergeSemantics, which is what lets
      // the label be localized without breaking test anchoring (#6948).
      expect(mergedIdentifier(tester, 0), SemanticIds.profileVideosTab);
      expect(mergedIdentifier(tester, 1), SemanticIds.profileLikedTab);
      expect(mergedIdentifier(tester, 2), SemanticIds.profileCommentsTab);

      handle.dispose();
    });
  });
}
