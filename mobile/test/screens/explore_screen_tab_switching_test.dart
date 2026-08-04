// ABOUTME: Unit tests for Explore tab selection persistence.
// ABOUTME: Ensures tab identity is stored by name instead of shifting index.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/providers/route_feed_providers.dart';

void main() {
  group('Explore tab selection', () {
    test('Tab name provider persists state across widget recreation', () {
      // Setup: Create container
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify initial state (default is New Videos by stable name)
      expect(container.read(exploreTabNameProvider), exploreDefaultTabName);

      // Simulate user switching to Trending.
      container.read(exploreTabNameProvider.notifier).state =
          explorePopularTabName;

      // Verify provider was updated
      expect(container.read(exploreTabNameProvider), explorePopularTabName);

      // The key insight: The provider state persists outside the widget lifecycle
      // When ExploreScreen is recreated (grid→feed navigation), it reads from
      // the provider and restores the tab name.

      // Simulate reading the persisted value (as ExploreScreen.initState would)
      final savedName = container.read(exploreTabNameProvider);
      expect(
        savedName,
        explorePopularTabName,
        reason: 'Tab name should persist in provider for widget to restore',
      );

      // Additional test: Verify switching tabs updates the provider
      container.read(exploreTabNameProvider.notifier).state =
          exploreCategoriesTabName;
      expect(container.read(exploreTabNameProvider), exploreCategoriesTabName);

      container.read(exploreTabNameProvider.notifier).state =
          exploreDefaultTabName;
      expect(container.read(exploreTabNameProvider), exploreDefaultTabName);
    });
  });
}
