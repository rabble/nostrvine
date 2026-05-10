// ABOUTME: Regression coverage for engagement count tag preservation in the
// ABOUTME: edit-video flow. Verifies both the extraction helper contract and
// ABOUTME: the publish path that re-emits loops/likes/reposts/views/comments
// ABOUTME: tags when metadata is edited.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/nip71_migration.dart';
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

class _MockDmRepository extends Mock implements DmRepository {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _FakeCuratedListsState extends CuratedListsState {
  @override
  Future<List<CuratedList>> build() async => const [];
}

class _FakeEvent extends Fake implements Event {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

/// A Vine-imported video whose Nostr event tags include all five engagement
/// count tags. These must survive the republish round-trip unchanged.
VideoEvent _vineVideo({required String pubkey}) {
  return VideoEvent(
    id: 'vine-event-id',
    pubkey: pubkey,
    createdAt: 1700000000,
    content: 'Classic vine content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
    videoUrl: 'https://cdn.example.com/vine.mp4',
    title: 'Classic Vine',
    vineId: 'vine-stable-id',
    nostrEventTags: const [
      ['imeta', 'url https://cdn.example.com/vine.mp4', 'm video/mp4'],
      ['loops', '850000'],
      ['likes', '12000'],
      ['reposts', '3400'],
      ['views', '1000000'],
      ['comments', '4200'],
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
  late _MockDmRepository mockDmRepository;
  late _MockPersonalEventCacheService mockPersonalEventCacheService;
  late _MockVideoEventService mockVideoEventService;
  late List<List<String>> capturedTags;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeVideoEvent());
  });

  setUp(() {
    mockAuthService = createMockAuthService();
    mockNostrService = createMockNostrService();
    mockBookmarkService = _MockBookmarkService();
    mockDmRepository = _MockDmRepository();
    mockPersonalEventCacheService = _MockPersonalEventCacheService();
    mockVideoEventService = _MockVideoEventService();
    capturedTags = [];

    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(ownerPubkey);

    late Event signedEvent;
    when(
      () => mockAuthService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
        createdAt: any(named: 'createdAt'),
      ),
    ).thenAnswer((invocation) async {
      capturedTags = List<List<String>>.from(
        invocation.namedArguments[#tags] as List<List<String>>,
      );
      signedEvent = Event(
        ownerPubkey,
        NIP71VideoKinds.addressableShortVideo,
        capturedTags,
        invocation.namedArguments[#content] as String,
      );
      return signedEvent;
    });

    when(
      () => mockNostrService.publishEvent(any()),
    ).thenAnswer((_) async => PublishSuccess(event: signedEvent));

    when(
      () => mockBookmarkService.isVideoBookmarkedGlobally(any()),
    ).thenReturn(false);
    when(
      () => mockBookmarkService.getVideoBookmarkSummary(any()),
    ).thenReturn('Not bookmarked');
    when(
      () => mockBookmarkService.toggleVideoInGlobalBookmarks(any()),
    ).thenAnswer((_) async => true);

    when(
      () => mockPersonalEventCacheService.cacheUserEvent(any()),
    ).thenReturn(null);
    when(() => mockVideoEventService.updateVideoEvent(any())).thenReturn(null);
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
        dmRepositoryProvider.overrideWithValue(mockDmRepository),
        personalEventCacheServiceProvider.overrideWithValue(
          mockPersonalEventCacheService,
        ),
        videoEventServiceProvider.overrideWithValue(mockVideoEventService),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShareVideoMenu(video: _vineVideo(pubkey: ownerPubkey)),
        ),
      ),
    );
  }

  group('extractEngagementCountTags()', () {
    test('extracts all five engagement tag types', () {
      final tags = [
        ['loops', '850000'],
        ['likes', '12000'],
        ['reposts', '3400'],
        ['views', '1000000'],
        ['comments', '4200'],
        ['title', 'Should be ignored'],
        ['t', 'hashtag'],
      ];
      final result = extractEngagementCountTags(tags);
      expect(result, hasLength(5));
      expect(result.map((t) => t[0]).toSet(), {
        'loops',
        'likes',
        'reposts',
        'views',
        'comments',
      });
    });

    test('preserves tag values exactly', () {
      final tags = [
        ['loops', '42'],
        ['comments', '7'],
      ];
      final result = extractEngagementCountTags(tags);
      expect(result, contains(equals(['loops', '42'])));
      expect(result, contains(equals(['comments', '7'])));
    });

    test('skips tags with no value', () {
      final tags = [
        ['loops'],
        ['likes', '5'],
      ];
      expect(extractEngagementCountTags(tags), hasLength(1));
    });

    test('returns empty list when no engagement tags are present', () {
      final tags = [
        ['d', 'abc'],
        ['title', 'My Video'],
      ];
      expect(extractEngagementCountTags(tags), isEmpty);
    });
  });

  testWidgets(
    'edit-video flow re-emits all engagement count tags in createAndSignEvent',
    (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Open the edit dialog
      await tester.dragUntilVisible(
        find.text(l10n.shareMenuEditVideo),
        find.byType(ShareVideoMenu),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.shareMenuEditVideo));
      await tester.pumpAndSettle();

      // Submit without changing anything
      await tester.ensureVisible(find.text(l10n.shareMenuUpdate));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.shareMenuUpdate));
      await tester.pumpAndSettle();

      // The tags passed to createAndSignEvent must contain all five engagement
      // count tags with their original values intact.
      expect(
        capturedTags,
        contains(equals(['loops', '850000'])),
        reason: 'loops tag must be preserved',
      );
      expect(
        capturedTags,
        contains(equals(['likes', '12000'])),
        reason: 'likes tag must be preserved',
      );
      expect(
        capturedTags,
        contains(equals(['reposts', '3400'])),
        reason: 'reposts tag must be preserved',
      );
      expect(
        capturedTags,
        contains(equals(['views', '1000000'])),
        reason: 'views tag must be preserved',
      );
      expect(
        capturedTags,
        contains(equals(['comments', '4200'])),
        reason: 'comments tag must be preserved',
      );
    },
  );
}
