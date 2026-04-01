// ABOUTME: Tests for VideoErrorOverlay widget
// ABOUTME: Verifies 401, 403, moderation-enriched 404, and general error display

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/broken_video_tracker.dart'
    show BrokenVideoTracker;
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/video_feed_item/video_error_overlay.dart';

import '../builders/test_video_event_builder.dart';

class _MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

/// A sha256 hash that [VideoModerationStatusService.resolveSha256] recognises.
const _testSha256 =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

/// Video URL whose path segment IS the sha256 hash — triggers moderation lookup.
const _divineVideoUrl = 'https://media.divine.video/$_testSha256';

void main() {
  group(VideoErrorOverlay, () {
    late VideoEvent testVideo;
    late VideoControllerParams controllerParams;
    late _MockAgeVerificationService mockAgeVerification;

    setUpAll(() {
      registerFallbackValue(Object());
    });

    setUp(() {
      testVideo = TestVideoEventBuilder.create(
        id: 'test-video-id',
        videoUrl: 'https://example.com/video.mp4',
      );

      controllerParams = VideoControllerParams(
        videoId: testVideo.id,
        videoUrl: testVideo.videoUrl!,
        videoEvent: testVideo,
      );

      mockAgeVerification = _MockAgeVerificationService();
    });

    Widget buildWidget({
      required String errorDescription,
      bool isActive = true,
      VideoEvent? videoOverride,
      VideoControllerParams? paramsOverride,
    }) {
      final video = videoOverride ?? testVideo;
      final params = paramsOverride ?? controllerParams;
      return ProviderScope(
        overrides: [
          ageVerificationServiceProvider.overrideWithValue(mockAgeVerification),
          brokenVideoTrackerProvider.overrideWith(
            (_) => Completer<BrokenVideoTracker>().future,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VideoErrorOverlay(
              video: video,
              controllerParams: params,
              errorDescription: errorDescription,
              isActive: isActive,
            ),
          ),
        ),
      );
    }

    /// Build widget with moderation status override for a divine video URL.
    Widget buildModeratedWidget({
      required String errorDescription,
      required VideoModerationStatus moderationStatus,
    }) {
      final divineVideo = TestVideoEventBuilder.create(
        id: 'moderated-video-id',
        videoUrl: _divineVideoUrl,
      );
      final divineParams = VideoControllerParams(
        videoId: divineVideo.id,
        videoUrl: divineVideo.videoUrl!,
        videoEvent: divineVideo,
      );
      return ProviderScope(
        overrides: [
          ageVerificationServiceProvider.overrideWithValue(mockAgeVerification),
          brokenVideoTrackerProvider.overrideWith(
            (_) => Completer<BrokenVideoTracker>().future,
          ),
          videoModerationStatusProvider(_testSha256).overrideWith(
            (_) async => moderationStatus,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VideoErrorOverlay(
              video: divineVideo,
              controllerParams: divineParams,
              errorDescription: errorDescription,
              isActive: true,
            ),
          ),
        ),
      );
    }

    // ── 401 (Age-restricted) ────────────────────────────────────

    testWidgets('displays 401 error UI for unauthorized errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          errorDescription: 'HttpException: Invalid statusCode: 401',
        ),
      );

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Age-restricted content'), findsOneWidget);
      expect(find.text('Verify Age'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets(
      '401 error with "unauthorized" in lowercase triggers age verification UI',
      (tester) async {
        await tester.pumpWidget(
          buildWidget(errorDescription: 'unauthorized access'),
        );

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.text('Age-restricted content'), findsOneWidget);
        expect(find.text('Verify Age'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Verify Age button shows age verification dialog',
      (tester) async {
        when(
          () => mockAgeVerification.verifyAdultContentAccess(any()),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(
          buildWidget(
            errorDescription: 'HttpException: Invalid statusCode: 401',
          ),
        );

        await tester.tap(find.text('Verify Age'));
        await tester.pumpAndSettle();

        verify(
          () => mockAgeVerification.verifyAdultContentAccess(any()),
        ).called(1);
        // TODO(any): Fix and re-enable these tests
      },
      skip: true,
    );

    // ── 403 (Moderation-restricted) ─────────────────────────────

    testWidgets('displays 403 error UI with shield icon', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          errorDescription: 'HttpException: Invalid statusCode: 403',
        ),
      );

      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.text('Content restricted'), findsOneWidget);
      // 403 should NOT show a retry button — content is intentionally blocked
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Verify Age'), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets(
      '403 error with "forbidden" keyword triggers restricted UI',
      (tester) async {
        await tester.pumpWidget(
          buildWidget(errorDescription: 'forbidden'),
        );

        expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
        expect(find.text('Content restricted'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
      },
    );

    testWidgets('403 error does not show any action button', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          errorDescription: 'HttpException: Invalid statusCode: 403',
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });

    // ── 404 with moderation enrichment ──────────────────────────

    testWidgets(
      'displays "Content restricted" for 404 when moderation status is blocked',
      (tester) async {
        await tester.pumpWidget(
          buildModeratedWidget(
            errorDescription: 'HttpException: Invalid statusCode: 404',
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

        // Allow the async moderation provider to resolve
        await tester.pump();
        await tester.pump();

        expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
        expect(find.text('Content restricted'), findsOneWidget);
        // No retry for moderation-restricted content
        expect(find.text('Retry'), findsNothing);
      },
    );

    testWidgets(
      'displays standard "Video not found" for 404 without moderation status',
      (tester) async {
        await tester.pumpWidget(
          buildWidget(
            errorDescription: 'HttpException: Invalid statusCode: 404',
          ),
        );

        // URL doesn't have sha256 → no moderation lookup → standard 404 message
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Video not found'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      },
    );

    testWidgets(
      'shows restricted UI for quarantined 404 (moderation enrichment)',
      (tester) async {
        await tester.pumpWidget(
          buildModeratedWidget(
            errorDescription: 'HttpException: Invalid statusCode: 404',
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

        // Allow async provider to resolve
        await tester.pump();
        await tester.pump();

        // Quarantined content should show shield + restricted message
        expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
        expect(find.text('Content restricted'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
      },
    );

    // ── General error messages ───────────────────────────────────

    testWidgets('displays generic error UI for non-401 errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          errorDescription: 'HttpException: Invalid statusCode: 404',
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Video not found'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });

    testWidgets('translates 404 error to user-friendly message', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          errorDescription: 'HttpException: Invalid statusCode: 404',
        ),
      );

      expect(find.text('Video not found'), findsOneWidget);
    });

    testWidgets('translates network error to user-friendly message', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(errorDescription: 'Network error: Connection failed'),
      );

      expect(find.text('Network error'), findsOneWidget);
    });

    testWidgets('translates timeout error to user-friendly message', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(errorDescription: 'Request timeout'),
      );

      expect(find.text('Loading timeout'), findsOneWidget);
    });

    testWidgets('translates format error to user-friendly message', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(errorDescription: 'Unsupported codec'),
      );

      expect(find.text('Unsupported video format'), findsOneWidget);
    });

    testWidgets('shows generic error message for unknown errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(errorDescription: 'Some unknown error'),
      );

      expect(find.text('Video playback error'), findsOneWidget);
    });

    // ── Visibility ──────────────────────────────────────────────

    testWidgets('hides error overlay when video is inactive', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          errorDescription: 'HttpException: Invalid statusCode: 401',
          isActive: false,
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('shows error overlay when video is active', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          errorDescription: 'HttpException: Invalid statusCode: 401',
        ),
      );

      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}
