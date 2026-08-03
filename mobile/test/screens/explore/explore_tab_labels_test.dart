// ABOUTME: Regression tests for shared Explore tab label resolution.
// ABOUTME: Covers feed-mode shell titles for every canonical Explore tab.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/screens/explore/explore_tab_labels.dart';

void main() {
  group('labelForExploreTabName', () {
    final l10n = AppLocalizationsEn();

    test('returns tab-bar labels for every canonical tab name', () {
      const state = ExploreTabsState(
        classicsAvailable: true,
        forYouAvailable: true,
        appsAvailable: true,
      );

      expect(
        state.tabNames.map((name) => labelForExploreTabName(l10n, name)),
        const [
          'Classics',
          'New',
          'Popular',
          'Categories',
          'For You',
          'Lists',
          'Integrated Apps',
        ],
      );
    });

    test('returns feed-mode shell titles for every canonical tab name', () {
      const state = ExploreTabsState(
        classicsAvailable: true,
        forYouAvailable: true,
        appsAvailable: true,
      );

      expect(
        state.tabNames.map(
          (name) => labelForExploreTabName(l10n, name, shellTitle: true),
        ),
        const [
          'Classics',
          'New Videos',
          'Trending',
          'Categories',
          'For You',
          'Lists',
          'Integrated Apps',
        ],
      );
    });
  });
}
