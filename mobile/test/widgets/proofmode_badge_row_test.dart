import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/proofmode_badge_row.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockModerationLabelService extends Mock
    implements ModerationLabelService {}

class _MockVideoModerationStatusService extends Mock
    implements VideoModerationStatusService {}

class _RebuildHost extends StatefulWidget {
  const _RebuildHost({required this.video, super.key});

  final VideoEvent video;

  @override
  State<_RebuildHost> createState() => _RebuildHostState();
}

class _RebuildHostState extends State<_RebuildHost> {
  int rebuildCount = 0;

  void triggerRebuild() {
    setState(() {
      rebuildCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('rebuild:$rebuildCount'),
        ProofModeBadgeRow(video: widget.video),
      ],
    );
  }
}

void main() {
  late _MockModerationLabelService mockLabelService;
  late _MockVideoModerationStatusService mockVideoModerationStatusService;

  setUp(() async {
    mockLabelService = _MockModerationLabelService();
    mockVideoModerationStatusService = _MockVideoModerationStatusService();
    when(() => mockLabelService.getAIDetectionResult(any())).thenReturn(null);
    when(() => mockLabelService.getAIDetectionByHash(any())).thenReturn(null);
    when(
      () => mockVideoModerationStatusService.fetchStatus(any()),
    ).thenAnswer((_) async => null);
    await LogCaptureService().clearAllLogs();
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
        home: Scaffold(body: ProofModeBadgeRow(video: video)),
      ),
    );
  }

  Widget buildRebuildSubject({
    required VideoEvent video,
    required GlobalKey<_RebuildHostState> hostKey,
  }) {
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
          body: _RebuildHost(key: hostKey, video: video),
        ),
      ),
    );
  }

  group('ProofModeBadgeRow', () {
    testWidgets(
      'shows AI scan pending for proofless Divine-hosted videos without AI',
      (tester) async {
        final video = VideoEvent(
          id: 'divine_no_proof_no_ai',
          pubkey: 'pubkey0',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'plain divine hosted video',
          timestamp: DateTime.now(),
          sha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          videoUrl:
              'https://media.divine.video/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.mp4',
        );

        await tester.pumpWidget(buildSubject(video));
        await tester.pumpAndSettle();

        expect(find.text('AI scan pending'), findsOneWidget);
        expect(find.text('Human Made'), findsNothing);
        expect(find.text('Possibly AI-Generated'), findsNothing);
        expect(find.text('Not Divine Hosted'), findsNothing);
      },
    );

    testWidgets('shows Human Made for scan-only human results', (tester) async {
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

    testWidgets(
      'resolves moderation AI lookup from Divine video URL when sha256 is missing',
      (tester) async {
        const sha256 =
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
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
            aiScore: 0.12,
          ),
        );

        final video = VideoEvent(
          id: 'divine_url_hash_only',
          pubkey: 'pubkey3',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'divine-hosted video without explicit sha',
          timestamp: DateTime.now(),
          videoUrl: 'https://media.divine.video/$sha256.mp4',
        );

        await tester.pumpWidget(buildSubject(video));
        await tester.pumpAndSettle();

        expect(find.text('Human Made'), findsOneWidget);
      },
    );

    testWidgets(
      'resolves moderation AI lookup from Divine HLS URL when sha256 is missing',
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
          id: 'divine_hls_hash_only',
          pubkey: 'pubkey4',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'divine-hosted HLS video without explicit sha',
          timestamp: DateTime.now(),
          videoUrl: 'https://media.divine.video/$sha256/hls/master.m3u8',
        );

        await tester.pumpWidget(buildSubject(video));
        await tester.pumpAndSettle();

        expect(find.text('Human Made'), findsOneWidget);
      },
    );

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

    testWidgets('does not capture badge decision logs during rebuilds', (
      tester,
    ) async {
      final hostKey = GlobalKey<_RebuildHostState>();
      final video = VideoEvent(
        id: 'proof_backed_rebuild_video',
        pubkey: 'pubkey_rebuild',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'proof backed video for rebuild logging',
        timestamp: DateTime.now(),
        videoUrl: 'https://media.divine.video/proof_backed_rebuild_video.mp4',
        rawTags: const {
          'verification': 'verified_mobile',
          'proofmode': '{"proof":"present"}',
        },
      );

      await tester.pumpWidget(
        buildRebuildSubject(video: video, hostKey: hostKey),
      );
      await tester.pump();

      hostKey.currentState!.triggerRebuild();
      await tester.pump();

      hostKey.currentState!.triggerRebuild();
      await tester.pump();

      final proofModeLogs = LogCaptureService()
          .getRecentLogs()
          .where((entry) => entry.name == 'ProofModeBadgeRow')
          .toList();

      expect(proofModeLogs, isEmpty);
    });
  });
}
