// ABOUTME: Widget tests for PublishNoRelays and PublishFailed branches in the
// ABOUTME: ShareVideoMenu edit-video flow. Verifies that the snackbar is shown
// ABOUTME: for both failure variants and that it does NOT contain raw
// ABOUTME: branch-detail strings ('no relays connected', 'send error').

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/share_video_menu.dart';

import '../helpers/test_provider_overrides.dart';

class _MockBookmarkService extends Mock implements BookmarkService {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _FakeCuratedListsState extends CuratedListsState {
  @override
  Future<List<CuratedList>> build() async => const [];
}

class _FakeEvent extends Fake implements Event {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

VideoEvent _testVideo({required String ownerPubkey}) {
  return VideoEvent(
    id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    pubkey: ownerPubkey,
    createdAt: 1757385263,
    content: 'Test video content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
    videoUrl: 'https://cdn.example.com/video.mp4',
    title: 'Test Video Title',
    vineId: 'video-d-tag',
    nostrEventTags: const [
      ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
    ],
  );
}

void main() {
  const ownerPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  final l10n = lookupAppLocalizations(const Locale('en'));

  late MockAuthService mockAuthService;
  late MockNostrClient mockNostrService;
  late _MockBookmarkService mockBookmarkService;
  late _MockPersonalEventCacheService mockPersonalEventCacheService;
  late _MockVideoEventService mockVideoEventService;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeVideoEvent());
  });

  setUp(() {
    mockAuthService = createMockAuthService();
    mockNostrService = createMockNostrService();
    mockBookmarkService = _MockBookmarkService();
    mockPersonalEventCacheService = _MockPersonalEventCacheService();
    mockVideoEventService = _MockVideoEventService();

    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(ownerPubkey);

    when(
      () => mockAuthService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
        createdAt: any(named: 'createdAt'),
      ),
    ).thenAnswer((invocation) async {
      final tags = invocation.namedArguments[#tags] as List<List<String>>;
      final content = invocation.namedArguments[#content] as String;
      return Event(
        ownerPubkey,
        NIP71VideoKinds.addressableShortVideo,
        tags,
        content,
      );
    });

    when(
      () => mockBookmarkService.isVideoBookmarkedGlobally(any()),
    ).thenReturn(false);
    when(
      () => mockBookmarkService.getVideoBookmarkSummary(any()),
    ).thenReturn('Not bookmarked');
    when(
      () => mockBookmarkService.toggleVideoInGlobalBookmarks(any()),
    ).thenAnswer((_) async => true);
  });

  Widget buildSubject() {
    return testProviderScope(
      mockAuthService: mockAuthService,
      mockNostrService: mockNostrService,
      additionalOverrides: [
        bookmarkServiceProvider.overrideWith((ref) => mockBookmarkService),
        curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
        isFeatureEnabledProvider(
          FeatureFlag.curatedLists,
        ).overrideWithValue(false),
        isFeatureEnabledProvider(
          FeatureFlag.debugTools,
        ).overrideWithValue(false),
        personalEventCacheServiceProvider.overrideWithValue(
          mockPersonalEventCacheService,
        ),
        videoEventServiceProvider.overrideWithValue(mockVideoEventService),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShareVideoMenu(video: _testVideo(ownerPubkey: ownerPubkey)),
        ),
      ),
    );
  }

  /// Pumps the widget and taps through to the Update button in the edit dialog.
  Future<void> openEditDialogAndTapUpdate(WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text(l10n.shareMenuEditVideo),
      find.byType(ShareVideoMenu),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.shareMenuEditVideo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(l10n.shareMenuUpdate));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.shareMenuUpdate));
    await tester.pumpAndSettle();
  }

  group('ShareVideoMenu edit-video publish failure branches', () {
    testWidgets(
      'PublishNoRelays: shows failure snackbar without branch-detail string',
      (tester) async {
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) async => const PublishNoRelays());

        await openEditDialogAndTapUpdate(tester);

        // Generic failure snackbar should appear.
        expect(find.byType(SnackBar), findsOneWidget);

        // The snackbar text must contain the localized failure prefix.
        // shareMenuFailedToUpdateVideo takes an error arg; matching on the
        // prefix ensures the localized key is used rather than a raw string.
        const publishFailureMessage = 'Failed to publish updated event';
        expect(
          find.textContaining(
            l10n.shareMenuFailedToUpdateVideo(
              'Exception: $publishFailureMessage',
            ),
          ),
          findsOneWidget,
        );

        // Raw branch detail must NOT leak into user-visible text.
        expect(find.textContaining('no relays connected'), findsNothing);
        expect(find.textContaining('send error'), findsNothing);
      },
    );

    testWidgets(
      'PublishFailed: shows failure snackbar without branch-detail string',
      (tester) async {
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());

        await openEditDialogAndTapUpdate(tester);

        // Generic failure snackbar should appear.
        expect(find.byType(SnackBar), findsOneWidget);

        // The snackbar text must contain the localized failure prefix.
        const publishFailureMessage = 'Failed to publish updated event';
        expect(
          find.textContaining(
            l10n.shareMenuFailedToUpdateVideo(
              'Exception: $publishFailureMessage',
            ),
          ),
          findsOneWidget,
        );

        // Raw branch detail must NOT leak into user-visible text.
        expect(find.textContaining('no relays connected'), findsNothing);
        expect(find.textContaining('send error'), findsNothing);
      },
    );
  });
}
