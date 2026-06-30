// ABOUTME: Widget + physics tests for the full-screen reaction float overlay.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/reaction_overlay.dart';

void main() {
  group('ReactionOverlay', () {
    testWidgets(
      'paints the float on a CustomPaint, shows the localized pill, '
      'then fires onComplete',
      (tester) async {
        var completed = false;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ReactionOverlay(
                emoji: '❤️',
                randomSeed: 1,
                onComplete: () => completed = true,
              ),
            ),
          ),
        );
        await tester.pump();

        // Every particle is drawn by one CustomPainter (a batched drawRawAtlas),
        // not a Stack of Text.
        expect(
          find.descendant(
            of: find.byType(ReactionOverlay),
            matching: find.byType(CustomPaint),
          ),
          findsWidgets,
        );
        expect(completed, isFalse);

        // Mid-animation: the confirmation pill reads its label from l10n, not a
        // hardcoded literal (the German value must NOT appear in an `en` tree).
        await tester.pump(const Duration(milliseconds: 250));
        final en = lookupAppLocalizations(const Locale('en'));
        expect(find.text(en.dmReelReactionSentPill), findsOneWidget);
        expect(
          find.text(
            lookupAppLocalizations(const Locale('de')).dmReelReactionSentPill,
          ),
          findsNothing,
        );
        expect(completed, isFalse);

        // Drain the animation → completes and notifies the host.
        await tester.pumpAndSettle();
        expect(completed, isTrue);
      },
    );

    testWidgets('does not absorb pointer events (IgnorePointer)', (
      tester,
    ) async {
      var tappedBehind = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tappedBehind = true,
                  child: const SizedBox.expand(),
                ),
                const ReactionOverlay(emoji: '🔥', randomSeed: 2),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tapAt(const Offset(10, 10));
      expect(tappedBehind, isTrue);
      // Let the animation finish so no ticker leaks into teardown.
      await tester.pump(const Duration(milliseconds: 2400));
    });
  });

  group('float physics', () {
    test('reactionFloatOpacity: 0 at the ends, holds at 1, stays in [0,1]', () {
      expect(reactionFloatOpacity(0), 0);
      expect(reactionFloatOpacity(1), 0);
      expect(reactionFloatOpacity(0.3), 1); // inside the hold band
      for (var i = 0; i <= 100; i++) {
        expect(reactionFloatOpacity(i / 100), inInclusiveRange(0.0, 1.0));
      }
      // Fades out across the back half but is still visible at 0.75.
      final late = reactionFloatOpacity(0.75);
      expect(late, greaterThan(0));
      expect(late, lessThan(1));
    });

    test('reactionFloatScaleIn pops 0→1 then holds at 1', () {
      expect(reactionFloatScaleIn(0), 0);
      expect(reactionFloatScaleIn(0.2), 1); // past the scale-in fraction
      expect(reactionFloatScaleIn(0.99), 1);
      final mid = reactionFloatScaleIn(0.06);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
    });

    test('reactionFloatRise is a monotonic ease-out from 0 to 1', () {
      expect(reactionFloatRise(0), 0);
      expect(reactionFloatRise(1), closeTo(1, 1e-9));
      // Ease-out: more than half the distance is covered by the halfway point.
      expect(reactionFloatRise(0.5), greaterThan(0.5));
      var prev = -1.0;
      for (var i = 0; i <= 100; i++) {
        final v = reactionFloatRise(i / 100);
        expect(v, greaterThanOrEqualTo(prev));
        prev = v;
      }
    });

    test('reactionFloatWiggle is a bounded sine sway', () {
      const amp = 40.0;
      // Zero at phase 0, lp 0.
      expect(reactionFloatWiggle(amp, 1, 0, 0), closeTo(0, 1e-9));
      // Peaks at +amplitude a quarter-cycle in.
      expect(reactionFloatWiggle(amp, 1, 0, 0.25), closeTo(amp, 1e-9));
      // Never exceeds the amplitude.
      for (var i = 0; i <= 100; i++) {
        expect(
          reactionFloatWiggle(amp, 1.7, 1.2, i / 100).abs(),
          lessThanOrEqualTo(amp + 1e-9),
        );
      }
    });
  });
}
