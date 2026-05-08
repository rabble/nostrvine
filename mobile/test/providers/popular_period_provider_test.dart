import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/providers/popular_period_provider.dart';

void main() {
  group(popularPeriodProvider, () {
    test('defaults to null (Right Now)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(popularPeriodProvider), isNull);
    });

    test('mutates to a LeaderboardPeriod when set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(popularPeriodProvider.notifier).state =
          LeaderboardPeriod.week;

      expect(
        container.read(popularPeriodProvider),
        equals(LeaderboardPeriod.week),
      );
    });

    test('reverts to null when explicitly cleared', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(popularPeriodProvider.notifier).state =
          LeaderboardPeriod.alltime;
      container.read(popularPeriodProvider.notifier).state = null;

      expect(container.read(popularPeriodProvider), isNull);
    });
  });
}
