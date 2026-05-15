// ABOUTME: Regression coverage for the extractEngagementCountTags helper.
// ABOUTME: Verifies the extraction contract for loops/likes/reposts/views/comments
// ABOUTME: tags that must be preserved when video metadata is edited.

import 'dart:ui' show Locale;

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_metadata_update_service.dart';

import '../helpers/test_provider_overrides.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _FakeEvent extends Fake implements Event {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

void main() {
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

  group('VideoMetadataUpdateService engagement tags', () {
    const ownerPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    late MockAuthService mockAuthService;
    late MockNostrClient mockNostrService;
    late _MockBlossomUploadService mockBlossomUploadService;
    late _MockDmRepository mockDmRepository;
    late _MockPersonalEventCacheService mockPersonalEventCacheService;
    late _MockVideoEventService mockVideoEventService;
    late VideoMetadataUpdateService service;
    late List<List<String>> capturedTags;

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
      registerFallbackValue(_FakeVideoEvent());
    });

    setUp(() {
      mockAuthService = createMockAuthService();
      mockNostrService = createMockNostrService();
      mockBlossomUploadService = _MockBlossomUploadService();
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
        () => mockPersonalEventCacheService.cacheUserEvent(any()),
      ).thenReturn(null);
      when(
        () => mockVideoEventService.updateVideoEvent(any()),
      ).thenReturn(null);

      service = VideoMetadataUpdateService(
        authService: mockAuthService,
        blossomService: mockBlossomUploadService,
        nostrService: mockNostrService,
        personalEventCache: mockPersonalEventCacheService,
        videoEventService: mockVideoEventService,
        collaboratorInviteService: CollaboratorInviteService(
          dmRepository: mockDmRepository,
          l10n: lookupAppLocalizations(const Locale('en')),
        ),
      );
    });

    test(
      'republishes all five engagement count tags with exact values preserved',
      () async {
        final originalVideo = VideoEvent(
          id: 'event-id',
          pubkey: ownerPubkey,
          createdAt: 1757385263,
          content: 'Test video content',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
          videoUrl: 'https://cdn.example.com/video.mp4',
          title: 'Test Video Title',
          vineId: 'video-d-tag',
          nostrEventTags: const [
            ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
            ['loops', '850000'],
            ['likes', '12000'],
            ['reposts', '3400'],
            ['views', '1000000'],
            ['comments', '4200'],
          ],
        );

        final result = await service.updateVideo(
          originalVideo: originalVideo,
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        final engagementTags = capturedTags
            .where(
              (t) =>
                  t.isNotEmpty &&
                  {
                    'loops',
                    'likes',
                    'reposts',
                    'views',
                    'comments',
                  }.contains(t.first),
            )
            .toList();
        expect(engagementTags, hasLength(5));
        expect(capturedTags, contains(equals(['loops', '850000'])));
        expect(capturedTags, contains(equals(['likes', '12000'])));
        expect(capturedTags, contains(equals(['reposts', '3400'])));
        expect(capturedTags, contains(equals(['views', '1000000'])));
        expect(capturedTags, contains(equals(['comments', '4200'])));
      },
    );
  });
}
