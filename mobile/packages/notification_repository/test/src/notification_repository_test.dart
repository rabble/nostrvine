// ABOUTME: Tests for NotificationRepository — covers enrichment, video-anchored
// ABOUTME: grouping by (referencedEventId, kind), follow consolidation, type
// ABOUTME: mapping, comment truncation, and the realtime enrichOne path.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:test/test.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockNotificationsDao extends Mock implements NotificationsDao {}

void main() {
  late _MockFunnelcakeApiClient funnelcakeApiClient;
  late _MockProfileRepository profileRepository;
  late _MockNotificationsDao notificationsDao;
  late NotificationRepository repository;

  const userPubkey = 'user1234567890abcdef';

  setUp(() {
    funnelcakeApiClient = _MockFunnelcakeApiClient();
    profileRepository = _MockProfileRepository();
    notificationsDao = _MockNotificationsDao();
    when(
      () => funnelcakeApiClient.notificationsUri(
        pubkey: any(named: 'pubkey'),
        limit: any(named: 'limit'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((invocation) {
      final pubkey = invocation.namedArguments[#pubkey] as String;
      final limit = invocation.namedArguments[#limit] as int? ?? 50;
      final cursor = invocation.namedArguments[#cursor] as String?;
      final effectiveBefore =
          cursor ?? DateTime.now().millisecondsSinceEpoch.toString();
      return Uri.parse(
        'https://api.example.com/api/users/$pubkey/notifications',
      ).replace(
        queryParameters: <String, String>{
          'limit': '$limit',
          'before': effectiveBefore,
        },
      );
    });
    // Default: getVideoStats throws (no metadata fetched). Tests that need a
    // thumbnail override this stub explicitly.
    when(
      () => funnelcakeApiClient.getVideoStats(any()),
    ).thenThrow(const FunnelcakeException('no stats'));
    repository = NotificationRepository(
      funnelcakeApiClient: funnelcakeApiClient,
      profileRepository: profileRepository,
      notificationsDao: notificationsDao,
      userPubkey: userPubkey,
    );
  });

  /// Helper to create a [RelayNotification] with sensible defaults.
  ///
  /// Defaults to a like notification with a non-null `referencedEventId`
  /// so the repository keeps it as a [VideoNotification]. Tests that want
  /// it dropped should pass `referencedEventId: null` explicitly.
  RelayNotification makeNotification({
    String id = 'n1',
    String sourcePubkey = 'pubkey_alice',
    String sourceEventId = 'evt1',
    int sourceKind = 7,
    String notificationType = 'reaction',
    DateTime? createdAt,
    bool read = false,
    String? referencedEventId = 'video_default',
    String? referencedDTag,
    String? content,
    bool isReferencedVideo = true,
  }) {
    return RelayNotification(
      id: id,
      sourcePubkey: sourcePubkey,
      sourceEventId: sourceEventId,
      sourceKind: sourceKind,
      notificationType: notificationType,
      createdAt: createdAt ?? DateTime(2025),
      read: read,
      referencedEventId: referencedEventId,
      referencedDTag: referencedDTag,
      content: content,
      isReferencedVideo: isReferencedVideo,
    );
  }

  void stubProfiles(Map<String, UserProfile> profiles) {
    when(
      () =>
          profileRepository.fetchBatchProfiles(pubkeys: any(named: 'pubkeys')),
    ).thenAnswer((_) async => profiles);
  }

  void stubNotifications(
    List<RelayNotification> notifications, {
    int unreadCount = 0,
    bool hasMore = false,
    String? nextCursor,
  }) {
    when(
      () => funnelcakeApiClient.getNotifications(
        pubkey: any(named: 'pubkey'),
        cursor: any(named: 'cursor'),
        requestUri: any(named: 'requestUri'),
        authHeaders: any(named: 'authHeaders'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => NotificationResponse(
        notifications: notifications,
        unreadCount: unreadCount,
        hasMore: hasMore,
        nextCursor: nextCursor,
      ),
    );
  }

  /// Stubs `getVideoStats(eventId)` to return [stats].
  void stubVideoStats(String eventId, VideoStats stats) {
    when(
      () => funnelcakeApiClient.getVideoStats(eventId),
    ).thenAnswer((_) async => stats);
  }

  UserProfile makeProfile(
    String pubkey, {
    String? displayName,
    String? picture,
  }) {
    return UserProfile(
      pubkey: pubkey,
      rawData: const {},
      createdAt: DateTime(2024),
      eventId: 'evt_$pubkey',
      displayName: displayName,
      picture: picture,
    );
  }

  VideoStats makeVideoStats({
    required String id,
    String? thumbnail,
    String? title,
  }) {
    return VideoStats(
      id: id,
      pubkey: 'author_pub',
      createdAt: DateTime(2025),
      kind: 34236,
      dTag: 'd_$id',
      title: title ?? '',
      thumbnail: thumbnail ?? '',
      videoUrl: 'https://example.com/$id.mp4',
      reactions: 0,
      comments: 0,
      reposts: 0,
      engagementScore: 0,
    );
  }

  group(NotificationRepository, () {
    group('getNotifications', () {
      test('signs the full first-page notifications URL', () async {
        var signedUrl = '';
        var signedMethod = '';
        repository = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
          authHeadersProvider: (url, method) async {
            signedUrl = url;
            signedMethod = method;
            return {'Authorization': 'Nostr test-token'};
          },
        );
        stubNotifications([]);
        stubProfiles({});

        await repository.getNotifications();

        final signedUri = Uri.parse(signedUrl);
        expect(
          '${signedUri.scheme}://${signedUri.host}${signedUri.path}',
          equals('https://api.example.com/api/users/$userPubkey/notifications'),
        );
        expect(signedUri.queryParameters['limit'], equals('50'));
        expect(signedUri.queryParameters['before'], isNotNull);
        expect(int.tryParse(signedUri.queryParameters['before']!), isNotNull);
        expect(signedMethod, equals('GET'));
      });

      test('signs the full paginated notifications URL with cursor', () async {
        var signedUrl = '';
        repository = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
          authHeadersProvider: (url, method) async {
            signedUrl = url;
            return {'Authorization': 'Nostr test-token'};
          },
        );
        stubNotifications([], nextCursor: 'cursor_abc', hasMore: true);
        stubProfiles({});

        await repository.getNotifications();
        stubNotifications([], nextCursor: 'cursor_def');

        await repository.getNotifications();

        expect(
          signedUrl,
          equals(
            'https://api.example.com/api/users/$userPubkey/notifications'
            '?limit=50&before=cursor_abc',
          ),
        );
      });

      test('one like becomes a $VideoNotification with totalCount 1', () async {
        stubNotifications([
          makeNotification(
            sourcePubkey: 'alice_pub',
            referencedEventId: 'video1',
          ),
        ]);
        stubVideoStats(
          'video1',
          makeVideoStats(id: 'video1', thumbnail: 'thumb', title: 'Hello'),
        );
        stubProfiles({
          'alice_pub': makeProfile(
            'alice_pub',
            displayName: 'Alice',
            picture: 'https://example.com/alice.jpg',
          ),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(item.actors, hasLength(1));
        expect(item.actors.first.displayName, equals('Alice'));
        expect(
          item.actors.first.pictureUrl,
          equals('https://example.com/alice.jpg'),
        );
        expect(item.totalCount, equals(1));
        expect(item.videoEventId, equals('video1'));
        expect(item.videoThumbnailUrl, equals('thumb'));
        expect(item.videoTitle, equals('Hello'));
      });

      test('falls back to "Unknown user" for missing profiles', () async {
        stubNotifications([makeNotification(sourcePubkey: 'unknown_pub')]);
        stubProfiles({});

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.first as VideoNotification;
        expect(item.actors.first.displayName, equals('Unknown user'));
        expect(item.actors.first.pictureUrl, isNull);
      });

      test('rethrows on API error after logging', () async {
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const FunnelcakeException('network error'));

        await expectLater(
          repository.getNotifications(),
          throwsA(isA<FunnelcakeException>()),
        );

        // BehaviorSubject preserves its prior value across the throw —
        // the seeded NotificationPage.empty stays as the snapshot value
        // so downstream consumers don't see a spurious update.
        final snapshot = await repository.watchSnapshot().first;
        expect(snapshot, equals(NotificationPage.empty));
      });

      test('preserves populated snapshot when refresh throws', () async {
        // First refresh succeeds and populates the snapshot.
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 1);
        await repository.refresh();
        final populated = await repository.watchSnapshot().first;
        expect(populated.items, hasLength(1));

        // Second refresh throws — the snapshot must keep the populated
        // page from the first refresh, not revert to empty. This pins
        // the design contract that lets the BLoC's failure state coexist
        // with previously-loaded data (the BehaviorSubject value the
        // snapshot stream emits to subscribers stays at the populated
        // page).
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const FunnelcakeException('network error'));

        await expectLater(
          repository.refresh(),
          throwsA(isA<FunnelcakeException>()),
        );

        final after = await repository.watchSnapshot().first;
        expect(after, equals(populated));
      });

      test('repeated throws keep snapshot stable', () async {
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const FunnelcakeException('network error'));

        await expectLater(
          repository.getNotifications(),
          throwsA(isA<FunnelcakeException>()),
        );
        await expectLater(
          repository.getNotifications(),
          throwsA(isA<FunnelcakeException>()),
        );

        // Two consecutive throws must not corrupt the snapshot or leave
        // the repository in a degraded state — the seeded empty page
        // remains the live snapshot value.
        final snapshot = await repository.watchSnapshot().first;
        expect(snapshot, equals(NotificationPage.empty));
      });

      test('passes cursor for pagination', () async {
        stubNotifications([], nextCursor: 'cursor_abc', hasMore: true);
        stubProfiles({});

        final page = await repository.getNotifications();
        expect(page.nextCursor, equals('cursor_abc'));
        expect(page.hasMore, isTrue);

        stubNotifications([], nextCursor: 'cursor_def');

        await repository.getNotifications();

        verify(
          () => funnelcakeApiClient.getNotifications(
            pubkey: userPubkey,
            cursor: 'cursor_abc',
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).called(1);
      });

      test(
        'passes the same first-page URI to signing and request execution',
        () async {
          var signedUrl = '';
          Uri? requestedUri;
          repository = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
            authHeadersProvider: (url, method) async {
              signedUrl = url;
              return {'Authorization': 'Nostr test-token'};
            },
          );
          stubNotifications([]);
          stubProfiles({});

          await repository.getNotifications();

          requestedUri =
              verify(
                    () => funnelcakeApiClient.getNotifications(
                      pubkey: userPubkey,
                      cursor: any(named: 'cursor'),
                      requestUri: captureAny(named: 'requestUri'),
                      authHeaders: any(named: 'authHeaders'),
                      limit: any(named: 'limit'),
                    ),
                  ).captured.single
                  as Uri;

          expect(requestedUri.toString(), equals(signedUrl));
        },
      );

      test(
        'passes the same paginated URI to signing and request execution',
        () async {
          var signedUrl = '';
          Uri? requestedUri;
          repository = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
            authHeadersProvider: (url, method) async {
              signedUrl = url;
              return {'Authorization': 'Nostr test-token'};
            },
          );
          stubNotifications([], nextCursor: 'cursor_abc', hasMore: true);
          stubProfiles({});

          await repository.getNotifications();
          stubNotifications([], nextCursor: 'cursor_def');

          await repository.getNotifications();

          requestedUri =
              verify(
                    () => funnelcakeApiClient.getNotifications(
                      pubkey: userPubkey,
                      cursor: 'cursor_abc',
                      requestUri: captureAny(named: 'requestUri'),
                      authHeaders: any(named: 'authHeaders'),
                      limit: any(named: 'limit'),
                    ),
                  ).captured.single
                  as Uri;

          expect(requestedUri.toString(), equals(signedUrl));
        },
      );
    });

    group('video-anchored grouping', () {
      test('5 likes on same video become 1 $VideoNotification '
          'with totalCount 5 and 3 actors', () async {
        stubNotifications([
          for (var i = 0; i < 5; i++)
            makeNotification(
              id: 'l$i',
              sourcePubkey: 'pub_$i',
              referencedEventId: 'video_x',
              createdAt: DateTime(2025, 1, 5 - i),
            ),
        ]);
        stubProfiles({
          for (var i = 0; i < 5; i++)
            'pub_$i': makeProfile('pub_$i', displayName: 'Actor$i'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.like));
        expect(item.totalCount, equals(5));
        // Cap is 3 actors for the stack.
        expect(item.actors, hasLength(3));
        // Newest first — pub_0 had the latest createdAt.
        expect(item.actors.first.displayName, equals('Actor0'));
        expect(item.videoEventId, equals('video_x'));
      });

      test('grouped video notifications build addressable id from '
          'user pubkey and d-tag', () async {
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: 'pub_a',
            referencedEventId: 'video_x',
            referencedDTag: 'vine-id',
          ),
          makeNotification(
            id: 'l2',
            sourcePubkey: 'pub_b',
            referencedEventId: 'video_x',
            referencedDTag: 'vine-id',
          ),
        ]);
        stubProfiles({
          'pub_a': makeProfile('pub_a', displayName: 'Alice'),
          'pub_b': makeProfile('pub_b', displayName: 'Bob'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(
          item.videoAddressableId,
          equals(
            '${NIP71VideoKinds.addressableShortVideo}:'
            '$userPubkey:vine-id',
          ),
        );
      });

      test('grouped video notifications leave addressable id null when d-tag '
          'is null or empty', () async {
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: 'pub_a',
            referencedEventId: 'video_x',
            referencedDTag: '',
          ),
          makeNotification(
            id: 'l2',
            sourcePubkey: 'pub_b',
            referencedEventId: 'video_x',
          ),
        ]);
        stubProfiles({
          'pub_a': makeProfile('pub_a', displayName: 'Alice'),
          'pub_b': makeProfile('pub_b', displayName: 'Bob'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(item.videoAddressableId, isNull);
      });

      test(
        '5 likes on 5 different videos produce 5 ${VideoNotification}s',
        () async {
          stubNotifications([
            for (var i = 0; i < 5; i++)
              makeNotification(
                id: 'l$i',
                sourcePubkey: 'pub_$i',
                referencedEventId: 'video_$i',
                createdAt: DateTime(2025, 1, 5 - i),
              ),
          ]);
          stubProfiles({
            for (var i = 0; i < 5; i++)
              'pub_$i': makeProfile('pub_$i', displayName: 'Actor$i'),
          });

          final page = await repository.getNotifications();

          expect(page.items, hasLength(5));
          for (final item in page.items) {
            expect(item, isA<VideoNotification>());
            expect((item as VideoNotification).totalCount, equals(1));
          }
        },
      );

      test('likes + comments on same video become 2 ${VideoNotification}s '
          'differing by kind', () async {
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: 'pub_a',
            referencedEventId: 'video_x',
          ),
          makeNotification(
            id: 'c1',
            sourcePubkey: 'pub_b',
            notificationType: 'comment',
            sourceKind: 1,
            referencedEventId: 'video_x',
            content: 'Cool',
          ),
        ]);
        stubProfiles({
          'pub_a': makeProfile('pub_a', displayName: 'Alice'),
          'pub_b': makeProfile('pub_b', displayName: 'Bob'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(2));
        final kinds = page.items
            .whereType<VideoNotification>()
            .map((v) => v.type)
            .toSet();
        expect(
          kinds,
          equals({NotificationKind.like, NotificationKind.comment}),
        );
      });

      test(
        'video-anchored notification with null referencedEventId is dropped',
        () async {
          stubNotifications([
            makeNotification(sourcePubkey: 'pub_a', referencedEventId: null),
          ]);
          stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

          final page = await repository.getNotifications();

          expect(page.items, isEmpty);
        },
      );

      test(
        'getVideoStats throws → row still rendered with null thumbnail',
        () async {
          stubNotifications([
            makeNotification(
              sourcePubkey: 'pub_a',
              referencedEventId: 'video_x',
            ),
          ]);
          stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});
          when(
            () => funnelcakeApiClient.getVideoStats('video_x'),
          ).thenThrow(const FunnelcakeException('boom'));

          final page = await repository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.single as VideoNotification;
          expect(item.videoThumbnailUrl, isNull);
          expect(item.videoTitle, isNull);
        },
      );
    });

    group('follow consolidation', () {
      test('2 follows from same pubkey become 1 $ActorNotification '
          'with earliest timestamp', () async {
        final earlier = DateTime(2025);
        final later = DateTime(2025, 1, 5);
        stubNotifications([
          makeNotification(
            id: 'f1',
            sourcePubkey: 'follower_pub',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
            createdAt: later,
          ),
          makeNotification(
            id: 'f2',
            sourcePubkey: 'follower_pub',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
            createdAt: earlier,
          ),
        ]);
        stubProfiles({
          'follower_pub': makeProfile('follower_pub', displayName: 'Follower'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.follow));
        expect(item.timestamp, equals(earlier));
      });

      test('follows from different pubkeys are not consolidated', () async {
        stubNotifications([
          makeNotification(
            id: 'f1',
            sourcePubkey: 'pub_a',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
          ),
          makeNotification(
            id: 'f2',
            sourcePubkey: 'pub_b',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
          ),
        ]);
        stubProfiles({
          'pub_a': makeProfile('pub_a', displayName: 'Alice'),
          'pub_b': makeProfile('pub_b', displayName: 'Bob'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(2));
      });
    });

    group('comments stay individual when on different videos', () {
      test(
        'comments on different videos are 2 separate ${VideoNotification}s',
        () async {
          stubNotifications([
            makeNotification(
              id: 'c1',
              sourcePubkey: 'pub_a',
              notificationType: 'comment',
              sourceKind: 1,
              referencedEventId: 'video_a',
              content: 'Great video!',
            ),
            makeNotification(
              id: 'c2',
              sourcePubkey: 'pub_b',
              notificationType: 'comment',
              sourceKind: 1,
              referencedEventId: 'video_b',
              content: 'Amazing!',
            ),
          ]);
          stubProfiles({
            'pub_a': makeProfile('pub_a', displayName: 'Alice'),
            'pub_b': makeProfile('pub_b', displayName: 'Bob'),
          });

          final page = await repository.getNotifications();

          expect(page.items, hasLength(2));
          expect(page.items[0], isA<VideoNotification>());
          expect(page.items[1], isA<VideoNotification>());
        },
      );
    });

    group('type mapping', () {
      test('reaction on a video maps to like', () async {
        stubNotifications([makeNotification()]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.like));
      });

      test('reaction on a non-video target maps to likeComment '
          '($ActorNotification)', () async {
        stubNotifications([makeNotification(isReferencedVideo: false)]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.likeComment));
      });

      test('likeComment carries referencedEventId as targetEventId', () async {
        stubNotifications([
          makeNotification(
            isReferencedVideo: false,
            referencedEventId: 'comment_event_xyz',
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.likeComment));
        expect(item.targetEventId, equals('comment_event_xyz'));
      });

      test(
        'likeComment carries videoAddressableId when referencedDTag is set',
        () async {
          // When the server provides the d_tag for the video the comment was
          // on, the repository builds the stable NIP-33 addressable ID so the
          // tap handler can skip the resolver entirely.
          stubNotifications([
            makeNotification(
              isReferencedVideo: false,
              referencedEventId: 'comment_event_xyz',
              referencedDTag: 'vine-abc',
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as ActorNotification;
          expect(item.type, equals(NotificationKind.likeComment));
          expect(
            item.videoAddressableId,
            equals('34236:$userPubkey:vine-abc'),
          );
        },
      );

      test(
        'likeComment videoAddressableId is null when referencedDTag is absent',
        () async {
          stubNotifications([
            makeNotification(
              isReferencedVideo: false,
              referencedEventId: 'comment_event_xyz',
              // referencedDTag intentionally omitted
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as ActorNotification;
          expect(item.videoAddressableId, isNull);
        },
      );

      test('reply on a video maps to comment ($VideoNotification)', () async {
        stubNotifications([
          makeNotification(notificationType: 'reply', sourceKind: 1),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        // A reply directly on a video is indistinguishable from a comment
        // for the user, so it lands in the comment grouping path.
        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.comment));
      });

      test('reply on a non-video target maps to reply ($ActorNotification) '
          'with targetEventId', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'reply',
            sourceKind: 1,
            isReferencedVideo: false,
            referencedEventId: 'parent_comment_id',
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.reply));
        expect(item.targetEventId, equals('parent_comment_id'));
      });

      test('comment maps to comment', () async {
        stubNotifications([
          makeNotification(notificationType: 'comment', sourceKind: 1),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.comment));
      });

      test('repost maps to repost', () async {
        stubNotifications([
          makeNotification(notificationType: 'repost', sourceKind: 6),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.repost));
      });

      test('mention maps to mention ($ActorNotification)', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'mention',
            sourceKind: 1,
            referencedEventId: null,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.mention));
      });

      test(
        'mention carries sourceEventId as targetEventId for resolver',
        () async {
          // A mention's referencedEventId is null (no video anchor); the
          // client resolver uses sourceEventId — the kind-1 event that
          // mentioned the user — to walk E-tags and find the root video.
          stubNotifications([
            makeNotification(
              notificationType: 'mention',
              sourceKind: 1,
              sourceEventId: 'mention_evt_id',
              referencedEventId: null,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as ActorNotification;
          expect(item.type, equals(NotificationKind.mention));
          expect(item.targetEventId, equals('mention_evt_id'));
        },
      );

      test('follow maps to follow ($ActorNotification)', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.follow));
      });

      test('contact maps to follow', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'contact',
            sourceKind: 3,
            referencedEventId: null,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.follow));
      });

      test('zap maps to like', () async {
        stubNotifications([
          makeNotification(notificationType: 'zap', sourceKind: 9735),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.like));
      });

      test('completely unknown type and kind maps to system', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'unknown',
            sourceKind: 9999,
            referencedEventId: null,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.system));
      });
    });

    group('comment text truncation', () {
      test('truncates comment text > 50 chars on $VideoNotification', () async {
        // Comment-on-video is now a VideoNotification, but the repository
        // does not currently surface commentText on that type. So we test
        // truncation through the actor-anchored path (mention with content)
        // since mention/reply/system go through _truncateComment too.
        final longComment = 'A' * 60;
        stubNotifications([
          makeNotification(
            notificationType: 'mention',
            sourceKind: 1,
            referencedEventId: null,
            content: longComment,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        // Mention is not in the comment/reply truncation path → null.
        expect(item.commentText, isNull);
      });

      test(
        'comment kind on video is a $VideoNotification with commentText',
        () async {
          // The repository carries the comment body through to the row
          // so it can quote the most recent comment under the message.
          stubNotifications([
            makeNotification(
              notificationType: 'comment',
              sourceKind: 1,
              content: 'Short comment',
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.comment));
          expect(item.commentText, equals('Short comment'));
        },
      );

      test(
        'truncates a long comment on $VideoNotification (50 chars + ellipsis)',
        () async {
          final longComment = 'A' * 60;
          stubNotifications([
            makeNotification(
              notificationType: 'comment',
              sourceKind: 1,
              content: longComment,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          // Reuses _truncateComment: caps at 50 chars and appends "..."
          // so the row never tries to render an unbounded comment body.
          expect(item.commentText, equals('${'A' * 50}...'));
        },
      );

      test(
        'like / repost on video leaves commentText null (no body text)',
        () async {
          // Default makeNotification is a reaction (kind 7) on a video,
          // which the repository maps to NotificationKind.like.
          stubNotifications([makeNotification()]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.like));
          expect(item.commentText, isNull);
        },
      );
    });

    group('refresh', () {
      test('resets cursor and fetches from beginning', () async {
        stubNotifications([], nextCursor: 'cursor_1');
        stubProfiles({});
        await repository.getNotifications();

        stubNotifications([]);
        await repository.refresh();

        verify(
          () => funnelcakeApiClient.getNotifications(
            pubkey: userPubkey,
            cursor: any(named: 'cursor'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).called(2);
      });
    });

    group('markAsRead', () {
      test('calls API and DAO for each id', () async {
        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            notificationIds: any(named: 'notificationIds'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer(
          (_) async => const MarkReadResponse(success: true, markedCount: 2),
        );
        when(
          () => notificationsDao.markAsRead(any()),
        ).thenAnswer((_) async => true);

        await repository.markAsRead(['n1', 'n2']);

        verify(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: userPubkey,
            notificationIds: ['n1', 'n2'],
            authHeaders: any(named: 'authHeaders'),
          ),
        ).called(1);
        verify(() => notificationsDao.markAsRead('n1')).called(1);
        verify(() => notificationsDao.markAsRead('n2')).called(1);
      });

      test('does nothing for empty id list', () async {
        await repository.markAsRead([]);

        verifyNever(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            notificationIds: any(named: 'notificationIds'),
            authHeaders: any(named: 'authHeaders'),
          ),
        );
      });

      test(
        'rolls back the optimistic snapshot when authHeadersProvider throws',
        () async {
          // authHeadersProvider returns headers for GET (initial refresh)
          // but throws on POST (the mark-read call). The rollback boundary
          // must cover this failure mode — pre-fix it didn't, so the
          // optimistic isRead=true flip stayed live with no server write.
          repository = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
            authHeadersProvider: (url, method) async {
              if (method == 'POST') {
                throw Exception('signer unavailable');
              }
              return {'Authorization': 'Nostr test-token'};
            },
          );

          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });
          stubNotifications([makeNotification()], unreadCount: 1);
          await repository.refresh();

          final loadedId =
              (await repository.watchSnapshot().first).items.first.id;
          expect(await repository.watchUnreadCount().first, equals(1));

          await expectLater(
            repository.markAsRead([loadedId]),
            throwsA(isA<Exception>()),
          );

          expect(
            await repository.watchUnreadCount().first,
            equals(1),
            reason:
                'Auth-header failure must roll back the optimistic flip — '
                'the snapshot should return to its pre-call state.',
          );
          verifyNever(
            () => funnelcakeApiClient.markNotificationsRead(
              pubkey: any(named: 'pubkey'),
              notificationIds: any(named: 'notificationIds'),
              authHeaders: any(named: 'authHeaders'),
            ),
          );
        },
      );

      test(
        'rolls back optimistic snapshot on 200 / success:false soft-failure',
        () async {
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });
          stubNotifications([makeNotification()], unreadCount: 1);
          await repository.refresh();
          final loadedId =
              (await repository.watchSnapshot().first).items.first.id;
          expect(await repository.watchUnreadCount().first, equals(1));

          when(
            () => funnelcakeApiClient.markNotificationsRead(
              pubkey: any(named: 'pubkey'),
              notificationIds: any(named: 'notificationIds'),
              authHeaders: any(named: 'authHeaders'),
            ),
          ).thenThrow(
            const FunnelcakeApiException(
              message:
                  'Mark notifications read rejected by server: token rejected',
              statusCode: 200,
            ),
          );

          await expectLater(
            repository.markAsRead([loadedId]),
            throwsA(isA<FunnelcakeApiException>()),
          );

          expect(
            await repository.watchUnreadCount().first,
            equals(1),
            reason:
                'A 200 / success:false from the API now throws and must '
                'roll back the optimistic flip so the snapshot matches '
                'server truth.',
          );
          verifyNever(() => notificationsDao.markAsRead(any()));
        },
      );
    });

    group('markAllAsRead', () {
      test('calls API and DAO when there are unread items', () async {
        // Seed the snapshot with an unread item so markAllAsRead's
        // early-return guard (skip when nothing is unread) does not fire.
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 1);
        await repository.refresh();

        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer(
          (_) async => const MarkReadResponse(success: true, markedCount: 5),
        );
        when(() => notificationsDao.markAllAsRead()).thenAnswer((_) async => 5);

        await repository.markAllAsRead();

        verify(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: userPubkey,
            authHeaders: any(named: 'authHeaders'),
          ),
        ).called(1);
        verify(() => notificationsDao.markAllAsRead()).called(1);
      });

      test(
        'rolls back the optimistic snapshot when authHeadersProvider throws',
        () async {
          repository = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
            authHeadersProvider: (url, method) async {
              if (method == 'POST') {
                throw Exception('signer unavailable');
              }
              return {'Authorization': 'Nostr test-token'};
            },
          );

          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });
          stubNotifications([makeNotification()], unreadCount: 1);
          await repository.refresh();

          expect(await repository.watchUnreadCount().first, equals(1));

          await expectLater(
            repository.markAllAsRead(),
            throwsA(isA<Exception>()),
          );

          expect(
            await repository.watchUnreadCount().first,
            equals(1),
            reason:
                'Auth-header failure must roll back the optimistic flip — '
                'the snapshot should return to its pre-call state.',
          );
          verifyNever(
            () => funnelcakeApiClient.markNotificationsRead(
              pubkey: any(named: 'pubkey'),
              authHeaders: any(named: 'authHeaders'),
            ),
          );
        },
      );
    });

    group('authHeadersProvider', () {
      test('passes auth headers to API calls when provided', () async {
        final authRepo = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
          authHeadersProvider: (url, method) async => {
            'Authorization': 'Nostr abc123',
          },
        );

        stubNotifications([]);
        stubProfiles({});

        await authRepo.getNotifications();

        verify(
          () => funnelcakeApiClient.getNotifications(
            pubkey: userPubkey,
            cursor: any(named: 'cursor'),
            requestUri: any(named: 'requestUri'),
            authHeaders: {'Authorization': 'Nostr abc123'},
            limit: any(named: 'limit'),
          ),
        ).called(1);
      });
    });

    group('sorting', () {
      test('results are sorted by timestamp descending', () async {
        stubNotifications([
          makeNotification(
            id: 'old',
            sourcePubkey: 'pub_a',
            notificationType: 'comment',
            sourceKind: 1,
            referencedEventId: 'video_old',
            createdAt: DateTime(2025),
            content: 'Old',
          ),
          makeNotification(
            id: 'new',
            sourcePubkey: 'pub_b',
            notificationType: 'comment',
            sourceKind: 1,
            referencedEventId: 'video_new',
            createdAt: DateTime(2025, 6),
            content: 'New',
          ),
        ]);
        stubProfiles({
          'pub_a': makeProfile('pub_a', displayName: 'Alice'),
          'pub_b': makeProfile('pub_b', displayName: 'Bob'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(2));
        expect((page.items[0] as VideoNotification).id, equals('new'));
        expect((page.items[1] as VideoNotification).id, equals('old'));
      });
    });

    group('enrichOne', () {
      RelayNotification raw({
        String id = 'r1',
        String sourcePubkey = 'pub_a',
        int sourceKind = 7,
        String notificationType = 'reaction',
        String? referencedEventId = 'video_x',
        String? referencedDTag,
        bool isReferencedVideo = true,
      }) {
        return RelayNotification(
          id: id,
          sourcePubkey: sourcePubkey,
          sourceEventId: 'src_$id',
          sourceKind: sourceKind,
          notificationType: notificationType,
          createdAt: DateTime(2025),
          read: false,
          referencedEventId: referencedEventId,
          referencedDTag: referencedDTag,
          isReferencedVideo: isReferencedVideo,
        );
      }

      test(
        'returns $VideoNotification for like with non-null referencedEventId',
        () async {
          stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});
          stubVideoStats(
            'video_x',
            makeVideoStats(id: 'video_x', thumbnail: 'thumb', title: 'T'),
          );

          final result = await repository.enrichOne(raw());

          expect(result, isA<VideoNotification>());
          final video = result! as VideoNotification;
          expect(video.actors.first.displayName, equals('Alice'));
          expect(video.totalCount, equals(1));
          expect(video.videoThumbnailUrl, equals('thumb'));
          expect(video.videoTitle, equals('T'));
        },
      );

      test('builds addressable id from user pubkey and d-tag for realtime '
          'video notifications', () async {
        stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});
        stubVideoStats(
          'video_x',
          makeVideoStats(id: 'video_x', thumbnail: 'thumb', title: 'T'),
        );

        final result = await repository.enrichOne(
          raw(referencedDTag: 'vine-id'),
        );

        expect(result, isA<VideoNotification>());
        final video = result! as VideoNotification;
        expect(
          video.videoAddressableId,
          equals(
            '${NIP71VideoKinds.addressableShortVideo}:'
            '$userPubkey:vine-id',
          ),
        );
      });

      test('leaves addressable id null when realtime d-tag is empty', () async {
        stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

        final result = await repository.enrichOne(raw(referencedDTag: ''));

        expect(result, isA<VideoNotification>());
        final video = result! as VideoNotification;
        expect(video.videoAddressableId, isNull);
      });

      test('returns null for like with null referencedEventId', () async {
        stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

        final result = await repository.enrichOne(raw(referencedEventId: null));

        expect(result, isNull);
      });

      test('returns $ActorNotification for follow', () async {
        stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

        final result = await repository.enrichOne(
          raw(
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
          ),
        );

        expect(result, isA<ActorNotification>());
        final actor = result! as ActorNotification;
        expect(actor.type, equals(NotificationKind.follow));
        expect(actor.actor.displayName, equals('Alice'));
      });

      test('returns likeComment with targetEventId when reaction targets a '
          'non-video event', () async {
        stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

        final result = await repository.enrichOne(
          raw(referencedEventId: 'comment_evt_id', isReferencedVideo: false),
        );

        expect(result, isA<ActorNotification>());
        final actor = result! as ActorNotification;
        expect(actor.type, equals(NotificationKind.likeComment));
        expect(actor.targetEventId, equals('comment_evt_id'));
      });

      test(
        'enrichOne: likeComment carries videoAddressableId when '
        'referencedDTag is set',
        () async {
          stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

          final result = await repository.enrichOne(
            raw(
              referencedEventId: 'comment_evt_id',
              isReferencedVideo: false,
              referencedDTag: 'vine-xyz',
            ),
          );

          expect(result, isA<ActorNotification>());
          final actor = result! as ActorNotification;
          expect(actor.type, equals(NotificationKind.likeComment));
          expect(
            actor.videoAddressableId,
            equals('34236:$userPubkey:vine-xyz'),
          );
        },
      );

      test(
        'enrichOne: likeComment videoAddressableId is null when '
        'referencedDTag is absent',
        () async {
          stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

          final result = await repository.enrichOne(
            raw(referencedEventId: 'comment_evt_id', isReferencedVideo: false),
          );

          expect(result, isA<ActorNotification>());
          final actor = result! as ActorNotification;
          expect(actor.videoAddressableId, isNull);
        },
      );
    });

    group('reactive snapshot', () {
      setUp(() {
        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            notificationIds: any(named: 'notificationIds'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer(
          (_) async => const MarkReadResponse(success: true, markedCount: 1),
        );
        when(
          () => notificationsDao.markAsRead(any()),
        ).thenAnswer((_) async => true);
        when(() => notificationsDao.markAllAsRead()).thenAnswer((_) async => 0);
      });

      test('seeds watchSnapshot with NotificationPage.empty', () async {
        await expectLater(
          repository.watchSnapshot().take(1),
          emitsInOrder([NotificationPage.empty]),
        );
      });

      test('watchUnreadCount starts at 0', () async {
        await expectLater(
          repository.watchUnreadCount().take(1),
          emitsInOrder([0]),
        );
      });

      test('emits snapshot after refresh', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 1);

        await repository.refresh();

        final snapshot = await repository.watchSnapshot().first;
        expect(snapshot.items, hasLength(1));
        expect(snapshot.items.first.isRead, isFalse);
      });

      test('watchUnreadCount derives from consolidated visible list', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 5);

        await repository.refresh();

        // Server reported 5, but the consolidated visible list has 1
        // unread item — watchUnreadCount returns the post-consolidation
        // count, not the server count.
        expect(await repository.watchUnreadCount().first, equals(1));
      });

      test('markAsRead optimistically flips matching items', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 1);
        await repository.refresh();
        final loadedId = repository.watchSnapshot().first.then(
          (s) => s.items.first.id,
        );
        final id = await loadedId;

        final counts = <int>[];
        final sub = repository.watchUnreadCount().listen(counts.add);

        await repository.markAsRead([id]);
        await sub.cancel();

        expect(counts.last, equals(0));
      });

      test('markAsRead rolls back snapshot when API throws', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 1);
        await repository.refresh();
        final loadedId =
            (await repository.watchSnapshot().first).items.first.id;

        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            notificationIds: any(named: 'notificationIds'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenThrow(const FunnelcakeException('boom'));

        await expectLater(
          repository.markAsRead([loadedId]),
          throwsA(isA<FunnelcakeException>()),
        );

        // Rollback restores the pre-write snapshot.
        expect(await repository.watchUnreadCount().first, equals(1));
      });

      test('markAllAsRead is a no-op when nothing is unread', () async {
        await repository.markAllAsRead();

        verifyNever(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            authHeaders: any(named: 'authHeaders'),
          ),
        );
      });

      test('markAllAsRead optimistically zeros every unread item', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
        });
        stubNotifications([
          makeNotification(),
          makeNotification(
            id: 'n2',
            sourcePubkey: 'pubkey_bob',
            referencedEventId: 'video_other',
          ),
        ], unreadCount: 2);
        await repository.refresh();
        expect(await repository.watchUnreadCount().first, equals(2));

        await repository.markAllAsRead();

        expect(await repository.watchUnreadCount().first, equals(0));
      });

      test('markAllAsRead rolls back when API throws', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 1);
        await repository.refresh();

        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenThrow(const FunnelcakeException('boom'));

        await expectLater(
          repository.markAllAsRead(),
          throwsA(isA<FunnelcakeException>()),
        );

        // Rollback restores the pre-write snapshot.
        expect(await repository.watchUnreadCount().first, equals(1));
      });

      test(
        'acceptRealtime enriches, prepends, and increments unread',
        () async {
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });

          await repository.acceptRealtime(makeNotification());

          expect(await repository.watchUnreadCount().first, equals(1));
        },
      );

      test('acceptRealtime dedupes against existing snapshot items', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 1);
        await repository.refresh();
        final beforeItems =
            (await repository.watchSnapshot().first).items.length;

        // Same id — should be a no-op.
        await repository.acceptRealtime(makeNotification());

        // Snapshot's item count is unchanged because the realtime event
        // was deduped against the existing item id.
        final afterItems =
            (await repository.watchSnapshot().first).items.length;
        expect(afterItems, equals(beforeItems));
      });

      test(
        'acceptRealtime by-id guard fires when existing row has empty '
        'sourceEventIds',
        () async {
          // Pins the by-id dedupe gate that survives below the
          // `_snapshotContainsSourceEventId` checks. The gate fires when
          // the incoming raw's `id` is not represented in any existing
          // row's `sourceEventIds` (so the cross-path checks can't see
          // it), but its `id` literally matches an item already in the
          // snapshot. If a future refactor deletes the by-id gate,
          // empty-sourceEventIds duplicates would inflate the snapshot
          // and this test will fail.
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });
          stubNotifications([]);
          await repository.refresh();

          // First WS arrival with empty sourceEventId — the resulting
          // row has `sourceEventIds = []`, so the cross-path checks
          // can't see it on the second arrival.
          await repository.acceptRealtime(
            makeNotification(
              id: 'evt1',
              sourceEventId: '',
              notificationType: 'follow',
              sourceKind: 3,
              referencedEventId: null,
              isReferencedVideo: false,
            ),
          );

          final firstItems = (await repository.watchSnapshot().first).items;
          expect(firstItems, hasLength(1));
          expect(firstItems.single.id, equals('evt1'));
          expect(firstItems.single.sourceEventIds, isEmpty);

          // Same raw again — only the by-id gate can dedupe this.
          await repository.acceptRealtime(
            makeNotification(
              id: 'evt1',
              sourceEventId: '',
              notificationType: 'follow',
              sourceKind: 3,
              referencedEventId: null,
              isReferencedVideo: false,
            ),
          );

          final afterItems = (await repository.watchSnapshot().first).items;
          expect(
            afterItems,
            hasLength(1),
            reason:
                'Duplicate WS arrival with empty sourceEventId must '
                'be deduped by the by-id gate; the sourceEventIds-based '
                'cross-path check cannot see an existing row with empty '
                'sourceEventIds.',
          );
        },
      );

      test(
        'acceptRealtime dedupes WS arrivals against snapshot sourceEventIds',
        () async {
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });
          stubNotifications([
            makeNotification(
              id: 'server-uuid-1',
              sourceEventId: 'nostr-event-1',
              notificationType: 'follow',
              sourceKind: 3,
              referencedEventId: null,
              isReferencedVideo: false,
            ),
          ], unreadCount: 1);
          await repository.refresh();

          await repository.acceptRealtime(
            makeNotification(
              id: 'nostr-event-1',
              sourceEventId: 'nostr-event-1',
              notificationType: 'follow',
              sourceKind: 3,
              referencedEventId: null,
              isReferencedVideo: false,
            ),
          );

          final items = (await repository.watchSnapshot().first).items;
          expect(items, hasLength(1));
          expect(items.single.id, equals('server-uuid-1'));
        },
      );

      test('acceptRealtime respects the refresh replacement boundary for '
          'sourceEventId dedupe', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([
          makeNotification(
            id: 'server-uuid-1',
            sourceEventId: 'nostr-event-1',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
            isReferencedVideo: false,
          ),
        ], unreadCount: 1);
        await repository.refresh();

        stubNotifications([]);
        await repository.refresh();

        await repository.acceptRealtime(
          makeNotification(
            id: 'nostr-event-1',
            sourceEventId: 'nostr-event-1',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
            isReferencedVideo: false,
          ),
        );

        final items = (await repository.watchSnapshot().first).items;
        expect(
          items,
          hasLength(1),
          reason:
              'First-page refresh replaces the snapshot, so a later WS '
              'arrival for an event no longer present should be accepted.',
        );
        expect(items.single.sourceEventIds, equals(<String>['nostr-event-1']));
      });

      test(
        'acceptRealtime rechecks the snapshot after enrichment before '
        'writing',
        () async {
          final profilesCompleter = Completer<Map<String, UserProfile>>();
          when(
            () => profileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) => profilesCompleter.future);

          final realtimeFuture = repository.acceptRealtime(
            makeNotification(
              id: 'nostr-event-1',
              sourceEventId: 'nostr-event-1',
              notificationType: 'follow',
              sourceKind: 3,
              referencedEventId: null,
              isReferencedVideo: false,
            ),
          );

          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });
          stubNotifications([
            makeNotification(
              id: 'server-uuid-1',
              sourceEventId: 'nostr-event-1',
              notificationType: 'follow',
              sourceKind: 3,
              referencedEventId: null,
              isReferencedVideo: false,
            ),
          ], unreadCount: 1);
          await repository.refresh();

          profilesCompleter.complete({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });
          await realtimeFuture;

          final items = (await repository.watchSnapshot().first).items;
          expect(
            items,
            hasLength(1),
            reason:
                'The post-await snapshot check must see the refreshed REST '
                'row and avoid prepending a stale duplicate.',
          );
          expect(items.single.id, equals('server-uuid-1'));
        },
      );

      test('acceptRealtime merges a second actor into an existing '
          '$VideoNotification group (same videoEventId + type)', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
        });
        // Initial fetch: one like from Alice on video_default. Becomes a
        // VideoNotification with totalCount: 1, actors: [Alice].
        stubNotifications([
          makeNotification(id: 'first', createdAt: DateTime(2025, 3)),
        ], unreadCount: 1);
        await repository.refresh();

        // Mark as read so we can verify the merge flips isRead back.
        await repository.markAllAsRead();

        final laterTimestamp = DateTime(2025, 6);
        // Realtime arrival: a like from Bob on the same video.
        await repository.acceptRealtime(
          makeNotification(
            id: 'second',
            sourcePubkey: 'pubkey_bob',
            createdAt: laterTimestamp,
          ),
        );

        final page = await repository.watchSnapshot().first;
        expect(
          page.items,
          hasLength(1),
          reason:
              'Same (videoEventId, type) should merge into the existing '
              'row instead of prepending a duplicate.',
        );

        final merged = page.items.single as VideoNotification;
        expect(merged.totalCount, equals(2));
        expect(merged.actors, hasLength(2));
        expect(
          merged.actors.first.pubkey,
          equals('pubkey_bob'),
          reason: 'New actor is prepended at the front of the stack.',
        );
        expect(merged.actors[1].pubkey, equals('pubkey_alice'));
        expect(merged.isRead, isFalse);
        expect(merged.timestamp, equals(laterTimestamp));

        // watchUnreadCount reflects the un-read flip.
        expect(await repository.watchUnreadCount().first, equals(1));
      });

      test(
        'acceptRealtime caps merged actors at the group display limit',
        () async {
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
            'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
            'pubkey_carol': makeProfile('pubkey_carol', displayName: 'Carol'),
            'pubkey_dave': makeProfile('pubkey_dave', displayName: 'Dave'),
          });
          // Initial fetch: three likes on the same video — fills the actor
          // stack to the display cap.
          stubNotifications([
            makeNotification(id: 'n_alice', createdAt: DateTime(2024, 1, 3)),
            makeNotification(
              id: 'n_bob',
              sourcePubkey: 'pubkey_bob',
              createdAt: DateTime(2024, 1, 2),
            ),
            makeNotification(
              id: 'n_carol',
              sourcePubkey: 'pubkey_carol',
              createdAt: DateTime(2024),
            ),
          ], unreadCount: 3);
          await repository.refresh();

          await repository.acceptRealtime(
            makeNotification(
              id: 'n_dave',
              sourcePubkey: 'pubkey_dave',
              createdAt: DateTime(2024, 1, 4),
            ),
          );

          final merged =
              (await repository.watchSnapshot().first).items.single
                  as VideoNotification;
          expect(merged.totalCount, equals(4));
          expect(
            merged.actors,
            hasLength(3),
            reason:
                'Displayed actor stack stays bounded even though totalCount '
                'continues to grow.',
          );
          expect(merged.actors.first.pubkey, equals('pubkey_dave'));
        },
      );

      test('acceptRealtime dedupes a WS arrival whose id matches a REST '
          "item's sourceEventId", () async {
        // REST raws carry the Nostr event id in `sourceEventId` (server's
        // UUID lives in `id`). WS raws — built by the realtime bridge —
        // carry the Nostr event id in `id`. Without the cross-path check
        // the same logical Nostr event accepted via WS after REST would
        // inflate the snapshot and the unread count.
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([
          makeNotification(
            id: 'server-uuid-1',
            sourceEventId: 'nostr-evt-1',
            referencedEventId: 'video_a',
          ),
        ], unreadCount: 1);
        await repository.refresh();

        final beforeItems =
            (await repository.watchSnapshot().first).items.length;
        expect(await repository.watchUnreadCount().first, equals(1));

        // Same Nostr event arriving over WS — bridge sets both `id` and
        // `sourceEventId` to the Nostr event id.
        await repository.acceptRealtime(
          makeNotification(
            id: 'nostr-evt-1',
            sourceEventId: 'nostr-evt-1',
            referencedEventId: 'video_a',
            createdAt: DateTime(2025, 6),
          ),
        );

        final afterItems =
            (await repository.watchSnapshot().first).items.length;
        expect(afterItems, equals(beforeItems));
        expect(
          await repository.watchUnreadCount().first,
          equals(1),
          reason:
              'Cross-path duplicate must not bump the unread count or the '
              'visible item count.',
        );
      });

      test('acceptRealtime prepends a $VideoNotification when no existing '
          'group matches by videoEventId + type', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
        });
        stubNotifications([
          makeNotification(id: 'first', referencedEventId: 'video_a'),
        ], unreadCount: 1);
        await repository.refresh();

        // Different videoEventId — must not merge.
        await repository.acceptRealtime(
          makeNotification(
            id: 'second',
            sourcePubkey: 'pubkey_bob',
            referencedEventId: 'video_b',
            createdAt: DateTime(2025, 6),
          ),
        );

        final items = (await repository.watchSnapshot().first).items;
        expect(items, hasLength(2));
        expect(
          (items.first as VideoNotification).videoEventId,
          equals('video_b'),
          reason: 'New, non-matching item is prepended.',
        );
      });
    });

    group('WS-first dedupe in page-merge (#4264)', () {
      // WS raws (built by `notification_realtime_bridge.dart`) carry the
      // Nostr event id in both `id` and `sourceEventId`. REST raws carry
      // the Nostr event id in `sourceEventId` (with the server's UUID in
      // `id`). When WS arrives first and a later REST pagination page
      // returns the same logical event, dedupe must key on the shared
      // Nostr event id via `NotificationItem.sourceEventIds`, not the
      // rendered `id` which differs across the two paths.

      test('standalone $ActorNotification: WS-first then non-first REST page '
          'with same sourceEventId resolves to a single row', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        // First page seeds the snapshot and advances _lastCursor so the
        // next getNotifications() emits as a non-first page.
        stubNotifications([], nextCursor: 'cursor_after_first', hasMore: true);
        await repository.refresh();

        // WS arrives: bridge sets id == sourceEventId == nostr event id.
        await repository.acceptRealtime(
          makeNotification(
            id: 'nostr-follow-evt-1',
            sourceEventId: 'nostr-follow-evt-1',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
            isReferencedVideo: false,
            createdAt: DateTime(2025, 6),
          ),
        );

        expect(
          (await repository.watchSnapshot().first).items,
          hasLength(1),
          reason: 'WS arrival adds the follow row.',
        );

        // Non-first REST page returns the same logical follow event
        // with the server UUID in id and the Nostr event id in
        // sourceEventId.
        stubNotifications([
          makeNotification(
            id: 'server-uuid-follow-1',
            sourceEventId: 'nostr-follow-evt-1',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
            isReferencedVideo: false,
            createdAt: DateTime(2025, 6),
          ),
        ]);

        await repository.getNotifications();

        final items = (await repository.watchSnapshot().first).items;
        expect(
          items,
          hasLength(1),
          reason:
              'REST item with sourceEventId already represented by the '
              'WS row must not be appended as a duplicate.',
        );
        final actor = items.single as ActorNotification;
        expect(actor.sourceEventIds, contains('nostr-follow-evt-1'));
      });

      test('grouped $VideoNotification: WS-first single-actor row, then '
          'non-first REST page with multi-actor group on same '
          '(videoEventId, type) merges richer REST data into the existing '
          'WS row in place', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
          'pubkey_carol': makeProfile('pubkey_carol', displayName: 'Carol'),
        });
        stubNotifications([], nextCursor: 'cursor_after_first', hasMore: true);
        await repository.refresh();

        await repository.acceptRealtime(
          makeNotification(
            id: 'nostr-like-alice',
            sourceEventId: 'nostr-like-alice',
            referencedEventId: 'video_a',
            createdAt: DateTime(2025, 5),
          ),
        );

        stubNotifications([
          makeNotification(
            id: 'server-uuid-like-alice',
            sourceEventId: 'nostr-like-alice',
            referencedEventId: 'video_a',
            createdAt: DateTime(2025, 5),
          ),
          makeNotification(
            id: 'server-uuid-like-bob',
            sourceEventId: 'nostr-like-bob',
            sourcePubkey: 'pubkey_bob',
            referencedEventId: 'video_a',
            createdAt: DateTime(2025, 5, 2),
          ),
          makeNotification(
            id: 'server-uuid-like-carol',
            sourceEventId: 'nostr-like-carol',
            sourcePubkey: 'pubkey_carol',
            referencedEventId: 'video_a',
            createdAt: DateTime(2025, 5, 3),
          ),
        ]);

        await repository.getNotifications();

        final items = (await repository.watchSnapshot().first).items;
        expect(
          items,
          hasLength(1),
          reason:
              'REST group on same (videoEventId, type) must merge into '
              'the existing WS row instead of producing a second row.',
        );
        final merged = items.single as VideoNotification;
        expect(merged.videoEventId, equals('video_a'));
        expect(merged.type, equals(NotificationKind.like));
        expect(
          merged.sourceEventIds,
          containsAll(<String>[
            'nostr-like-alice',
            'nostr-like-bob',
            'nostr-like-carol',
          ]),
        );
        expect(merged.totalCount, equals(3));
        expect(
          merged.actors,
          hasLength(3),
          reason: 'Actor stack fills up to _maxGroupActors after merge.',
        );
        expect(
          merged.actors.first.pubkey,
          equals('pubkey_alice'),
          reason:
              'Existing-side actors retain their leading position so '
              'the row does not visibly jump.',
        );
      });

      test('unrelated REST event on a different video is appended; no '
          'false-positive dedupe', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
        });
        stubNotifications([], nextCursor: 'cursor_after_first', hasMore: true);
        await repository.refresh();

        await repository.acceptRealtime(
          makeNotification(
            id: 'nostr-like-alice-video-a',
            sourceEventId: 'nostr-like-alice-video-a',
            referencedEventId: 'video_a',
            createdAt: DateTime(2025, 5),
          ),
        );

        stubNotifications([
          makeNotification(
            id: 'server-uuid-like-bob-video-b',
            sourceEventId: 'nostr-like-bob-video-b',
            sourcePubkey: 'pubkey_bob',
            referencedEventId: 'video_b',
            createdAt: DateTime(2025, 5, 2),
          ),
        ]);

        await repository.getNotifications();

        final items = (await repository.watchSnapshot().first).items;
        expect(
          items,
          hasLength(2),
          reason:
              'Disjoint sourceEventIds and disjoint (videoEventId, type) '
              'must not trigger dedupe — both rows visible.',
        );
      });

      test(
        'mixed page: same logical event deduped, new events appended',
        () async {
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
            'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
            'pubkey_carol': makeProfile('pubkey_carol', displayName: 'Carol'),
          });
          stubNotifications(
            [],
            nextCursor: 'cursor_after_first',
            hasMore: true,
          );
          await repository.refresh();

          // WS arrives for a follow notification.
          await repository.acceptRealtime(
            makeNotification(
              id: 'nostr-follow-alice',
              sourceEventId: 'nostr-follow-alice',
              notificationType: 'follow',
              sourceKind: 3,
              referencedEventId: null,
              isReferencedVideo: false,
              createdAt: DateTime(2025, 5),
            ),
          );

          // Non-first REST page includes:
          //  - the same follow event (must be deduped),
          //  - a new follow from Bob (must be appended),
          //  - a new like from Carol on a video (must be appended).
          stubNotifications([
            makeNotification(
              id: 'server-uuid-follow-alice',
              sourceEventId: 'nostr-follow-alice',
              notificationType: 'follow',
              sourceKind: 3,
              referencedEventId: null,
              isReferencedVideo: false,
              createdAt: DateTime(2025, 5),
            ),
            makeNotification(
              id: 'server-uuid-follow-bob',
              sourceEventId: 'nostr-follow-bob',
              sourcePubkey: 'pubkey_bob',
              notificationType: 'follow',
              sourceKind: 3,
              referencedEventId: null,
              isReferencedVideo: false,
              createdAt: DateTime(2025, 4),
            ),
            makeNotification(
              id: 'server-uuid-like-carol',
              sourceEventId: 'nostr-like-carol',
              sourcePubkey: 'pubkey_carol',
              referencedEventId: 'video_x',
              createdAt: DateTime(2025, 4, 5),
            ),
          ]);

          await repository.getNotifications();

          final items = (await repository.watchSnapshot().first).items;
          expect(
            items,
            hasLength(3),
            reason:
                'Duplicate Nostr event is dropped; the two new events '
                'are appended.',
          );
          final allSourceIds = items.expand((n) => n.sourceEventIds).toSet();
          expect(
            allSourceIds,
            containsAll(<String>[
              'nostr-follow-alice',
              'nostr-follow-bob',
              'nostr-like-carol',
            ]),
          );
        },
      );

      test("comment-kind merge keeps the newer side's commentText "
          '(WS newer than REST page)', () async {
        // Production ordering: REST pagination walks backward in time,
        // so an incoming REST page on the same (videoEventId, kind)
        // is typically OLDER than the WS-built row in the snapshot.
        // The merged row must therefore keep the WS commentText —
        // mirrors `_groupVideoAnchored`'s sort-desc + group.first
        // newest-wins and the surrounding `timestamp = max(...)`.
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
        });
        stubNotifications([], nextCursor: 'cursor_after_first', hasMore: true);
        await repository.refresh();

        // WS arrives with the NEWER comment.
        await repository.acceptRealtime(
          makeNotification(
            id: 'nostr-comment-alice',
            sourceEventId: 'nostr-comment-alice',
            notificationType: 'comment',
            sourceKind: 1,
            referencedEventId: 'video_a',
            content: 'Newer comment from Alice (WS-arrived)',
            createdAt: DateTime(2025, 6),
          ),
        );

        // REST pagination returns an OLDER comment on the same video.
        stubNotifications([
          makeNotification(
            id: 'server-uuid-comment-bob',
            sourceEventId: 'nostr-comment-bob',
            sourcePubkey: 'pubkey_bob',
            notificationType: 'comment',
            sourceKind: 1,
            referencedEventId: 'video_a',
            content: 'Older comment from Bob (REST-paged)',
            createdAt: DateTime(2025, 4),
          ),
        ]);

        await repository.getNotifications();

        final items = (await repository.watchSnapshot().first).items;
        expect(items, hasLength(1));
        final merged = items.single as VideoNotification;
        expect(merged.type, equals(NotificationKind.comment));
        expect(
          merged.commentText,
          equals('Newer comment from Alice (WS-arrived)'),
          reason:
              'Newer side wins to mirror _groupVideoAnchored sort-desc '
              'semantics and align with timestamp=max(...). Older REST '
              'commentText must NOT overwrite the displayed newest one.',
        );
        expect(
          merged.timestamp,
          equals(DateTime(2025, 6)),
          reason: 'timestamp must be the max of the two sides.',
        );
      });

      test("comment-kind merge keeps the newer side's commentText "
          '(REST page newer than WS) — symmetric direction', () async {
        // Symmetric case: rare in production (REST first page is the
        // newer boundary), but the rule must be timestamp-driven, not
        // path-driven. Lock both directions.
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
        });
        stubNotifications([], nextCursor: 'cursor_after_first', hasMore: true);
        await repository.refresh();

        await repository.acceptRealtime(
          makeNotification(
            id: 'nostr-comment-alice',
            sourceEventId: 'nostr-comment-alice',
            notificationType: 'comment',
            sourceKind: 1,
            referencedEventId: 'video_a',
            content: 'Older comment from Alice (WS-arrived)',
            createdAt: DateTime(2025, 4),
          ),
        );

        stubNotifications([
          makeNotification(
            id: 'server-uuid-comment-bob',
            sourceEventId: 'nostr-comment-bob',
            sourcePubkey: 'pubkey_bob',
            notificationType: 'comment',
            sourceKind: 1,
            referencedEventId: 'video_a',
            content: 'Newer comment from Bob (REST-paged)',
            createdAt: DateTime(2025, 6),
          ),
        ]);

        await repository.getNotifications();

        final items = (await repository.watchSnapshot().first).items;
        expect(items, hasLength(1));
        final merged = items.single as VideoNotification;
        expect(
          merged.commentText,
          equals('Newer comment from Bob (REST-paged)'),
          reason:
              'When the REST side carries the newer createdAt, its '
              'commentText wins — rule is timestamp-driven, not '
              'path-driven.',
        );
        expect(merged.timestamp, equals(DateTime(2025, 6)));
      });
    });
  });
}
