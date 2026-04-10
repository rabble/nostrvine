// ABOUTME: Tests that tab history correctly preserves the originating tab
// ABOUTME: when navigating to search, so back-nav returns to the right tab

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/providers/providers.dart';

void main() {
  group('TabHistory search back-navigation', () {
    late StreamController<RouteContext> contextController;
    late ProviderContainer container;

    setUp(() {
      contextController = StreamController<RouteContext>();
      container = ProviderContainer(
        overrides: [
          pageContextProvider.overrideWith(
            (ref) => contextController.stream,
          ),
        ],
      );
      // Force the provider to start listening
      container.listen(tabHistoryProvider, (_, _) {});
    });

    tearDown(() {
      container.dispose();
      contextController.close();
    });

    test('getCurrentTab returns Home after navigating Home → Search', () async {
      // Start on Home
      contextController.add(const RouteContext(type: RouteType.home));
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(tabHistoryProvider.notifier).getCurrentTab(),
        equals(0),
      );

      // Navigate to Search
      contextController.add(const RouteContext(type: RouteType.search));
      await Future<void>.delayed(Duration.zero);

      // Tab history should still report Home as the current tab
      // (search is not a main tab and should not be tracked)
      expect(
        container.read(tabHistoryProvider.notifier).getCurrentTab(),
        equals(0),
      );
    });

    test(
      'getCurrentTab returns Explore after navigating Explore → Search',
      () async {
        // Start on Home
        contextController.add(const RouteContext(type: RouteType.home));
        await Future<void>.delayed(Duration.zero);

        // Navigate to Explore
        contextController.add(const RouteContext(type: RouteType.explore));
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(tabHistoryProvider.notifier).getCurrentTab(),
          equals(1),
        );

        // Navigate to Search
        contextController.add(const RouteContext(type: RouteType.search));
        await Future<void>.delayed(Duration.zero);

        // Tab history should still report Explore as the current tab
        expect(
          container.read(tabHistoryProvider.notifier).getCurrentTab(),
          equals(1),
        );
      },
    );

    test(
      'getCurrentTab returns Profile after navigating Profile → Search',
      () async {
        // Start on Home
        contextController.add(const RouteContext(type: RouteType.home));
        await Future<void>.delayed(Duration.zero);

        // Navigate to Profile
        contextController.add(const RouteContext(type: RouteType.profile));
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(tabHistoryProvider.notifier).getCurrentTab(),
          equals(3),
        );

        // Navigate to Search
        contextController.add(const RouteContext(type: RouteType.search));
        await Future<void>.delayed(Duration.zero);

        // Tab history should still report Profile as the current tab
        expect(
          container.read(tabHistoryProvider.notifier).getCurrentTab(),
          equals(3),
        );
      },
    );

    test(
      'getCurrentTab returns Notifications after navigating Notifications → Search',
      () async {
        // Start on Home
        contextController.add(const RouteContext(type: RouteType.home));
        await Future<void>.delayed(Duration.zero);

        // Navigate to Notifications
        contextController.add(
          const RouteContext(type: RouteType.notifications),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(tabHistoryProvider.notifier).getCurrentTab(),
          equals(2),
        );

        // Navigate to Search
        contextController.add(const RouteContext(type: RouteType.search));
        await Future<void>.delayed(Duration.zero);

        // Tab history should still report Notifications as the current tab
        expect(
          container.read(tabHistoryProvider.notifier).getCurrentTab(),
          equals(2),
        );
      },
    );

    test('tab history is unchanged by search navigation', () async {
      // Start on Home
      contextController.add(const RouteContext(type: RouteType.home));
      await Future<void>.delayed(Duration.zero);

      // Navigate to Explore
      contextController.add(const RouteContext(type: RouteType.explore));
      await Future<void>.delayed(Duration.zero);

      final historyBeforeSearch = List<int>.from(
        container.read(tabHistoryProvider),
      );

      // Navigate to Search
      contextController.add(const RouteContext(type: RouteType.search));
      await Future<void>.delayed(Duration.zero);

      // History should be identical — search is not tracked
      expect(container.read(tabHistoryProvider), equals(historyBeforeSearch));
    });

    test(
      'search with videoIndex does not affect tab history',
      () async {
        // Start on Home
        contextController.add(const RouteContext(type: RouteType.home));
        await Future<void>.delayed(Duration.zero);

        final historyBeforeSearch = List<int>.from(
          container.read(tabHistoryProvider),
        );

        // Navigate to Search feed mode (with videoIndex)
        contextController.add(
          const RouteContext(
            type: RouteType.search,
            searchTerm: 'bitcoin',
            videoIndex: 3,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        // History should be identical
        expect(container.read(tabHistoryProvider), equals(historyBeforeSearch));

        // getCurrentTab should still report Home
        expect(
          container.read(tabHistoryProvider.notifier).getCurrentTab(),
          equals(0),
        );
      },
    );
  });
}
