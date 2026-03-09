// ABOUTME: Unit tests for the scroll-driven overlay opacity utility.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/scroll_driven_opacity.dart';

void main() {
  group('scrollDrivenOpacity', () {
    group('fully visible region (distance <= dimLo)', () {
      test('returns 1.0 at distance 0', () {
        expect(scrollDrivenOpacity(0.0), equals(1.0));
      });

      test('returns 1.0 just below the full-opacity threshold', () {
        const dimLo = kOverlayFullOpacityThreshold - kOverlayFadeHalfWidth;
        expect(scrollDrivenOpacity(dimLo), equals(1.0));
      });
    });

    group('full-to-dim transition band', () {
      test('returns 1.0 at start of fade band', () {
        const dimLo = kOverlayFullOpacityThreshold - kOverlayFadeHalfWidth;
        expect(scrollDrivenOpacity(dimLo), equals(1.0));
      });

      test('returns dimmed opacity at end of fade band', () {
        const dimHi = kOverlayFullOpacityThreshold + kOverlayFadeHalfWidth;
        expect(scrollDrivenOpacity(dimHi), equals(kOverlayDimmedOpacity));
      });

      test('returns interpolated value at midpoint of fade band', () {
        const mid = kOverlayFullOpacityThreshold;
        final result = scrollDrivenOpacity(mid);
        const expected = (1.0 + kOverlayDimmedOpacity) / 2;
        expect(result, closeTo(expected, 1e-9));
      });
    });

    group('dimmed region', () {
      test('returns dimmed opacity between the two thresholds', () {
        const midpoint =
            (kOverlayFullOpacityThreshold + kOverlayHideThreshold) / 2;
        expect(scrollDrivenOpacity(midpoint), equals(kOverlayDimmedOpacity));
      });

      test('returns dimmed opacity just above full-opacity threshold', () {
        const dimHi = kOverlayFullOpacityThreshold + kOverlayFadeHalfWidth;
        expect(scrollDrivenOpacity(dimHi), equals(kOverlayDimmedOpacity));
      });

      test('returns dimmed opacity just below hide threshold', () {
        const hideLo = kOverlayHideThreshold - kOverlayFadeHalfWidth;
        expect(scrollDrivenOpacity(hideLo), equals(kOverlayDimmedOpacity));
      });
    });

    group('dim-to-hidden transition band', () {
      test('returns dimmed opacity at start of hide fade band', () {
        const hideLo = kOverlayHideThreshold - kOverlayFadeHalfWidth;
        expect(scrollDrivenOpacity(hideLo), equals(kOverlayDimmedOpacity));
      });

      test('returns 0.0 at end of hide fade band', () {
        const hideHi = kOverlayHideThreshold + kOverlayFadeHalfWidth;
        expect(scrollDrivenOpacity(hideHi), equals(0.0));
      });

      test('returns interpolated value at midpoint of hide fade band', () {
        const mid = kOverlayHideThreshold;
        final result = scrollDrivenOpacity(mid);
        const expected = kOverlayDimmedOpacity / 2;
        expect(result, closeTo(expected, 1e-9));
      });
    });

    group('fully hidden region (distance >= hideHi)', () {
      test('returns 0.0 at distance 1.0', () {
        expect(scrollDrivenOpacity(1.0), equals(0.0));
      });

      test('returns 0.0 above hide threshold', () {
        const hideHi = kOverlayHideThreshold + kOverlayFadeHalfWidth;
        expect(scrollDrivenOpacity(hideHi + 0.1), equals(0.0));
      });
    });

    group('monotonically decreasing', () {
      test('opacity never increases as distance increases', () {
        var prev = scrollDrivenOpacity(0.0);
        for (var i = 1; i <= 100; i++) {
          final distance = i / 100.0;
          final current = scrollDrivenOpacity(distance);
          expect(
            current,
            lessThanOrEqualTo(prev + 1e-9),
            reason: 'opacity increased at distance=$distance',
          );
          prev = current;
        }
      });
    });
  });
}
