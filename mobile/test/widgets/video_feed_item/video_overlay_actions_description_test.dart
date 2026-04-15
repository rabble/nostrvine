// ABOUTME: Regression test for tapping descriptions in VideoOverlayActions.
// ABOUTME: Verifies the inline description opens the metadata sheet.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

import '../../helpers/test_provider_overrides.dart';

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

    expect(find.text('Loops'), findsOneWidget);
    expect(find.text('Likes'), findsOneWidget);
  });
}
