// ABOUTME: Widget tests for the video card's date-and-count meta line.
// ABOUTME: Pins that small public counts stay hidden behind the post-date flag.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:reposts_repository/reposts_repository.dart';

import '../../helpers/test_provider_overrides.dart';

const _authorPubkey =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
const _strangerPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _vineEraCreatedAt = 1398124800; // 2014-04-22

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockAuthService extends Mock implements AuthService {}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

VideoEvent _video({
  int? originalLoops,
  Map<String, String> rawTags = const {},
  int? createdAt,
}) {
  final at = createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return VideoEvent(
    id: 'video-card-meta-line-test-0123456789abcdef0123456789abcdef0123',
    pubkey: _authorPubkey,
    createdAt: at,
    content: 'caption',
    timestamp: DateTime.fromMillisecondsSinceEpoch(at * 1000, isUtc: true),
    originalLoops: originalLoops,
    rawTags: rawTags,
  );
}

void main() {
  late _MockVideoInteractionsBloc mockInteractionsBloc;
  late _MockRepostsRepository mockRepostsRepository;
  late _MockAuthService mockAuthService;

  setUp(() {
    mockInteractionsBloc = _MockVideoInteractionsBloc();
    mockRepostsRepository = _MockRepostsRepository();
    mockAuthService = _MockAuthService();

    when(
      () => mockInteractionsBloc.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockInteractionsBloc.state,
    ).thenReturn(const VideoInteractionsState());
    when(
      () => mockRepostsRepository.fetchEventReposters(
        eventId: any(named: 'eventId'),
        addressableId: any(named: 'addressableId'),
      ),
    ).thenAnswer((_) async => const <String>[]);
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(_strangerPubkey);
  });

  Future<void> pump(
    WidgetTester tester, {
    required VideoEvent video,
    required bool postDateEnabled,
    bool viewerIsAuthor = false,
  }) async {
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(
      viewerIsAuthor ? _authorPubkey : _strangerPubkey,
    );

    await tester.pumpWidget(
      testProviderScope(
        additionalOverrides: [
          repostsRepositoryProvider.overrideWithValue(mockRepostsRepository),
          authServiceProvider.overrideWithValue(mockAuthService),
          featureFlagStateProvider.overrideWithValue({
            FeatureFlag.videoCardPostDate: postDateEnabled,
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<VideoInteractionsBloc>.value(
              value: mockInteractionsBloc,
              child: VideoOverlayActions(
                video: video,
                isVisible: true,
                isActive: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String loopLine(WidgetTester tester, int count) => _l10n(
    tester,
  ).videoFeedLoopCountLine(StringUtils.formatCompactNumber(count), count);

  group('video card meta line', () {
    testWidgets('shows the raw loop count when the flag is off', (
      tester,
    ) async {
      await pump(
        tester,
        video: _video(rawTags: {'views': '7'}),
        postDateEnabled: false,
      );

      expect(find.text(loopLine(tester, 7)), findsOneWidget);
    });

    testWidgets('hides a small count from a stranger when the flag is on', (
      tester,
    ) async {
      await pump(
        tester,
        video: _video(rawTags: {'views': '7'}),
        postDateEnabled: true,
      );

      expect(find.text(loopLine(tester, 7)), findsNothing);
      expect(find.textContaining('7 loops'), findsNothing);
    });

    testWidgets('shows a large count to a stranger when the flag is on', (
      tester,
    ) async {
      await pump(
        tester,
        video: _video(rawTags: {'views': '50000'}),
        postDateEnabled: true,
      );

      expect(find.textContaining('50K'), findsOneWidget);
    });

    testWidgets('shows the creator their own small count', (tester) async {
      await pump(
        tester,
        video: _video(rawTags: {'views': '7'}),
        postDateEnabled: true,
        viewerIsAuthor: true,
      );

      expect(find.textContaining('7 loops'), findsOneWidget);
    });

    testWidgets('shows a classic Vine date alongside its archival count', (
      tester,
    ) async {
      await pump(
        tester,
        video: _video(
          originalLoops: 2100000,
          createdAt: _vineEraCreatedAt,
          rawTags: {
            'platform': 'vine',
            'published_at': '$_vineEraCreatedAt',
            'views': '340',
          },
        ),
        postDateEnabled: true,
      );

      // Archival figure only: live diVine views must not inflate it.
      expect(find.textContaining('2.1M loops'), findsOneWidget);
      expect(find.textContaining('Apr 22, 2014'), findsOneWidget);
    });

    testWidgets('shows a relative date on a fresh post', (tester) async {
      await pump(
        tester,
        video: _video(rawTags: {'views': '7'}),
        postDateEnabled: true,
      );

      expect(find.textContaining(_l10n(tester).timeVerboseNow), findsOneWidget);
    });
  });
}
