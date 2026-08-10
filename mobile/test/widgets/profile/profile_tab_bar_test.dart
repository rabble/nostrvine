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

    Future<void> pumpBar(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      final controller = TabController(length: 3, vsync: tester);
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
                  tabs: tabsFor(lookupAppLocalizations(locale)),
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
