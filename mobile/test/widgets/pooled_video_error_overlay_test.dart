// ABOUTME: Tests for PooledVideoErrorOverlay widget
// ABOUTME: Verifies UI rendering for each VideoErrorType and moderation
// ABOUTME: enrichment for divine URL 404 errors.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart'
    show VideoErrorType;
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/video_feed_item/pooled_video_error_overlay.dart';

import '../builders/test_video_event_builder.dart';

Finder _findDivineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  group(PooledVideoErrorOverlay, () {
    late VideoEvent divineVideo;
    late VideoEvent thirdPartyVideo;
    late bool retryPressed;
    late bool verifyAgePressed;
    late AppLocalizations l10n;

    // Valid 64-char hex sha256 for moderation status resolution.
    const testSha256 =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    setUp(() {
      divineVideo = TestVideoEventBuilder.create(
        id: 'test-video-id',
        videoUrl: 'https://blossom.divine.video/$testSha256.mp4',
      );
      thirdPartyVideo = TestVideoEventBuilder.create(
        id: 'third-party-video',
        videoUrl: 'https://cdn.example.com/video.mp4',
      );
      retryPressed = false;
      verifyAgePressed = false;
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    Widget buildWidget({
      VideoErrorType? errorType,
      VideoEvent? video,
      VoidCallback? onVerifyAge,
      bool isVerifying = false,
    }) {
      return ProviderScope(
        overrides: [
          videoModerationStatusProvider.overrideWith(
            (ref, sha256) async => null,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PooledVideoErrorOverlay(
              video: video ?? divineVideo,
              onRetry: () => retryPressed = true,
              onVerifyAge: onVerifyAge,
              errorType: errorType,
              isVerifying: isVerifying,
            ),
          ),
        ),
      );
    }

    Widget buildWidgetWithModeration({
      required VideoErrorType? errorType,
      required VideoModerationStatus moderationStatus,
      VideoEvent? video,
      VoidCallback? onVerifyAge,
    }) {
      return ProviderScope(
        overrides: [
          videoModerationStatusProvider.overrideWith(
            (ref, sha256) async => moderationStatus,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PooledVideoErrorOverlay(
              video: video ?? divineVideo,
              onRetry: () => retryPressed = true,
              onVerifyAge: onVerifyAge,
              errorType: errorType,
            ),
          ),
        ),
      );
    }

    group('forbidden', () {
      testWidgets('shows shield icon and "Content restricted"', (tester) async {
        await tester.pumpWidget(
          buildWidget(errorType: VideoErrorType.forbidden),
        );
        await tester.pumpAndSettle();

        expect(_findDivineIcon(DivineIconName.shieldCheck), findsOneWidget);
        expect(find.text(l10n.videoErrorContentRestricted), findsOneWidget);
      });

      testWidgets('does not show retry button', (tester) async {
        await tester.pumpWidget(
          buildWidget(errorType: VideoErrorType.forbidden),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoErrorRetry), findsNothing);
      });
    });

    group('ageRestricted', () {
      testWidgets('shows lock icon and "Age-restricted content"', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(errorType: VideoErrorType.ageRestricted),
        );
        await tester.pumpAndSettle();

        expect(_findDivineIcon(DivineIconName.lockSimple), findsOneWidget);
        expect(find.text(l10n.videoErrorAgeRestricted), findsOneWidget);
      });

      testWidgets('shows Retry button', (tester) async {
        await tester.pumpWidget(
          buildWidget(errorType: VideoErrorType.ageRestricted),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoErrorRetry), findsOneWidget);
      });

      testWidgets(
        'shows a loading spinner and disables Verify age while verifying',
        (tester) async {
          await tester.pumpWidget(
            buildWidget(
              errorType: VideoErrorType.ageRestricted,
              onVerifyAge: () => verifyAgePressed = true,
              isVerifying: true,
            ),
          );
          // Not pumpAndSettle: the loading spinner animates indefinitely.
          await tester.pump();

          expect(find.byType(CircularProgressIndicator), findsOneWidget);

          // Disabled while verifying — a tap must be a no-op.
          await tester.tap(find.text(l10n.videoErrorVerifyAgeButton));
          await tester.pump();
          expect(verifyAgePressed, isFalse);
        },
      );
    });

    group('notFound', () {
      testWidgets('shows "Video not found" with retry', (tester) async {
        await tester.pumpWidget(
          buildWidget(errorType: VideoErrorType.notFound),
        );
        await tester.pumpAndSettle();

        expect(_findDivineIcon(DivineIconName.warningCircle), findsOneWidget);
        expect(find.text(l10n.videoErrorNotFound), findsOneWidget);
        expect(find.text(l10n.videoErrorRetry), findsOneWidget);
      });

      testWidgets(
        'shows shield icon when moderation status indicates blocked',
        (tester) async {
          await tester.pumpWidget(
            buildWidgetWithModeration(
              errorType: VideoErrorType.notFound,
              moderationStatus: const VideoModerationStatus(
                moderated: true,
                blocked: true,
                quarantined: false,
                ageRestricted: false,
                needsReview: false,
                aiGenerated: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(_findDivineIcon(DivineIconName.shieldCheck), findsOneWidget);
          expect(find.text(l10n.videoErrorContentRestricted), findsOneWidget);
          expect(find.text(l10n.videoErrorRetry), findsNothing);
        },
      );

      testWidgets(
        'shows shield icon when moderation status indicates quarantined',
        (tester) async {
          await tester.pumpWidget(
            buildWidgetWithModeration(
              errorType: VideoErrorType.notFound,
              moderationStatus: const VideoModerationStatus(
                moderated: true,
                blocked: false,
                quarantined: true,
                ageRestricted: false,
                needsReview: false,
                aiGenerated: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(_findDivineIcon(DivineIconName.shieldCheck), findsOneWidget);
          expect(find.text(l10n.videoErrorContentRestricted), findsOneWidget);
        },
      );

      testWidgets(
        'shows age-gated explanation and verify action when moderation status is ageRestricted',
        (tester) async {
          await tester.pumpWidget(
            buildWidgetWithModeration(
              errorType: VideoErrorType.notFound,
              moderationStatus: const VideoModerationStatus(
                moderated: true,
                blocked: false,
                quarantined: false,
                ageRestricted: true,
                needsReview: false,
                aiGenerated: false,
              ),
              onVerifyAge: () => verifyAgePressed = true,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text(l10n.videoErrorAgeRestricted), findsOneWidget);
          expect(find.text(l10n.videoErrorVerifyAgeBody), findsOneWidget);
          expect(find.text(l10n.videoErrorVerifyAgeButton), findsOneWidget);
          expect(find.text(l10n.videoErrorRetry), findsNothing);

          await tester.tap(find.text(l10n.videoErrorVerifyAgeButton));

          expect(verifyAgePressed, isTrue);
        },
      );

      testWidgets('skips moderation lookup for non-divine video URLs', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidgetWithModeration(
            errorType: VideoErrorType.notFound,
            moderationStatus: const VideoModerationStatus(
              moderated: true,
              blocked: true,
              quarantined: false,
              ageRestricted: false,
              needsReview: false,
              aiGenerated: false,
            ),
            video: thirdPartyVideo,
          ),
        );
        await tester.pumpAndSettle();

        // Should show plain 404, not moderation-restricted.
        expect(_findDivineIcon(DivineIconName.warningCircle), findsOneWidget);
        expect(find.text(l10n.videoErrorNotFound), findsOneWidget);
        expect(find.text(l10n.videoErrorRetry), findsOneWidget);
      });
    });

    group('generic', () {
      testWidgets('shows "Video playback error" with retry', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            errorType: VideoErrorType.generic,
            video: thirdPartyVideo,
          ),
        );
        await tester.pumpAndSettle();

        expect(_findDivineIcon(DivineIconName.warningCircle), findsOneWidget);
        expect(find.text(l10n.videoErrorPlayback), findsOneWidget);
        expect(find.text(l10n.videoErrorRetry), findsOneWidget);
      });

      testWidgets('shows generic error for null error type', (tester) async {
        await tester.pumpWidget(buildWidget(video: thirdPartyVideo));
        await tester.pumpAndSettle();

        expect(_findDivineIcon(DivineIconName.warningCircle), findsOneWidget);
        expect(find.text(l10n.videoErrorPlayback), findsOneWidget);
        expect(find.text(l10n.videoErrorRetry), findsOneWidget);
      });

      testWidgets(
        'shows "Content restricted" when moderation status indicates blocked',
        (tester) async {
          await tester.pumpWidget(
            buildWidgetWithModeration(
              errorType: VideoErrorType.notFound,
              moderationStatus: const VideoModerationStatus(
                moderated: true,
                blocked: true,
                quarantined: false,
                ageRestricted: false,
                needsReview: false,
                aiGenerated: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(_findDivineIcon(DivineIconName.shieldCheck), findsOneWidget);
          expect(find.text(l10n.videoErrorContentRestricted), findsOneWidget);
          expect(find.text(l10n.videoErrorRetry), findsNothing);
        },
      );
    });

    group('retry', () {
      testWidgets('retry button calls onRetry', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            errorType: VideoErrorType.generic,
            video: thirdPartyVideo,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.videoErrorRetry));
        expect(retryPressed, isTrue);
      });
    });
  });
}
