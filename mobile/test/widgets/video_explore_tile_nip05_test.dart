// ABOUTME: Tests that VideoExploreTile does not show NIP-05 checkmarks
// ABOUTME: Ensures valid NIP-05 does not look like account verification

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/video_explore_tile.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

import '../helpers/test_provider_overrides.dart'
    show createMockMediaCacheManager;

class _MockModerationLabelService extends Mock
    implements ModerationLabelService {}

class _MockVideoModerationStatusService extends Mock
    implements VideoModerationStatusService {}

Finder _specialCheckmark() => find.byWidgetPredicate(
  (w) => w is DivineIcon && w.icon == DivineIconName.check,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testPubkey =
      'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

  late VideoEvent testVideo;

  setUp(() {
    final now = DateTime.now();
    testVideo = VideoEvent(
      id: 'test_event_id_001',
      pubkey: testPubkey,
      content: 'Test video',
      createdAt: now.millisecondsSinceEpoch ~/ 1000,
      timestamp: now,
      videoUrl: 'https://example.com/video.mp4',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      title: 'Test Video',
      duration: 15,
      hashtags: const ['test'],
    );
  });

  // Stub the image cache (#5158 seam) so VideoExploreTile's VineCachedImage does
  // no real path_provider / cache-manager work that could settle after the test
  // and cascade in the merged VGV optimizer isolate (#5159).
  setUp(() => debugImageCacheOverride = createMockMediaCacheManager());
  tearDown(() => debugImageCacheOverride = null);

  Widget buildSubject({
    required Nip05VerificationStatus verificationStatus,
    String? nip05,
  }) {
    final mockLabelService = _MockModerationLabelService();
    when(() => mockLabelService.getAIDetectionResult(any())).thenReturn(null);
    when(() => mockLabelService.getAIDetectionByHash(any())).thenReturn(null);

    return ProviderScope(
      overrides: [
        userProfileReactiveProvider.overrideWith((ref, pubkey) async* {
          yield UserProfile(
            pubkey: pubkey,
            name: 'Test User',
            nip05: nip05,
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: 'test_event',
          );
        }),
        nip05VerificationProvider.overrideWith(
          (ref, pubkey) async => verificationStatus,
        ),
        moderationLabelServiceProvider.overrideWithValue(mockLabelService),
        videoModerationStatusServiceProvider.overrideWithValue(
          _MockVideoModerationStatusService(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 300,
            child: VideoExploreTile(video: testVideo, isActive: false),
          ),
        ),
      ),
    );
  }

  group(VideoExploreTile, () {
    group('NIP-05 checkmark', () {
      testWidgets('does not show checkmark when NIP-05 is verified', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            verificationStatus: Nip05VerificationStatus.verified,
            nip05: 'alice@example.com',
          ),
        );
        await tester.pump();

        expect(_specialCheckmark(), findsNothing);
      });

      testWidgets('does not show checkmark when NIP-05 verification fails', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            verificationStatus: Nip05VerificationStatus.failed,
            nip05: 'fake@example.com',
          ),
        );
        await tester.pump();

        expect(_specialCheckmark(), findsNothing);
      });

      testWidgets('does not show checkmark when NIP-05 has network error', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            verificationStatus: Nip05VerificationStatus.error,
            nip05: 'alice@example.com',
          ),
        );
        await tester.pump();

        expect(_specialCheckmark(), findsNothing);
      });

      testWidgets('does not show checkmark when user has no NIP-05', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(verificationStatus: Nip05VerificationStatus.none),
        );
        await tester.pump();

        expect(_specialCheckmark(), findsNothing);
      });

      testWidgets('does not show checkmark while verification is pending', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            verificationStatus: Nip05VerificationStatus.pending,
            nip05: 'alice@example.com',
          ),
        );
        await tester.pump();

        expect(_specialCheckmark(), findsNothing);
      });

      testWidgets('shows checkmark for Kirsten Swasey special profile', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            verificationStatus: Nip05VerificationStatus.verified,
            nip05: '_@kirstenswasey.divine.video',
          ),
        );
        await tester.pump();

        expect(_specialCheckmark(), findsOneWidget);
      });
    });
  });
}
