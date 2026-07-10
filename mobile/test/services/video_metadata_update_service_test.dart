// ABOUTME: Unit tests for VideoMetadataUpdateService.
// ABOUTME: Covers auth guard, video-URL guard, original-tag preservation,
// ABOUTME: edited-field replacement, createdAt bumping, successful publish,
// ABOUTME: publish failure, and invite failure via inviteFailureCount.

import 'dart:ui' show Locale;

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/content_label.dart';
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

    group('original tag preservation', () {
      const audioEventId =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

      test(
        'preserves audio-attribution, provenance, expiration, and hint tags',
        () async {
          final video = _testVideo(
            extraTags: const [
              ['e', audioEventId, 'wss://relay.divine.video', 'audio'],
              ['expiration', '1799999999'],
              ['client', 'divine'],
              ['r', 'wss://relay.divine.video'],
              ['proofmode', 'proof-payload'],
              ['c2pa_manifest_id', 'manifest-123'],
            ],
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(
            capturedTags,
            contains(
              equals(['e', audioEventId, 'wss://relay.divine.video', 'audio']),
            ),
          );
          expect(capturedTags, contains(equals(['expiration', '1799999999'])));
          expect(capturedTags, contains(equals(['client', 'divine'])));
          expect(
            capturedTags,
            contains(equals(['r', 'wss://relay.divine.video'])),
          );
          expect(
            capturedTags,
            contains(equals(['proofmode', 'proof-payload'])),
          );
          expect(
            capturedTags,
            contains(equals(['c2pa_manifest_id', 'manifest-123'])),
          );
        },
      );

      test('preserves reply-threading tags and mention p-tags', () async {
        const rootEventId =
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
        const rootAuthorPubkey =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        const rootAddressableId = '34236:$rootAuthorPubkey:root-vid';
        final video = VideoEvent.fromNostrEvent(
          Event(
            _ownerPubkey,
            NIP71VideoKinds.addressableShortVideo,
            const [
              ['d', 'video-d-tag'],
              [
                'imeta',
                'url https://cdn.example.com/video.mp4',
                'm video/mp4',
              ],
              ['A', rootAddressableId, ''],
              ['P', rootAuthorPubkey],
              ['k', '34236'],
              ['p', rootAuthorPubkey],
              ['a', rootAddressableId, ''],
              ['p', rootAuthorPubkey, 'wss://relay.divine.video', 'mention'],
              ['E', rootEventId, '', rootAuthorPubkey],
              ['K', '34236'],
              ['e', rootEventId, '', rootAuthorPubkey],
            ],
            'Reply video',
            createdAt: 1757385263,
          ),
        );

        expect(video.isVideoReply, isTrue);
        expect(video.inspiredByVideo, isNotNull);

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(
            inspiredByVideo: video.inspiredByVideo,
          ),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          contains(equals(['E', rootEventId, '', rootAuthorPubkey])),
        );
        expect(capturedTags, contains(equals(['K', '34236'])));
        expect(
          capturedTags,
          contains(equals(['e', rootEventId, '', rootAuthorPubkey])),
        );
        final addressableTags = capturedTags
            .where((tag) => tag.isNotEmpty && tag.first == 'a')
            .toList();
        expect(addressableTags, [
          ['a', rootAddressableId, ''],
        ]);
        expect(capturedTags, contains(equals(['p', rootAuthorPubkey])));
        expect(
          capturedTags,
          contains(
            equals([
              'p',
              rootAuthorPubkey,
              'wss://relay.divine.video',
              'mention',
            ]),
          ),
        );
      });

      test('removes collaborator tags with mixed-case markers', () async {
        const removedCollaborator =
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
        final video = _testVideo(
          extraTags: const [
            [
              'p',
              removedCollaborator,
              'wss://relay.divine.video',
              'Collaborator',
            ],
          ],
        );

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {removedCollaborator},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          isNot(
            contains(
              equals([
                'p',
                removedCollaborator,
                'wss://relay.divine.video',
                'Collaborator',
              ]),
            ),
          ),
        );
        expect(
          capturedTags.where(
            (tag) =>
                tag.length >= 2 &&
                tag.first == 'p' &&
                tag[1] == removedCollaborator,
          ),
          isEmpty,
        );
      });

      test(
        'does not duplicate the d tag when the original carries one',
        () async {
          final video = _testVideo(
            extraTags: const [
              ['d', 'video-d-tag'],
            ],
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          final dTags = capturedTags.where(
            (t) => t.isNotEmpty && t.first == 'd',
          );
          expect(dTags, hasLength(1));
          expect(capturedTags, contains(equals(['d', 'video-d-tag'])));
        },
      );
    });

    group('edited field replacement', () {
      test(
        'replaces title, summary, and hashtags without duplicates',
        () async {
          final video = _testVideo(
            extraTags: const [
              ['title', 'Old Title'],
              ['summary', 'Old description'],
              ['t', 'oldtag'],
            ],
          );
          final editorState = VideoEditorProviderState(
            title: 'New Title',
            description: 'New description',
            tags: const {'newtag'},
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: editorState,
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(capturedTags, contains(equals(['title', 'New Title'])));
          expect(capturedTags, isNot(contains(equals(['title', 'Old Title']))));
          expect(
            capturedTags,
            contains(equals(['summary', 'New description'])),
          );
          expect(
            capturedTags,
            isNot(contains(equals(['summary', 'Old description']))),
          );
          expect(capturedTags, contains(equals(['t', 'newtag'])));
          expect(capturedTags, isNot(contains(equals(['t', 'oldtag']))));
        },
      );

      test(
        'removes the content-warning group when warnings are cleared',
        () async {
          final video = _testVideo(
            extraTags: const [
              ['content-warning', 'nudity'],
              ['L', 'content-warning'],
              ['l', 'nudity', 'content-warning'],
              ['L', 'ISO-639-1'],
              ['l', 'en', 'ISO-639-1'],
            ],
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          final warningTags = capturedTags.where(
            (t) => t.isNotEmpty && t.first == 'content-warning',
          );
          expect(warningTags, isEmpty);
          expect(
            capturedTags,
            isNot(contains(equals(['L', 'content-warning']))),
          );
          expect(
            capturedTags,
            isNot(contains(equals(['l', 'nudity', 'content-warning']))),
          );
          expect(capturedTags, contains(equals(['L', 'ISO-639-1'])));
          expect(capturedTags, contains(equals(['l', 'en', 'ISO-639-1'])));
        },
      );

      test('rewrites the full NIP-36 group when warnings change', () async {
        final video = _testVideo(
          extraTags: const [
            ['content-warning', 'nudity'],
            ['L', 'content-warning'],
            ['l', 'nudity', 'content-warning'],
          ],
        );
        final editorState = VideoEditorProviderState(
          contentWarnings: const {ContentLabel.violence},
        );

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: editorState,
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          contains(equals(['content-warning', 'violence'])),
        );
        expect(capturedTags, contains(equals(['L', 'content-warning'])));
        expect(
          capturedTags,
          contains(equals(['l', 'violence', 'content-warning'])),
        );
        expect(
          capturedTags,
          isNot(contains(equals(['content-warning', 'nudity']))),
        );
        expect(
          capturedTags,
          isNot(contains(equals(['l', 'nudity', 'content-warning']))),
        );
      });

      test('replaces collaborator p-tags but keeps mention p-tags', () async {
        const removedCollaborator =
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
        const mentionedPubkey =
            '1111111111111111111111111111111111111111111111111111111111111111';
        final video = _testVideo(
          extraTags: const [
            [
              'p',
              removedCollaborator,
              'wss://relay.divine.video',
              'collaborator',
            ],
            ['p', mentionedPubkey, 'wss://relay.divine.video', 'mention'],
          ],
        );

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {removedCollaborator},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          isNot(
            contains(
              equals([
                'p',
                removedCollaborator,
                'wss://relay.divine.video',
                'collaborator',
              ]),
            ),
          ),
        );
        expect(
          capturedTags,
          contains(
            equals([
              'p',
              mentionedPubkey,
              'wss://relay.divine.video',
              'mention',
            ]),
          ),
        );
      });

      test('replaces the inspired-by a-tag without duplicating it', () async {
        final video = _testVideo(
          extraTags: const [
            [
              'a',
              '34236:$_ownerPubkey:old-vid',
              'wss://relay.divine.video',
              'mention',
            ],
          ],
        );
        final editorState = VideoEditorProviderState(
          inspiredByVideo: const InspiredByInfo(
            addressableId: '34236:$_ownerPubkey:new-vid',
            relayUrl: 'wss://relay.divine.video',
          ),
        );

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: editorState,
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          contains(
            equals([
              'a',
              '34236:$_ownerPubkey:new-vid',
              'wss://relay.divine.video',
              'inspired-by',
            ]),
          ),
        );
        expect(
          capturedTags,
          isNot(
            contains(
              equals([
                'a',
                '34236:$_ownerPubkey:old-vid',
                'wss://relay.divine.video',
                'mention',
              ]),
            ),
          ),
        );
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
