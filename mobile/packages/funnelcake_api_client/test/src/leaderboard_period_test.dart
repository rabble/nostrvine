import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:test/test.dart';

void main() {
  group(LeaderboardPeriod, () {
    test('wireValue maps each variant to the funnelcake API token', () {
      expect(LeaderboardPeriod.day.wireValue, equals('day'));
      expect(LeaderboardPeriod.week.wireValue, equals('week'));
      expect(LeaderboardPeriod.month.wireValue, equals('month'));
      expect(LeaderboardPeriod.alltime.wireValue, equals('alltime'));
    });

    test('urlSlug uses today for day, otherwise matches wireValue', () {
      expect(LeaderboardPeriod.day.urlSlug, equals('today'));
      expect(LeaderboardPeriod.week.urlSlug, equals('week'));
      expect(LeaderboardPeriod.month.urlSlug, equals('month'));
      expect(LeaderboardPeriod.alltime.urlSlug, equals('alltime'));
    });

    test('fromUrlSlug round-trips every supported value', () {
      for (final p in LeaderboardPeriod.values) {
        expect(LeaderboardPeriod.fromUrlSlug(p.urlSlug), equals(p));
      }
    });

    test('fromUrlSlug returns null for unknown or empty input', () {
      expect(LeaderboardPeriod.fromUrlSlug(null), isNull);
      expect(LeaderboardPeriod.fromUrlSlug(''), isNull);
      expect(LeaderboardPeriod.fromUrlSlug('right_now'), isNull);
      expect(LeaderboardPeriod.fromUrlSlug('YEAR'), isNull);
    });

    test('fromUrlSlug accepts day as well as today (back-compat)', () {
      expect(
        LeaderboardPeriod.fromUrlSlug('day'),
        equals(LeaderboardPeriod.day),
      );
    });
  });
}
