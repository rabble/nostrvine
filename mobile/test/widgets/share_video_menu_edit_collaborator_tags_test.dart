// ABOUTME: Regression coverage for collaborator p-tags in the edit-video flow.
// ABOUTME: Verifies the shared collaborator tag builder contract and that
// ABOUTME: ShareVideoMenu's edit dialog emits that tag when republishing.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/collaborator_tags.dart';
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

VideoEvent _testVideo({
  required String ownerPubkey,
  required String collaboratorPubkey,
}) {
  return VideoEvent(
    id: 'event-id',
    pubkey: ownerPubkey,
    createdAt: 1757385263,
    content: 'Test video content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
    videoUrl: 'https://cdn.example.com/video.mp4',
    title: 'Test Video Title',
    vineId: 'video-d-tag',
    collaboratorPubkeys: [collaboratorPubkey],
    nostrEventTags: const [
      ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
    ],
  );
}

void main() {
  const ownerPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const collaboratorPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
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
    ).thenAnswer((_) async => signedEvent);

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
          body: ShareVideoMenu(
            video: _testVideo(
              ownerPubkey: ownerPubkey,
              collaboratorPubkey: collaboratorPubkey,
            ),
          ),
        ),
      ),
    );
  }

  test('buildCollaboratorPTag emits the exact lowercase collaborator tag', () {
    expect(
      buildCollaboratorPTag(collaboratorPubkey),
      equals(const [
        'p',
        collaboratorPubkey,
        collaboratorInviteRelayHint,
        'collaborator',
      ]),
    );
  });

  testWidgets(
    'edit-video flow republishes collaborator p-tags with lowercase marker',
    (tester) async {
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

      expect(
        capturedTags.where((tag) => tag.isNotEmpty && tag.first == 'p'),
        hasLength(1),
      );
      expect(
        capturedTags,
        contains(equals(buildCollaboratorPTag(collaboratorPubkey))),
      );
      expect(
        capturedTags,
        isNot(
          contains(
            equals(const [
              'p',
              collaboratorPubkey,
              collaboratorInviteRelayHint,
              'Collaborator',
            ]),
          ),
        ),
      );
    },
  );
}
