// ABOUTME: Tests for PooledVideoErrorOverlay widget
// ABOUTME: Verifies error differentiation for 401, 403, 404, and generic
// ABOUTME: errors in the pooled video player path.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/video_feed_item/pooled_video_error_overlay.dart';

import '../builders/test_video_event_builder.dart';

void main() {
  group(PooledVideoErrorOverlay, () {
    late VideoEvent testVideo;
    late bool retryPressed;

    // Valid 64-char hex sha256 for moderation status resolution.
    const testSha256 =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    setUp(() {
      testVideo = TestVideoEventBuilder.create(
        id: 'test-video-id',
        videoUrl: 'https://blossom.divine.video/$testSha256.mp4',
      );
      retryPressed = false;
    });

    Widget buildWidget({
      String? errorMessage,
    }) {
      return ProviderScope(
        overrides: [
          videoModerationStatusProvider.overrideWith(
            (ref, sha256) async => null,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PooledVideoErrorOverlay(
              video: testVideo,
              onRetry: () => retryPressed = true,
              errorMessage: errorMessage,
            ),
          ),
        ),
      );
    }

    Widget buildWidgetWithModeration({
      required String? errorMessage,
      required VideoModerationStatus moderationStatus,
    }) {
      return ProviderScope(
        overrides: [
          videoModerationStatusProvider.overrideWith(
            (ref, sha256) async => moderationStatus,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PooledVideoErrorOverlay(
              video: testVideo,
              onRetry: () => retryPressed = true,
              errorMessage: errorMessage,
            ),
          ),
        ),
      );
    }

    group('403 Forbidden', () {
      testWidgets('shows shield icon and "Content restricted"', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(errorMessage: 'HttpException: 403 Forbidden'),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
        expect(find.text('Content restricted'), findsOneWidget);
      });

      testWidgets('does not show retry button', (tester) async {
        await tester.pumpWidget(
          buildWidget(errorMessage: 'HttpException: 403 Forbidden'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Retry'), findsNothing);
      });

      testWidgets('detects "forbidden" keyword variant', (tester) async {
        await tester.pumpWidget(
          buildWidget(errorMessage: 'forbidden'),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
        expect(find.text('Content restricted'), findsOneWidget);
      });
    });

    group('401 Unauthorized', () {
      testWidgets('shows lock icon and "Age-restricted content"', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            errorMessage: 'HttpException: Invalid statusCode: 401',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.text('Age-restricted content'), findsOneWidget);
      });

      testWidgets('shows "Verify Age" button', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            errorMessage: 'HttpException: Invalid statusCode: 401',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Verify Age'), findsOneWidget);
      });

      testWidgets('detects "unauthorized" keyword variant', (tester) async {
        await tester.pumpWidget(
          buildWidget(errorMessage: 'unauthorized'),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      });
    });

    group('404 Not Found', () {
      testWidgets('shows error icon and "Video not found" without moderation', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(errorMessage: '404 not found'),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Video not found'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets(
        'shows shield icon when moderation status indicates blocked',
        (tester) async {
          await tester.pumpWidget(
            buildWidgetWithModeration(
              errorMessage: '404 not found',
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

          expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
          expect(find.text('Content restricted'), findsOneWidget);
          expect(find.text('Retry'), findsNothing);
        },
      );

      testWidgets(
        'shows shield icon when moderation status indicates quarantined',
        (tester) async {
          await tester.pumpWidget(
            buildWidgetWithModeration(
              errorMessage: '404 not found',
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

          expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
          expect(find.text('Content restricted'), findsOneWidget);
        },
      );

      testWidgets(
        'skips moderation lookup for non-divine video URLs',
        (tester) async {
          // Use a non-divine URL — moderation provider returns blocked but
          // should never be consulted because shouldCheckModeration is false.
          final thirdPartyVideo = TestVideoEventBuilder.create(
            id: 'third-party-video',
            videoUrl: 'https://cdn.example.com/$testSha256.mp4',
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                videoModerationStatusProvider.overrideWith(
                  (ref, sha256) async => const VideoModerationStatus(
                    moderated: true,
                    blocked: true,
                    quarantined: false,
                    ageRestricted: false,
                    needsReview: false,
                    aiGenerated: false,
                  ),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: PooledVideoErrorOverlay(
                    video: thirdPartyVideo,
                    onRetry: () => retryPressed = true,
                    errorMessage: '404 not found',
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Should show plain 404, not moderation-restricted.
          expect(find.byIcon(Icons.error_outline), findsOneWidget);
          expect(find.text('Video not found'), findsOneWidget);
          expect(find.text('Retry'), findsOneWidget);
        },
      );
    });

    group('generic errors', () {
      testWidgets('shows error icon and retry for unknown errors', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(errorMessage: 'PlatformException: video decode error'),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Video playback error'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('shows generic error for null error message', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Video playback error'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('retry button calls onRetry', (tester) async {
        await tester.pumpWidget(
          buildWidget(errorMessage: 'some error'),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Retry'));
        expect(retryPressed, isTrue);
      });
    });
  });
}
