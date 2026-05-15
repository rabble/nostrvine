// ABOUTME: Unit tests for VideoMetadataUpdateService.
// ABOUTME: Covers auth guard, video-URL guard, engagement-tag preservation,
// ABOUTME: createdAt bumping, successful publish, publish failure, and
// ABOUTME: invite failure surfaced via inviteFailureCount.

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

const _ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

VideoEvent _testVideo({
  List<List<String>> extraTags = const [],
}) {
  return VideoEvent(
    id: 'event-id',
    pubkey: _ownerPubkey,
    createdAt: 1757385263,
    content: 'Test video content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
    videoUrl: 'https://cdn.example.com/video.mp4',
    title: 'Test Video Title',
    vineId: 'video-d-tag',
    nostrEventTags: [
      const ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
      ...extraTags,
    ],
  );
}

void main() {
  late MockAuthService mockAuthService;
  late MockNostrClient mockNostrService;
  late _MockBlossomUploadService mockBlossomUploadService;
  late _MockDmRepository mockDmRepository;
  late _MockPersonalEventCacheService mockPersonalEventCacheService;
  late _MockVideoEventService mockVideoEventService;
  late VideoMetadataUpdateService service;
  late List<List<String>> capturedTags;
  late int capturedCreatedAt;

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
    capturedCreatedAt = 0;

    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(_ownerPubkey);

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
      capturedCreatedAt = invocation.namedArguments[#createdAt] as int? ?? 0;
      signedEvent = Event(
        _ownerPubkey,
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
    when(() => mockVideoEventService.updateVideoEvent(any())).thenReturn(null);

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

  group(VideoMetadataUpdateService, () {
    group('auth guard', () {
      test('returns VideoUpdateFailure when not authenticated', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);

        final result = await service.updateVideo(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateFailure>());
        verifyNever(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        );
      });
    });

    group('video URL guard', () {
      test(
        'returns VideoUpdateFailure when video has no HTTP URL in imeta tags',
        () async {
          final videoWithNoHttpUrl = VideoEvent(
            id: 'event-id',
            pubkey: _ownerPubkey,
            createdAt: 1757385263,
            content: 'Test',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
            videoUrl: '',
            title: 'Test',
            vineId: 'video-d-tag',
            nostrEventTags: const [
              ['d', 'video-d-tag'],
            ],
          );

          final result = await service.updateVideo(
            originalVideo: videoWithNoHttpUrl,
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateFailure>());
        },
      );
    });

    group('createdAt bumping', () {
      test(
        'signs the event with createdAt = originalVideo.createdAt + 1',
        () async {
          const originalCreatedAt = 1757385263;
          final result = await service.updateVideo(
            originalVideo: _testVideo(),
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(capturedCreatedAt, equals(originalCreatedAt + 1));
        },
      );
    });

    group('engagement tag preservation', () {
      test(
        'preserves all five engagement count tags with exact values',
        () async {
          final video = _testVideo(
            extraTags: const [
              ['loops', '850000'],
              ['likes', '12000'],
              ['reposts', '3400'],
              ['views', '1000000'],
              ['comments', '4200'],
            ],
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(capturedTags, contains(equals(['loops', '850000'])));
          expect(capturedTags, contains(equals(['likes', '12000'])));
          expect(capturedTags, contains(equals(['reposts', '3400'])));
          expect(capturedTags, contains(equals(['views', '1000000'])));
          expect(capturedTags, contains(equals(['comments', '4200'])));
        },
      );

      test('does not include engagement tags when original has none', () async {
        final result = await service.updateVideo(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        final engagementTagNames = {
          'loops',
          'likes',
          'reposts',
          'views',
          'comments',
        };
        final engagementTags = capturedTags.where(
          (t) => t.isNotEmpty && engagementTagNames.contains(t.first),
        );
        expect(engagementTags, isEmpty);
      });
    });

    group('successful publish', () {
      test('returns VideoUpdateSuccess on happy path', () async {
        final result = await service.updateVideo(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
      });

      test('calls publishEvent and cacheUserEvent on success', () async {
        await service.updateVideo(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        verify(() => mockNostrService.publishEvent(any())).called(1);
        verify(
          () => mockPersonalEventCacheService.cacheUserEvent(any()),
        ).called(1);
      });

      test('calls updateVideoEvent on success', () async {
        await service.updateVideo(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        verify(() => mockVideoEventService.updateVideoEvent(any())).called(1);
      });
    });

    group('publish failure', () {
      test(
        'returns VideoUpdateFailure when publishEvent does not succeed',
        () async {
          when(
            () => mockNostrService.publishEvent(any()),
          ).thenAnswer((_) async => const PublishNoRelays());

          final result = await service.updateVideo(
            originalVideo: _testVideo(),
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateFailure>());
          verifyNever(
            () => mockPersonalEventCacheService.cacheUserEvent(any()),
          );
          verifyNever(() => mockVideoEventService.updateVideoEvent(any()));
        },
      );

      test(
        'returns VideoUpdateFailure when createAndSignEvent throws',
        () async {
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          ).thenThrow(Exception('signing failed'));

          final result = await service.updateVideo(
            originalVideo: _testVideo(),
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateFailure>());
          verifyNever(() => mockNostrService.publishEvent(any()));
        },
      );
    });

    group('invite failure', () {
      const newCollaborator =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

      test(
        'returns VideoUpdateSuccess with inviteFailureCount > 0 when DM '
        'send fails for a newly added collaborator',
        () async {
          when(
            () => mockDmRepository.sendMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
              additionalTags: any(named: 'additionalTags'),
              skipNip04Fallback: any(named: 'skipNip04Fallback'),
            ),
          ).thenAnswer(
            (_) async => const NIP17SendResult.failure('relay unreachable'),
          );

          final editorState = VideoEditorProviderState(
            collaboratorPubkeys: const {newCollaborator},
          );

          final result = await service.updateVideo(
            originalVideo: _testVideo(),
            editorState: editorState,
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(
            (result as VideoUpdateSuccess).inviteFailureCount,
            equals(1),
          );
          verify(
            () => mockDmRepository.sendMessage(
              recipientPubkey: newCollaborator,
              content: any(named: 'content'),
              additionalTags: any(named: 'additionalTags'),
              skipNip04Fallback: any(named: 'skipNip04Fallback'),
            ),
          ).called(1);
        },
      );

      test(
        'returns inviteFailureCount = 0 when no new collaborators were added',
        () async {
          final result = await service.updateVideo(
            originalVideo: _testVideo(),
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(
            (result as VideoUpdateSuccess).inviteFailureCount,
            equals(0),
          );
          verifyNever(
            () => mockDmRepository.sendMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
              additionalTags: any(named: 'additionalTags'),
              skipNip04Fallback: any(named: 'skipNip04Fallback'),
            ),
          );
        },
      );
    });
  });
}
