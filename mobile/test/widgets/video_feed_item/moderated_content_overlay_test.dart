import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';

void main() {
  group(ModeratedContentOverlay, () {
    Future<void> pumpOverlay(
      WidgetTester tester, {
      required PlaybackStatus status,
      VoidCallback? onSkip,
      VoidCallback? onVerifyAge,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ModeratedContentOverlay(
              status: status,
              onSkip: onSkip ?? () {},
              onVerifyAge: onVerifyAge,
            ),
          ),
        ),
      );
    }

    testWidgets(
      'renders content-restricted message for forbidden',
      (tester) async {
        await pumpOverlay(tester, status: PlaybackStatus.forbidden);

        expect(
          find.text(ModeratedContentOverlayStrings.forbiddenTitle),
          findsOneWidget,
        );
        expect(
          find.text(ModeratedContentOverlayStrings.skipLabel),
          findsOneWidget,
        );
        expect(
          find.text(ModeratedContentOverlayStrings.verifyAgeLabel),
          findsNothing,
        );
      },
    );

    testWidgets(
      'renders age-restricted message and Verify age button',
      (tester) async {
        await pumpOverlay(
          tester,
          status: PlaybackStatus.ageRestricted,
          onVerifyAge: () {},
        );

        expect(
          find.text(ModeratedContentOverlayStrings.ageRestrictedTitle),
          findsOneWidget,
        );
        expect(
          find.text(ModeratedContentOverlayStrings.verifyAgeLabel),
          findsOneWidget,
        );
        expect(
          find.text(ModeratedContentOverlayStrings.skipLabel),
          findsOneWidget,
        );
      },
    );

    testWidgets('calls onSkip when Skip is tapped', (tester) async {
      var skipped = 0;
      await pumpOverlay(
        tester,
        status: PlaybackStatus.forbidden,
        onSkip: () => skipped++,
      );
      await tester.tap(find.text(ModeratedContentOverlayStrings.skipLabel));
      await tester.pumpAndSettle();

      expect(skipped, equals(1));
    });

    testWidgets(
      'calls onVerifyAge when Verify age is tapped',
      (tester) async {
        var verified = 0;
        await pumpOverlay(
          tester,
          status: PlaybackStatus.ageRestricted,
          onVerifyAge: () => verified++,
        );
        await tester.tap(
          find.text(ModeratedContentOverlayStrings.verifyAgeLabel),
        );
        await tester.pumpAndSettle();

        expect(verified, equals(1));
      },
    );

    testWidgets(
      'calls onSkip when Skip is tapped in ageRestricted state',
      (tester) async {
        var skipped = 0;
        await pumpOverlay(
          tester,
          status: PlaybackStatus.ageRestricted,
          onSkip: () => skipped++,
          onVerifyAge: () {},
        );
        await tester.tap(find.text(ModeratedContentOverlayStrings.skipLabel));
        await tester.pumpAndSettle();

        expect(skipped, equals(1));
      },
    );

    testWidgets(
      'does not render author info or action buttons',
      (tester) async {
        await pumpOverlay(tester, status: PlaybackStatus.forbidden);

        // The overlay must NOT show the usual FeedVideoOverlay chrome.
        expect(
          find.bySemanticsLabel(RegExp('Video author: .*')),
          findsNothing,
        );
        expect(
          find.bySemanticsLabel(RegExp('Video description: .*')),
          findsNothing,
        );
      },
    );

    test(
      'asserts when constructed with a non-restricted status',
      () {
        expect(
          () => ModeratedContentOverlay(
            status: PlaybackStatus.generic,
            onSkip: () {},
          ),
          throwsAssertionError,
        );
      },
    );

    test(
      'asserts when ageRestricted without onVerifyAge',
      () {
        expect(
          () => ModeratedContentOverlay(
            status: PlaybackStatus.ageRestricted,
            onSkip: () {},
          ),
          throwsAssertionError,
        );
      },
    );
  });
}
