// ABOUTME: Tests for SyncClock created_at generation.
// ABOUTME: Covers normal time, skew clamping, and the no-remote case.

import 'package:clock/clock.dart';
import 'package:creator_sync/creator_sync.dart';
import 'package:test/test.dart';

void main() {
  group(SyncClock, () {
    const fixedNow = 1_800_000_000;

    test('returns wall-clock seconds when no remote is known', () {
      withClock(
        Clock.fixed(
          DateTime.fromMillisecondsSinceEpoch(fixedNow * 1000, isUtc: true),
        ),
        () {
          expect(SyncClock.nowSeconds(), equals(fixedNow));
        },
      );
    });

    test('returns wall-clock seconds when it already leads the remote', () {
      withClock(
        Clock.fixed(
          DateTime.fromMillisecondsSinceEpoch(fixedNow * 1000, isUtc: true),
        ),
        () {
          expect(
            SyncClock.nowSeconds(latestKnownRemote: fixedNow - 500),
            equals(fixedNow),
          );
        },
      );
    });

    test('clamps past remote when local clock lags behind', () {
      withClock(
        Clock.fixed(
          DateTime.fromMillisecondsSinceEpoch(fixedNow * 1000, isUtc: true),
        ),
        () {
          expect(
            SyncClock.nowSeconds(latestKnownRemote: fixedNow + 900),
            equals(fixedNow + 901),
          );
        },
      );
    });

    test('clamps past remote when remote equals local time', () {
      withClock(
        Clock.fixed(
          DateTime.fromMillisecondsSinceEpoch(fixedNow * 1000, isUtc: true),
        ),
        () {
          expect(
            SyncClock.nowSeconds(latestKnownRemote: fixedNow),
            equals(fixedNow + 1),
          );
        },
      );
    });
  });
}
