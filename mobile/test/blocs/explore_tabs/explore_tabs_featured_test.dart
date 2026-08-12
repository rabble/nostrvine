// ABOUTME: Tests for splicing the server-configured featured tab into the
// ABOUTME: Explore tab order without shifting the user's selected tab.

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';

FeaturedTabConfig _featured({String? after, String? before}) {
  return FeaturedTabConfig(
    id: 'ft_a1b2c3d4',
    slug: 'featured-slug',
    label: const {'default': 'Featured'},
    position: FeaturedTabPosition(after: after, before: before),
    startsAt: null,
    endsAt: null,
    enabled: true,
    hasContent: true,
  );
}

void main() {
  group('ExploreTabsState featured tab', () {
    test('omits the tab entirely when none is configured', () {
      const state = ExploreTabsState();

      expect(state.tabNames, isNot(contains(exploreFeaturedTabName)));
    });

    test('places the tab directly after its named anchor', () {
      final state = ExploreTabsState(
        featuredTab: _featured(after: explorePopularTabName),
      );

      final names = state.tabNames;
      expect(
        names.indexOf(exploreFeaturedTabName),
        equals(names.indexOf(explorePopularTabName) + 1),
      );
    });

    test('places the tab directly before its named anchor', () {
      final state = ExploreTabsState(
        featuredTab: _featured(before: exploreListsTabName),
      );

      final names = state.tabNames;
      expect(
        names.indexOf(exploreFeaturedTabName) + 1,
        equals(names.indexOf(exploreListsTabName)),
      );
    });

    test('appends the tab when its anchor names an absent tab', () {
      final state = ExploreTabsState(
        featuredTab: _featured(after: exploreAppsTabName),
      );

      expect(state.tabNames.last, equals(exploreFeaturedTabName));
    });

    test('appends the tab when no anchor is configured', () {
      final state = ExploreTabsState(featuredTab: _featured());

      expect(state.tabNames.last, equals(exploreFeaturedTabName));
    });

    test('honours the anchor once an optional tab shifts indices', () {
      final state = ExploreTabsState(
        classicsAvailable: true,
        forYouAvailable: true,
        featuredTab: _featured(after: explorePopularTabName),
      );

      final names = state.tabNames;
      expect(
        names.indexOf(exploreFeaturedTabName),
        equals(names.indexOf(explorePopularTabName) + 1),
      );
    });

    test('counts the featured tab in the controller length', () {
      const without = ExploreTabsState();
      final with_ = ExploreTabsState(featuredTab: _featured());

      expect(with_.tabCount, equals(without.tabCount + 1));
    });

    test('keeps name lookup stable when the tab is added', () {
      const before = ExploreTabsState();
      final after = ExploreTabsState(
        featuredTab: _featured(after: exploreDefaultTabName),
      );

      // The user sitting on Lists must still resolve to Lists, not to the
      // tab that inherited its old index.
      final selected = before.nameForIndex(
        before.indexForName(exploreListsTabName),
      );
      expect(
        after.nameForIndex(after.indexForName(selected)),
        equals(exploreListsTabName),
      );
    });

    test('keeps name lookup stable when the tab is removed', () {
      final before = ExploreTabsState(
        featuredTab: _featured(after: exploreDefaultTabName),
      );
      const after = ExploreTabsState();

      final selected = before.nameForIndex(
        before.indexForName(exploreListsTabName),
      );
      expect(
        after.nameForIndex(after.indexForName(selected)),
        equals(exploreListsTabName),
      );
    });

    test('tracks the banner anchors past an inserted featured tab', () {
      final state = ExploreTabsState(
        featuredTab: _featured(before: exploreDefaultTabName),
      );

      expect(
        state.tabNames[state.newVideosIndex],
        equals(exploreDefaultTabName),
      );
      expect(
        state.tabNames[state.trendingIndex],
        equals(explorePopularTabName),
      );
    });

    test('clearing the configuration removes the tab', () {
      final state = ExploreTabsState(featuredTab: _featured());

      expect(
        state.copyWith(clearFeaturedTab: true).tabNames,
        isNot(contains(exploreFeaturedTabName)),
      );
    });

    test('preserves the featured tab when another field changes', () {
      final state = ExploreTabsState(featuredTab: _featured());

      expect(
        state.copyWith(classicsAvailable: true).featuredTab,
        equals(state.featuredTab),
      );
    });
  });
}
