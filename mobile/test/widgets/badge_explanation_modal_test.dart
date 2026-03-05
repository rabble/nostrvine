// ABOUTME: Tests for BadgeExplanationModal widget
// ABOUTME: Validates Vine archive, ProofMode details, and AI detection sections

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/widgets/badge_explanation_modal.dart';

class _MockModerationLabelService extends Mock
    implements ModerationLabelService {}

void main() {
  late _MockModerationLabelService mockLabelService;

  setUp(() {
    mockLabelService = _MockModerationLabelService();
    when(() => mockLabelService.getAIDetectionResult(any())).thenReturn(null);
    when(() => mockLabelService.getAIDetectionByHash(any())).thenReturn(null);
  });

  Widget buildSubject(VideoEvent video) {
    return ProviderScope(
      overrides: [
        moderationLabelServiceProvider.overrideWithValue(mockLabelService),
      ],
      child: MaterialApp(
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
          originalLoops: 0,
        );

        await tester.pumpWidget(buildSubject(video));
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        // Not original vine, so it shows ProofMode explanation
        expect(find.text('Video Verification'), findsOneWidget);
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

        expect(find.text('Video Verification'), findsOneWidget);
        expect(find.text('ProofMode Verification'), findsOneWidget);
        expect(find.text('AI Detection'), findsOneWidget);
        expect(find.text('Device attestation'), findsOneWidget);
        expect(find.text('PGP signature'), findsOneWidget);
        expect(find.text('C2PA Content Credentials'), findsOneWidget);
        expect(find.text('Proof manifest'), findsOneWidget);
        expect(find.text('Not yet scanned'), findsOneWidget);
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
        when(
          () => mockLabelService.getAIDetectionResult('hash_fallback_id'),
        ).thenReturn(null);
        when(
          () => mockLabelService.getAIDetectionByHash('content_sha256'),
        ).thenReturn(
          const AIDetectionResult(score: 0.05, source: 'hiveai'),
        );

        final video = VideoEvent(
          id: 'hash_fallback_id',
          pubkey: 'pubkey6',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'video with hash',
          timestamp: DateTime.now(),
          sha256: 'content_sha256',
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
