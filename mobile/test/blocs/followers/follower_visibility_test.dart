// ABOUTME: Pins the displayed follower count to the authoritative REST value
// ABOUTME: minus locally hidden rows, with no relay-list-length floor (#8197).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/followers/follower_visibility.dart';

void main() {
  group('visibleFollowerCount', () {
    test('shows the authoritative count when nothing is hidden', () {
      expect(
        visibleFollowerCount(
          visiblePubkeyCount: 146,
          rawPubkeyCount: 146,
          authoritativeFollowerCount: 146,
        ),
        equals(146),
      );
    });

    test('subtracts followers the profile owner has blocked', () {
      // 5 of the fetched rows are blocked: 146 - 5 = 141.
      expect(
        visibleFollowerCount(
          visiblePubkeyCount: 175,
          rawPubkeyCount: 180,
          authoritativeFollowerCount: 146,
        ),
        equals(141),
      );
    });

    test(
      'is not floored by a relay list longer than the count (#8197)',
      () {
        // The real measured shape for @cptnbackfire: REST 146, relay-merged
        // union 180. A floor at the visible row count would display 180 and
        // move with relay coverage — the instability this issue reports.
        expect(
          visibleFollowerCount(
            visiblePubkeyCount: 180,
            rawPubkeyCount: 180,
            authoritativeFollowerCount: 146,
          ),
          equals(146),
        );
      },
    );

    test('blocking stays legible as relay coverage changes', () {
      // Same account, same 5 blocks, two runs where the union differed
      // (170 one day, 180 the next). The number must not move.
      final smallerUnion = visibleFollowerCount(
        visiblePubkeyCount: 165,
        rawPubkeyCount: 170,
        authoritativeFollowerCount: 146,
      );
      final largerUnion = visibleFollowerCount(
        visiblePubkeyCount: 175,
        rawPubkeyCount: 180,
        authoritativeFollowerCount: 146,
      );

      expect(smallerUnion, equals(largerUnion));
      expect(smallerUnion, equals(141));
    });

    test('never goes negative when hidden rows exceed the count', () {
      expect(
        visibleFollowerCount(
          visiblePubkeyCount: 0,
          rawPubkeyCount: 5,
          authoritativeFollowerCount: 2,
        ),
        equals(0),
      );
    });
  });
}
