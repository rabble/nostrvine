import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/proofmode_badge_row.dart';

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
        home: Scaffold(body: ProofModeBadgeRow(video: video)),
      ),
    );
  }

  group('ProofModeBadgeRow', () {
    testWidgets('shows Human Made for scan-only human results', (
      tester,
    ) async {
      const sha256 =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
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
          aiScore: 0.18,
        ),
      );

      final video = VideoEvent(
        id: 'divine_no_proof_human_scan',
        pubkey: 'pubkey1',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'divine-hosted video',
        timestamp: DateTime.now(),
        sha256: sha256,
        videoUrl: 'https://media.divine.video/$sha256.mp4',
      );

      await tester.pumpWidget(buildSubject(video));
      await tester.pumpAndSettle();

      expect(find.text('Human Made'), findsOneWidget);
      expect(find.text('Hosted on Divine'), findsNothing);
    });

    testWidgets('still shows Human Made for proof-backed videos', (
      tester,
    ) async {
      final video = VideoEvent(
        id: 'proof_backed_video',
        pubkey: 'pubkey2',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'proof backed video',
        timestamp: DateTime.now(),
        videoUrl: 'https://media.divine.video/proof_backed_video.mp4',
        rawTags: const {
          'verification': 'verified_mobile',
          'proofmode': '{"proof":"present"}',
        },
      );

      await tester.pumpWidget(buildSubject(video));
      await tester.pumpAndSettle();

      expect(find.text('Human Made'), findsOneWidget);
      expect(find.text('Hosted on Divine'), findsNothing);
    });
  });
}
