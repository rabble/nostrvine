// ABOUTME: Tests for BadgeExplanationModal widget
// ABOUTME: Validates Vine archive, ProofMode details, and AI detection sections

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/badge_explanation_modal.dart';

class _MockModerationLabelService extends Mock
    implements ModerationLabelService {}

class _MockVideoModerationStatusService extends Mock
    implements VideoModerationStatusService {}

void main() {
  late _MockModerationLabelService mockLabelService;
  late _MockVideoModerationStatusService mockVideoModerationStatusService;

  setUp(() {
    mockLabelService = _MockModerationLabelService();
    mockVideoModerationStatusService = _MockVideoModerationStatusService();
    when(() => mockLabelService.getAIDetectionResult(any())).thenReturn(null);
    when(() => mockLabelService.getAIDetectionByHash(any())).thenReturn(null);
    when(
      () => mockVideoModerationStatusService.fetchStatus(any()),
    ).thenAnswer((_) async => null);
  });

  Widget buildSubject(VideoEvent video) {
    return ProviderScope(
      overrides: [
        moderationLabelServiceProvider.overrideWithValue(mockLabelService),
        videoModerationStatusServiceProvider.overrideWithValue(
          mockVideoModerationStatusService,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ProviderScope(
                  overrides: [
                    moderationLabelServiceProvider.overrideWithValue(
                      mockLabelService,
                    ),
                    videoModerationStatusServiceProvider.overrideWithValue(
                      mockVideoModerationStatusService,
                    ),
                  ],
                  child: BadgeExplanationModal(video: video),
                ),
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );
  }

  group(BadgeExplanationModal, () {
    group('Vine archive video', () {
      testWidgets('renders Vine archive explanation', (tester) async {
        final video = VideoEvent(
          id: 'vine_id',
          pubkey: 'pubkey1',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'classic vine',
          timestamp: DateTime.now(),
          rawTags: const {'platform': 'vine', 'loops': '1000000'},
          originalLoops: 1000000,
        );

        await tester.pumpWidget(buildSubject(video));
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text('Original Vine Archive'), findsOneWidget);
        expect(
          find.textContaining('original Vine recovered'),
          findsOneWidget,
        );
        expect(find.textContaining('1000000 loops'), findsOneWidget);
      });

      testWidgets('renders Vine archive without loops when zero', (
        tester,
      ) async {
        final video = VideoEvent(
          id: 'vine_id_2',
          pubkey: 'pubkey2',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'vine no loops',
          timestamp: DateTime.now(),
          rawTags: const {'platform': 'vine'},
          originalLoops: 0,
        );

        await tester.pumpWidget(buildSubject(video));
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text('Original Vine Archive'), findsOneWidget);
        expect(find.text('Original stats: 0 loops'), findsNothing);
      });
    });

    group('ProofMode verified video', () {
      testWidgets('renders ProofMode verification details', (tester) async {
        final video = VideoEvent(
          id: 'proof_id',
          pubkey: 'pubkey3',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'verified video',
          timestamp: DateTime.now(),
          rawTags: const {
            'verification': 'verified_mobile',
            'proofmode': '{"test": "data"}',
            'pgp_fingerprint': 'ABC123',
            'device_attestation': 'ATTEST',
          },
        );

        await tester.pumpWidget(buildSubject(video));
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text('Camera Proof'), findsNWidgets(2));
        expect(
          find.textContaining(
            "This video's authenticity is verified using Proofmode technology.",
          ),
          findsOneWidget,
        );
        expect(find.text('AI Detection'), findsOneWidget);
        expect(find.text('Device attestation'), findsOneWidget);
        expect(find.text('PGP signature'), findsOneWidget);
        expect(find.text('C2PA Content Credentials'), findsOneWidget);
        expect(find.text('Proof manifest'), findsOneWidget);
        expect(find.text('AI scan: Not yet scanned'), findsOneWidget);
        expect(find.text('Check if AI-generated'), findsOneWidget);
      });

      testWidgets('uses authenticity wording when no proof data exists', (
        tester,
      ) async {
        final video = VideoEvent(
          id: 'no_proof_id',
          pubkey: 'pubkey_no_proof',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'unverified video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example-cdn.com/video.mp4',
        );

        await tester.pumpWidget(buildSubject(video));
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text('Authenticity Signals'), findsNWidgets(2));
        expect(find.text('Camera Proof'), findsNothing);
        expect(
          find.textContaining('cryptographic camera-verification data'),
          findsOneWidget,
        );
        expect(
          find.textContaining('ProofMode verification data'),
          findsNothing,
        );
      });

      testWidgets('shows AI detection results when available', (
        tester,
      ) async {
        when(
          () => mockLabelService.getAIDetectionResult('ai_proof_id'),
        ).thenReturn(
          const AIDetectionResult(score: 0.15, source: 'hiveai'),
        );

        final video = VideoEvent(
          id: 'ai_proof_id',
          pubkey: 'pubkey4',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'ai scanned video',
          timestamp: DateTime.now(),
          rawTags: const {'verification': 'verified_mobile'},
        );

        await tester.pumpWidget(buildSubject(video));
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(
          find.text('15% likelihood of being AI-generated'),
          findsOneWidget,
        );
        expect(find.text('Scanned by: hiveai'), findsOneWidget);
        expect(find.text('Not yet scanned'), findsNothing);
      });

      testWidgets('shows verified badge when result is verified', (
        tester,
      ) async {
        when(
          () => mockLabelService.getAIDetectionResult('verified_ai_id'),
        ).thenReturn(
          const AIDetectionResult(
            score: 0.92,
            source: 'hiveai',
            isVerified: true,
          ),
        );

        final video = VideoEvent(
          id: 'verified_ai_id',
          pubkey: 'pubkey5',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'verified ai scanned',
          timestamp: DateTime.now(),
          rawTags: const {'verification': 'verified_web'},
        );

        await tester.pumpWidget(buildSubject(video));
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(
          find.text('92% likelihood of being AI-generated'),
          findsOneWidget,
        );
        expect(find.text('Verified by human moderator'), findsOneWidget);
      });

      testWidgets('falls back to hash lookup for AI detection', (
        tester,
      ) async {
        const sha256 =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        when(
          () => mockLabelService.getAIDetectionResult('hash_fallback_id'),
        ).thenReturn(null);
        when(
          () => mockLabelService.getAIDetectionByHash(sha256),
        ).thenReturn(
          const AIDetectionResult(score: 0.05, source: 'hiveai'),
        );

        final video = VideoEvent(
          id: 'hash_fallback_id',
          pubkey: 'pubkey6',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'video with hash',
          timestamp: DateTime.now(),
          sha256: sha256,
          rawTags: const {'verification': 'basic_proof'},
        );

        await tester.pumpWidget(buildSubject(video));
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(
          find.text('5% likelihood of being AI-generated'),
          findsOneWidget,
        );
      });

      testWidgets('checks moderation status from the modal on demand', (
        tester,
      ) async {
        const sha256 =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        var lookupCount = 0;
        when(
          () => mockVideoModerationStatusService.fetchStatus(sha256),
        ).thenAnswer(
          (_) async {
            lookupCount += 1;
            if (lookupCount == 1) {
              return null;
            }
            return const VideoModerationStatus(
              moderated: false,
              blocked: false,
              quarantined: false,
              ageRestricted: false,
              needsReview: false,
              aiGenerated: false,
              aiScore: 0.12,
            );
          },
        );

        final video = VideoEvent(
          id: 'modal_check_id',
          pubkey: 'pubkey8',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'video needing scan',
          timestamp: DateTime.now(),
          sha256: sha256,
          videoUrl: 'https://media.divine.video/$sha256.mp4',
        );

        await tester.pumpWidget(buildSubject(video));
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text('Check if AI-generated'), findsOneWidget);
        await tester.tap(find.text('Check if AI-generated'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.textContaining('AI detection indicates it is likely human-made'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Silver: AI scan confirms this video is likely human-created.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('12% likelihood of being AI-generated'),
          findsOneWidget,
        );
        verify(
          () => mockVideoModerationStatusService.fetchStatus(sha256),
        ).called(greaterThanOrEqualTo(2));
      });

      testWidgets(
        'automatically resolves moderation AI status from Divine video URL when sha256 is missing',
        (tester) async {
          const sha256 =
              'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
          when(
            () => mockVideoModerationStatusService.fetchStatus(sha256),
          ).thenAnswer(
            (_) async => const VideoModerationStatus(
              moderated: false,
              blocked: false,
              quarantined: false,
              ageRestricted: false,
              needsReview: false,
              aiGenerated: false,
              aiScore: 0.09,
            ),
          );

          final video = VideoEvent(
            id: 'modal_url_hash_only',
            pubkey: 'pubkey9',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            content: 'divine hosted modal video',
            timestamp: DateTime.now(),
            videoUrl: 'https://media.divine.video/$sha256.mp4',
          );

          await tester.pumpWidget(buildSubject(video));
          await tester.tap(find.text('Show'));
          await tester.pumpAndSettle();

          expect(
            find.text('9% likelihood of being AI-generated'),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              'AI detection indicates it is likely human-made',
            ),
            findsOneWidget,
          );
        },
      );
    });

    group('close button', () {
      testWidgets('renders close button', (tester) async {
        final video = VideoEvent(
          id: 'close_test',
          pubkey: 'pubkey7',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'test',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(buildSubject(video));
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text('Close'), findsOneWidget);
      });
    });
  });
}
