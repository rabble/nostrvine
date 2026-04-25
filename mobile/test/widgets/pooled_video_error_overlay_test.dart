// ABOUTME: Tests for PooledVideoErrorOverlay widget
// ABOUTME: Verifies UI rendering for each VideoErrorType and moderation
// ABOUTME: enrichment for divine URL 404 errors.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/video_feed_item/pooled_video_error_overlay.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../builders/test_video_event_builder.dart';

Finder _findDivineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  group(PooledVideoErrorOverlay, () {
    late VideoEvent divineVideo;
    late VideoEvent thirdPartyVideo;
    late bool retryPressed;

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
    });

    Widget buildWidget({VideoErrorType? errorType, VideoEvent? video}) {
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
              errorType: errorType,
            ),
          ),
        ),
      );
    }

    Widget buildWidgetWithModeration({
      required VideoErrorType? errorType,
      required VideoModerationStatus moderationStatus,
      VideoEvent? video,
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
        expect(find.text('Content restricted'), findsOneWidget);
      });

      testWidgets('does not show retry button', (tester) async {
        await tester.pumpWidget(
          buildWidget(errorType: VideoErrorType.forbidden),
        );
        await tester.pumpAndSettle();

        expect(find.text('Retry'), findsNothing);
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
        expect(find.text('Age-restricted content'), findsOneWidget);
      });

      testWidgets('shows Retry button', (tester) async {
        await tester.pumpWidget(
          buildWidget(errorType: VideoErrorType.ageRestricted),
        );
        await tester.pumpAndSettle();

        expect(find.text('Retry'), findsOneWidget);
      });
    });

    group('notFound', () {
      testWidgets('shows "Video not found" with retry', (tester) async {
        await tester.pumpWidget(
          buildWidget(errorType: VideoErrorType.notFound),
        );
        await tester.pumpAndSettle();

        expect(_findDivineIcon(DivineIconName.warningCircle), findsOneWidget);
        expect(find.text('Video not found'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
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
          expect(find.text('Content restricted'), findsOneWidget);
          expect(find.text('Retry'), findsNothing);
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
          expect(find.text('Content restricted'), findsOneWidget);
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
        expect(find.text('Video not found'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
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
        expect(find.text('Video playback error'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('shows generic error for null error type', (tester) async {
        await tester.pumpWidget(buildWidget(video: thirdPartyVideo));
        await tester.pumpAndSettle();

        expect(_findDivineIcon(DivineIconName.warningCircle), findsOneWidget);
        expect(find.text('Video playback error'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
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
          expect(find.text('Content restricted'), findsOneWidget);
          expect(find.text('Retry'), findsNothing);
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

        await tester.tap(find.text('Retry'));
        expect(retryPressed, isTrue);
      });
    });
  });
}
