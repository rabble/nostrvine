// ABOUTME: Regression test for tapping descriptions in VideoOverlayActions.
// ABOUTME: Verifies the inline description opens the metadata sheet.

@Tags(['skip_very_good_optimization'])
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

import '../../helpers/test_provider_overrides.dart';

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

class _MockVideoEventService extends Mock implements VideoEventService {}

void main() {
  late _MockVideoInteractionsBloc mockInteractionsBloc;
  late _MockVideoEventService mockVideoEventService;
  late VideoEvent testVideo;

  setUp(() {
    mockInteractionsBloc = _MockVideoInteractionsBloc();
    mockVideoEventService = _MockVideoEventService();

    when(
      () => mockInteractionsBloc.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockInteractionsBloc.state,
    ).thenReturn(const VideoInteractionsState());
    when(
      () => mockVideoEventService.getRepostersForVideo(any()),
    ).thenAnswer((_) async => const <String>[]);

    testVideo = VideoEvent(
      id: 'video-overlay-actions-test-0123456789abcdef0123456789abcdef012345',
      pubkey:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      createdAt: 1757385263,
      content: 'Tap this description',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      videoUrl: 'https://example.com/video.mp4',
      title: 'Test Video',
    );
  });

  testWidgets('opens metadata sheet when tapping description', (tester) async {
    await tester.pumpWidget(
      testProviderScope(
        additionalOverrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<VideoInteractionsBloc>.value(
              value: mockInteractionsBloc,
              child: VideoOverlayActions(
                video: testVideo,
                isVisible: true,
                isActive: true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Tap this description'));
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);
    expect(
      find.text(l10n.metadataLoopsLabel(testVideo.totalLoops)),
      findsOneWidget,
    );
    expect(find.text('Likes'), findsOneWidget);
  });

  testWidgets('author line uses localized singular loop label for 1', (
    tester,
  ) async {
    testVideo = testVideo.copyWith(originalLoops: 1);

    await tester.pumpWidget(
      testProviderScope(
        additionalOverrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<VideoInteractionsBloc>.value(
              value: mockInteractionsBloc,
              child: VideoOverlayActions(
                video: testVideo,
                isVisible: true,
                isActive: true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final l10n = _l10n(tester);
    expect(
      find.text(
        l10n.videoFeedLoopCountLine(StringUtils.formatCompactNumber(1), 1),
      ),
      findsOneWidget,
    );
  });

  testWidgets('author line does not show checkmark for verified NIP-05', (
    tester,
  ) async {
    await tester.pumpWidget(
      testProviderScope(
        additionalOverrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          userProfileReactiveProvider.overrideWith((ref, pubkey) async* {
            yield UserProfile(
              pubkey: pubkey,
              name: 'Alice',
              nip05: 'alice@example.com',
              rawData: const {},
              createdAt: DateTime(2026),
              eventId: 'kind0_event_id',
            );
          }),
          nip05VerificationProvider.overrideWith(
            (ref, pubkey) async => Nip05VerificationStatus.verified,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<VideoInteractionsBloc>.value(
              value: mockInteractionsBloc,
              child: VideoOverlayActions(
                video: testVideo,
                isVisible: true,
                isActive: true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets(
    'author line shows checkmark for Kirsten Swasey special profile',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            userProfileReactiveProvider.overrideWith((ref, pubkey) async* {
              yield UserProfile(
                pubkey: pubkey,
                name: 'Alice',
                nip05: '_@kirstenswasey.divine.video',
                rawData: const {},
                createdAt: DateTime(2026),
                eventId: 'kind0_event_id',
              );
            }),
            nip05VerificationProvider.overrideWith(
              (ref, pubkey) async => Nip05VerificationStatus.verified,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<VideoInteractionsBloc>.value(
                value: mockInteractionsBloc,
                child: VideoOverlayActions(
                  video: testVideo,
                  isVisible: true,
                  isActive: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    },
  );

  testWidgets(
    'does not render a dedicated captions button in the action rail',
    (tester) async {
      final subtitleVideo = testVideo.copyWith(
        textTrackRef: '39307:${testVideo.pubkey}:subtitles:${testVideo.id}',
      );

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<VideoInteractionsBloc>.value(
                value: mockInteractionsBloc,
                child: VideoOverlayActions(
                  video: subtitleVideo,
                  isVisible: true,
                  isActive: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.identifier == 'cc_button',
        ),
        findsNothing,
      );
    },
  );
}
