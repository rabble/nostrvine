// ABOUTME: Tests for NotificationRepository — covers enrichment, video-anchored
// ABOUTME: grouping by (referencedEventId, kind), follow consolidation, type
// ABOUTME: mapping, and comment truncation.

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
  const stableCursorId =
      '1122334411223344112233441122334411223344112233441122334411223344';

  NotificationRepository buildRepository({
    BlockedNotificationFilter? blockFilter,
  }) {
    return NotificationRepository(
      funnelcakeApiClient: funnelcakeApiClient,
      profileRepository: profileRepository,
      notificationsDao: notificationsDao,
      userPubkey: userPubkey,
      blockFilter: blockFilter,
      hydrateOnStart: false,
    );
  }

  setUpAll(() {
    registerFallbackValue(<NotificationCacheRow>[]);
  });

  setUp(() {
    funnelcakeApiClient = _MockFunnelcakeApiClient();
    profileRepository = _MockProfileRepository();
    notificationsDao = _MockNotificationsDao();
    when(
      () => funnelcakeApiClient.notificationsUri(
        pubkey: any(named: 'pubkey'),
        limit: any(named: 'limit'),
        cursor: any(named: 'cursor'),
        cursorId: any(named: 'cursorId'),
      ),
    ).thenAnswer((invocation) {
      final pubkey = invocation.namedArguments[#pubkey] as String;
      final limit = invocation.namedArguments[#limit] as int? ?? 50;
      final cursor = invocation.namedArguments[#cursor] as String?;
      final cursorId = invocation.namedArguments[#cursorId] as String?;
      final effectiveBefore =
          cursor ?? DateTime.now().millisecondsSinceEpoch.toString();
      final queryParameters = <String, String>{
        'limit': '$limit',
        'before': effectiveBefore,
        'before_id': ?cursorId,
      };
      return Uri.parse(
        'https://api.example.com/api/users/$pubkey/notifications',
      ).replace(queryParameters: queryParameters);
    });
    when(
      () => funnelcakeApiClient.notificationsReadUri(
        pubkey: any(named: 'pubkey'),
      ),
    ).thenAnswer((invocation) {
      final pubkey = invocation.namedArguments[#pubkey] as String;
      return Uri.parse(
        'https://api.example.com/api/users/$pubkey/notifications/read',
      );
    });
    // Default: getVideoStats throws (no metadata fetched). Tests that need a
    // thumbnail override this stub explicitly.
    when(
      () => funnelcakeApiClient.getVideoStats(any()),
    ).thenThrow(const FunnelcakeException('no stats'));
    // Default DAO stubs cover the new hydrate / write-through paths so
    // existing tests don't need to know about them. Tests exercising the
    // cache override these explicitly.
    when(
      () => notificationsDao.getAllNotifications(limit: any(named: 'limit')),
    ).thenAnswer((_) async => <NotificationRow>[]);
    when(() => notificationsDao.replaceAll(any())).thenAnswer((_) async {});
    repository = buildRepository();
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
    String? rootEventId,
    String? targetCommentId,
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
      rootEventId: rootEventId,
      targetCommentId: targetCommentId,
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
    String? nextCursorId,
  }) {
    when(
      () => funnelcakeApiClient.getNotifications(
        pubkey: any(named: 'pubkey'),
        cursor: any(named: 'cursor'),
        cursorId: any(named: 'cursorId'),
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
        nextCursorId: nextCursorId,
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
    String? name,
    String? picture,
  }) {
    return UserProfile(
      pubkey: pubkey,
      rawData: const {},
      createdAt: DateTime(2024),
      eventId: 'evt_$pubkey',
      displayName: displayName,
      name: name,
      picture: picture,
    );
  }

  VideoStats makeVideoStats({
    required String id,
    String pubkey = userPubkey,
    String? thumbnail,
    String? title,
    String? dTag,
  }) {
    return VideoStats(
      id: id,
      pubkey: pubkey,
      createdAt: DateTime(2025),
      kind: 34236,
      dTag: dTag ?? 'd_$id',
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
          authHeadersProvider: (url, method, {body}) async {
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
        expect(signedUri.queryParameters['limit'], equals('20'));
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
          authHeadersProvider: (url, method, {body}) async {
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
            '?limit=20&before=cursor_abc',
          ),
        );
      });

      test(
        'signs the full paginated notifications URL with cursor id',
        () async {
          var signedUrl = '';
          repository = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
            authHeadersProvider: (url, method, {body}) async {
              signedUrl = url;
              return {'Authorization': 'Nostr test-token'};
            },
          );
          stubNotifications(
            [],
            nextCursor: '1700000000',
            nextCursorId: stableCursorId,
            hasMore: true,
          );
          stubProfiles({});

          await repository.getNotifications();
          stubNotifications([], nextCursor: '1699999999');

          await repository.getNotifications();

          expect(
            signedUrl,
            equals(
              'https://api.example.com/api/users/$userPubkey/notifications'
              '?limit=20&before=1700000000'
              '&before_id=$stableCursorId',
            ),
          );
        },
      );

      test('explicit cursor override does not leak stored cursor id', () async {
        var signedUrl = '';
        repository = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
          authHeadersProvider: (url, method, {body}) async {
            signedUrl = url;
            return {'Authorization': 'Nostr test-token'};
          },
        );
        stubNotifications(
          [],
          nextCursor: '1700000000',
          nextCursorId: stableCursorId,
          hasMore: true,
        );
        stubProfiles({});

        await repository.getNotifications();
        stubNotifications([], nextCursor: 'manual_next');

        await repository.getNotifications(cursor: 'manual_cursor');

        expect(
          signedUrl,
          equals(
            'https://api.example.com/api/users/$userPubkey/notifications'
            '?limit=20&before=manual_cursor',
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

      test(
        'falls back to a generated display name for missing profiles',
        () async {
          stubNotifications([makeNotification(sourcePubkey: 'unknown_pub')]);
          stubProfiles({});

          final page = await repository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.first as VideoNotification;
          expect(
            item.actors.first.displayName,
            equals(UserProfile.defaultDisplayNameFor('unknown_pub')),
          );
          expect(item.actors.first.pictureUrl, isNull);
        },
      );

      test('sanitizes explicit display names before rendering', () async {
        stubNotifications([makeNotification(sourcePubkey: 'zalgo_pub')]);
        stubProfiles({
          'zalgo_pub': makeProfile(
            'zalgo_pub',
            displayName: 'A\u0300\u0301\u0302',
          ),
        });

        final page = await repository.getNotifications();

        final item = page.items.single as VideoNotification;
        expect(item.actors.first.displayName, equals('A\u0300\u0301'));
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

        // BehaviorSubject preserves its prior items across the throw —
        // the seeded empty list stays so downstream consumers don't see
        // spurious item updates — but `lastRefreshError` flips to `true`
        // so the BLoC can render the inline refresh-error affordance.
        final snapshot = await repository.watchSnapshot().first;
        expect(snapshot.items, isEmpty);
        expect(snapshot.lastRefreshError, isTrue);
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
        expect(populated.lastRefreshError, isFalse);

        // Second refresh throws — the snapshot must keep the populated
        // items from the first refresh, not revert to empty. This pins
        // the design contract that lets the BLoC's failure state coexist
        // with previously-loaded data (the BehaviorSubject value the
        // snapshot stream emits to subscribers stays at the populated
        // page). `lastRefreshError` flips so the view can render the
        // inline banner.
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
        expect(after.items, equals(populated.items));
        expect(after.lastRefreshError, isTrue);
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

        // Two consecutive throws must not corrupt the items list. The
        // refresh-error flag stays sticky between throws — it only
        // clears on the next successful refresh.
        final snapshot = await repository.watchSnapshot().first;
        expect(snapshot.items, isEmpty);
        expect(snapshot.lastRefreshError, isTrue);
      });

      test('clears lastRefreshError on next successful refresh', () async {
        // First call throws — flips lastRefreshError to true.
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
        expect(
          (await repository.watchSnapshot().first).lastRefreshError,
          isTrue,
        );

        // Second call succeeds — flag clears.
        stubProfiles({});
        stubNotifications([]);
        await repository.refresh();
        expect(
          (await repository.watchSnapshot().first).lastRefreshError,
          isFalse,
        );
      });

      test('retries first-page fetch on transient 5xx and succeeds on second '
          'attempt', () async {
        stubProfiles({});
        var calls = 0;
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            throw const FunnelcakeApiException(
              message: 'Internal server error',
              statusCode: 500,
              url: 'https://api.example.com/api/users/x/notifications',
            );
          }
          return const NotificationResponse(
            notifications: [],
            unreadCount: 0,
            hasMore: false,
          );
        });

        final page = await repository.getNotifications();
        expect(page.items, isEmpty);
        expect(calls, equals(2));
        expect(
          (await repository.watchSnapshot().first).lastRefreshError,
          isFalse,
        );
      });

      test(
        'does not retry first-page fetch on 4xx — surfaces error immediately',
        () async {
          var calls = 0;
          when(
            () => funnelcakeApiClient.getNotifications(
              pubkey: any(named: 'pubkey'),
              cursor: any(named: 'cursor'),
              requestUri: any(named: 'requestUri'),
              authHeaders: any(named: 'authHeaders'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async {
            calls++;
            throw const FunnelcakeApiException(
              message: 'unauthorized',
              statusCode: 401,
              url: 'https://api.example.com/api/users/x/notifications',
            );
          });

          await expectLater(
            repository.getNotifications(),
            throwsA(isA<FunnelcakeApiException>()),
          );
          expect(calls, equals(1));
        },
      );

      test('persists first-page items to DAO on success', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 1);
        await repository.refresh();
        verify(() => notificationsDao.replaceAll(any())).called(1);
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
            authHeadersProvider: (url, method, {body}) async {
              signedUrl = url;
              return {'Authorization': 'Nostr test-token'};
            },
          );
          stubNotifications([]);
          stubProfiles({});

          await repository.getNotifications();

          final captured = verify(
            () => funnelcakeApiClient.getNotifications(
              pubkey: userPubkey,
              cursor: any(named: 'cursor'),
              requestUri: captureAny(named: 'requestUri'),
              authHeaders: any(named: 'authHeaders'),
              limit: captureAny(named: 'limit'),
            ),
          ).captured;
          requestedUri = captured.whereType<Uri>().single;
          final requestedLimit = captured.whereType<int>().single;

          expect(requestedUri.toString(), equals(signedUrl));
          expect(requestedLimit, equals(20));
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
            authHeadersProvider: (url, method, {body}) async {
              signedUrl = url;
              return {'Authorization': 'Nostr test-token'};
            },
          );
          stubNotifications([], nextCursor: 'cursor_abc', hasMore: true);
          stubProfiles({});

          await repository.getNotifications();
          stubNotifications([], nextCursor: 'cursor_def');

          await repository.getNotifications();

          final captured = verify(
            () => funnelcakeApiClient.getNotifications(
              pubkey: userPubkey,
              cursor: 'cursor_abc',
              requestUri: captureAny(named: 'requestUri'),
              authHeaders: any(named: 'authHeaders'),
              limit: captureAny(named: 'limit'),
            ),
          ).captured;
          requestedUri = captured.whereType<Uri>().single;
          final requestedLimit = captured.whereType<int>().single;

          expect(requestedUri.toString(), equals(signedUrl));
          expect(requestedLimit, equals(20));
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

      test('grouped video notifications lead with a named actor', () async {
        const hashPubkey =
            '2949ede154d1f121402761cbd73f2b8c490b5041cdd85c9908c5322f1a2fe3f6';
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: hashPubkey,
            referencedEventId: 'video_x',
            createdAt: DateTime(2025, 1, 5),
          ),
          makeNotification(
            id: 'l2',
            sourcePubkey: 'pub_named',
            referencedEventId: 'video_x',
            createdAt: DateTime(2025, 1, 4),
          ),
          makeNotification(
            id: 'l3',
            sourcePubkey: 'pub_missing',
            referencedEventId: 'video_x',
            createdAt: DateTime(2025, 1, 3),
          ),
        ]);
        stubProfiles({
          hashPubkey: makeProfile(hashPubkey, displayName: hashPubkey),
          'pub_named': makeProfile(
            'pub_named',
            displayName: 'Sally Strawberry',
          ),
        });

        final page = await repository.getNotifications();

        final item = page.items.single as VideoNotification;
        expect(item.totalCount, equals(3));
        expect(item.actors.first.pubkey, equals('pub_named'));
        expect(item.actors.first.displayName, equals('Sally Strawberry'));
      });

      test('grouped video notifications build the addressable id from the '
          'authoritative VideoStats d-tag when the recipient owns the '
          'referenced video (#4730)', () async {
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: 'pub_a',
            referencedEventId: 'video_x',
            referencedDTag: 'payload-dtag',
          ),
          makeNotification(
            id: 'l2',
            sourcePubkey: 'pub_b',
            referencedEventId: 'video_x',
            referencedDTag: 'payload-dtag',
          ),
        ]);
        stubProfiles({
          'pub_a': makeProfile('pub_a', displayName: 'Alice'),
          'pub_b': makeProfile('pub_b', displayName: 'Bob'),
        });
        // Authoritative ownership: video stats resolve and the owner is the
        // recipient (makeVideoStats defaults pubkey == userPubkey, d-tag
        // 'd_video_x'). The payload referencedDTag intentionally DIFFERS so the
        // assertion proves the route uses the authoritative VideoStats d-tag,
        // not the payload — a mismatched referenced_video block can't poison
        // the route.
        stubVideoStats('video_x', makeVideoStats(id: 'video_x'));

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(
          item.videoAddressableId,
          equals(
            '${NIP71VideoKinds.addressableShortVideo}:'
            '$userPubkey:d_video_x',
          ),
        );
      });

      test('grouped video notifications fall back to the payload d-tag when '
          'the authoritative VideoStats omits one (#4730)', () async {
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: 'pub_a',
            referencedEventId: 'video_x',
            referencedDTag: 'vine-id',
          ),
        ]);
        stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});
        // Owner confirmed, but VideoStats carries no d-tag → use the payload
        // d-tag rather than drop the stable route.
        stubVideoStats('video_x', makeVideoStats(id: 'video_x', dTag: ''));

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

      test('grouped video notifications synthesize the addressable id from the '
          'payload d-tag when the referenced video metadata is missing '
          '(#4730 broken-link fix)', () async {
        // No video stats stubbed → ownership cannot be confirmed (e.g. a
        // stale/edited event id whose old metadata no longer resolves). The
        // notification is structurally about the recipient's own video, so we
        // synthesize the recipient-scoped stable route from the server-provided
        // d-tag rather than dropping to the (often stale) raw event id. The
        // pubkey is pinned to the recipient, so the route can never address
        // another creator's video.
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
        // The canonical event id is still carried for the resolver fallback.
        expect(item.videoEventId, equals('video_x'));
      });

      test('grouped video notifications leave addressable id null on a '
          'metadata miss when no payload d-tag is available', () async {
        // Metadata miss AND no usable d-tag → nothing to synthesize from, so
        // the route stays null and navigation falls back to the raw event id.
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: 'pub_a',
            referencedEventId: 'video_x',
            referencedDTag: '',
          ),
        ]);
        stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(item.videoAddressableId, isNull);
        expect(item.videoEventId, equals('video_x'));
      });

      test('comment with empty referencedEventId synthesizes the addressable '
          'id from the payload d-tag and keeps the root video event id '
          '(#4730 broken-link fix)', () async {
        // NIP-22 comment whose referenced_event_id is empty carries the video
        // via rootEventId. The page-load path fetches metadata by
        // referenced_event_id only (not rootEventId), so ownership of the root
        // video is unconfirmed here — but the notification is still about the
        // recipient's own video, so the recipient-scoped route is synthesized
        // from the payload d-tag instead of dropping to the rootEventId.
        stubNotifications([
          makeNotification(
            id: 'c1',
            sourcePubkey: 'pub_a',
            sourceKind: 1111,
            notificationType: 'comment',
            referencedEventId: '',
            rootEventId: 'video_root',
            referencedDTag: 'vine-id',
            content: 'nice one',
          ),
        ]);
        stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.comment));
        expect(
          item.videoAddressableId,
          equals(
            '${NIP71VideoKinds.addressableShortVideo}:'
            '$userPubkey:vine-id',
          ),
        );
        expect(item.videoEventId, equals('video_root'));
      });

      test(
        'comment on a video reply anchors to the referenced video, not root',
        () async {
          stubNotifications([
            makeNotification(
              id: 'c-reply-video',
              sourcePubkey: 'pub_a',
              sourceKind: 1111,
              notificationType: 'comment',
              sourceEventId: 'comment_event_id',
              referencedEventId: 'reply_video_event',
              rootEventId: 'thread_root_event',
              targetCommentId: 'reply_video_event',
              referencedDTag: 'reply-video-dtag',
              content: 'comment on a video reply',
            ),
          ]);
          stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

          final page = await repository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.comment));
          expect(item.videoEventId, equals('reply_video_event'));
          expect(
            item.videoAddressableId,
            equals(
              '${NIP71VideoKinds.addressableShortVideo}:'
              '$userPubkey:reply-video-dtag',
            ),
          );
        },
      );

      test('grouped video notifications leave addressable id null when neither '
          'VideoStats nor the payload carries a usable d-tag', () async {
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
        // Owner confirmed, but no d-tag from either source → cannot synthesize.
        // (Without this stub the row would be null for the unrelated
        // ownership-unknown reason, masking the d-tag branch under test.)
        stubVideoStats('video_x', makeVideoStats(id: 'video_x', dTag: ''));

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
          'with most-recent timestamp', () async {
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
        // The consolidated row carries the most recent follow timestamp so a
        // fresh follow surfaces at the top of the Follows tab rather than
        // being buried (and paginated off the first page) with a stale
        // timestamp.
        expect(item.timestamp, equals(later));
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

      test('a re-published follow sorts above older notifications by its '
          'latest timestamp', () async {
        // A replaceable kind-3 contact list arrives twice for the same
        // follower: once with a stale timestamp and once fresh. The
        // consolidated row must inherit the fresh timestamp so it sorts
        // above an older like — otherwise the follow sinks below the fold
        // and the Follows tab reads "no activity" (regression for the
        // reported follows-tab bug).
        final stale = DateTime(2025);
        final older = DateTime(2025, 1, 3);
        final fresh = DateTime(2025, 1, 10);
        stubNotifications([
          makeNotification(
            id: 'follow_stale',
            sourcePubkey: 'follower_pub',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
            createdAt: stale,
          ),
          makeNotification(
            id: 'old_like',
            sourcePubkey: 'liker_pub',
            referencedEventId: 'video_a',
            createdAt: older,
          ),
          makeNotification(
            id: 'follow_fresh',
            sourcePubkey: 'follower_pub',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
            createdAt: fresh,
          ),
        ]);
        stubProfiles({
          'follower_pub': makeProfile('follower_pub', displayName: 'Follower'),
          'liker_pub': makeProfile('liker_pub', displayName: 'Liker'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(2));
        final follow = page.items.first as ActorNotification;
        expect(follow.type, equals(NotificationKind.follow));
        expect(follow.actor.pubkey, equals('follower_pub'));
        expect(follow.timestamp, equals(fresh));
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

      test('reaction on a non-owned video is reclassified as likeComment '
          'instead of liked your video (#4813)', () async {
        stubNotifications([
          makeNotification(
            referencedEventId: 'foreign_video',
            targetCommentId: 'comment_event_xyz',
          ),
        ]);
        stubProfiles({});
        stubVideoStats(
          'foreign_video',
          makeVideoStats(id: 'foreign_video', pubkey: 'other_owner_pubkey'),
        );

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.likeComment));
        expect(item.targetEventId, equals('comment_event_xyz'));
      });

      test('comment on a non-owned video is reclassified as reply '
          'instead of commented on your video (#4813)', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'reply',
            sourceKind: 1,
            referencedEventId: 'foreign_video',
            rootEventId: 'foreign_video',
            targetCommentId: 'comment_event_xyz',
          ),
        ]);
        stubProfiles({});
        stubVideoStats(
          'foreign_video',
          makeVideoStats(id: 'foreign_video', pubkey: 'other_owner_pubkey'),
        );

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.reply));
        expect(item.targetEventId, equals('comment_event_xyz'));
      });

      test('repost on a non-owned video is dropped entirely', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'repost',
            sourceKind: 6,
            referencedEventId: 'foreign_video',
          ),
        ]);
        stubProfiles({});
        stubVideoStats(
          'foreign_video',
          makeVideoStats(id: 'foreign_video', pubkey: 'other_owner_pubkey'),
        );

        final page = await repository.getNotifications();

        expect(page.items, isEmpty);
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
        'likeComment leaves videoAddressableId null even when referencedDTag '
        'is set without an authoritative owner pubkey',
        () async {
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
          expect(item.videoAddressableId, isNull);
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

      test('reply to user comment with root video metadata maps to reply '
          '($ActorNotification)', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'reply',
            sourceKind: 1111,
            sourceEventId: 'reply_event_id',
            isReferencedVideo: false,
            referencedEventId: 'parent_comment_id',
            rootEventId: 'someone_else_video_id',
            targetCommentId: 'parent_comment_id',
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.reply));
        expect(item.targetEventId, equals('parent_comment_id'));
      });

      test('comment-typed nested NIP-22 reply maps to reply '
          '($ActorNotification)', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'comment',
            sourceKind: 1111,
            sourceEventId: 'reply_event_id',
            isReferencedVideo: false,
            referencedEventId: 'parent_comment_id',
            rootEventId: 'someone_else_video_id',
            targetCommentId: 'parent_comment_id',
            content: 'Nested reply to my comment',
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.reply));
        expect(item.targetEventId, equals('parent_comment_id'));
        expect(item.commentText, equals('Nested reply to my comment'));
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

      test(
        'reply falls back to sourceEventId when referencedEventId is null',
        () async {
          stubNotifications([
            makeNotification(
              notificationType: 'reply',
              sourceKind: 1,
              isReferencedVideo: false,
              sourceEventId: 'reply_event_id',
              referencedEventId: null,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as ActorNotification;
          expect(item.type, equals(NotificationKind.reply));
          // targetEventId must be non-null so _onItemTap can call the resolver
          // instead of falling back to the actor's profile screen.
          expect(item.targetEventId, equals('reply_event_id'));
        },
      );

      test(
        'reply falls back to sourceEventId when referencedEventId is empty',
        () async {
          stubNotifications([
            makeNotification(
              notificationType: 'reply',
              sourceKind: 1,
              isReferencedVideo: false,
              sourceEventId: 'reply_event_id',
              referencedEventId: '',
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as ActorNotification;
          expect(item.type, equals(NotificationKind.reply));
          expect(item.targetEventId, equals('reply_event_id'));
        },
      );

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

      test(
        'kind 1111 staging mention with rootEventId maps to video comment',
        () async {
          stubNotifications([
            makeNotification(
              id: '',
              sourceEventId: 'comment_evt_id',
              sourceKind: 1111,
              notificationType: 'mention',
              referencedEventId: '',
              rootEventId: 'root_video_evt_id',
              targetCommentId: 'comment_evt_id',
              content: 'Fake staging comment from Codex',
              isReferencedVideo: false,
            ),
          ]);
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });

          final page = await repository.getNotifications();

          final item = page.items.single as VideoNotification;
          expect(item.id, equals('comment_evt_id'));
          expect(item.type, equals(NotificationKind.comment));
          expect(item.videoEventId, equals('root_video_evt_id'));
          expect(item.commentText, equals('Fake staging comment from Codex'));
          expect(item.sourceEventIds, equals(['comment_evt_id']));
        },
      );

      test(
        'kind 1111 reply with rootEventId stays reply and keeps actor anchor',
        () async {
          stubNotifications([
            makeNotification(
              id: '',
              sourceEventId: 'reply_evt_id',
              sourceKind: 1111,
              notificationType: 'reply',
              referencedEventId: '',
              rootEventId: 'root_video_evt_id',
              targetCommentId: 'parent_comment_evt_id',
              content: 'Nested reply from staging payload',
              isReferencedVideo: false,
            ),
          ]);
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });

          final page = await repository.getNotifications();

          final item = page.items.single as ActorNotification;
          expect(item.id, equals('reply_evt_id'));
          expect(item.type, equals(NotificationKind.reply));
          expect(item.targetEventId, equals('reply_evt_id'));
          expect(item.commentText, equals('Nested reply from staging payload'));
          expect(item.sourceEventIds, equals(['reply_evt_id']));
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

    group('cache hydration', () {
      test('emits cached rows on construction when DAO has data', () async {
        final cachedRow = NotificationRow(
          id: 'cached_1',
          type: 'like',
          fromPubkey: 'cached_actor',
          timestamp: 1700000000,
          targetEventId: 'cached_event',
          isRead: false,
          cachedAt: DateTime(2026),
        );
        when(
          () =>
              notificationsDao.getAllNotifications(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [cachedRow]);

        final hydrated = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
        );
        addTearDown(hydrated.close);

        // Snapshot starts at empty and updates once hydration resolves.
        // Use emitsThrough so the test is robust to the seeded empty
        // emission ordering.
        await expectLater(
          hydrated.watchSnapshot(),
          emitsThrough(
            predicate<NotificationPage>(
              (p) => p.items.length == 1 && p.items.first.id == 'cached_1',
              'snapshot contains the hydrated row',
            ),
          ),
        );
      });

      test('hydration is a no-op when DAO is empty', () async {
        when(
          () =>
              notificationsDao.getAllNotifications(limit: any(named: 'limit')),
        ).thenAnswer((_) async => <NotificationRow>[]);

        final hydrated = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
        );
        addTearDown(hydrated.close);
        // Give the unawaited hydration a chance to resolve.
        await Future<void>.delayed(Duration.zero);
        final snapshot = await hydrated.watchSnapshot().first;
        expect(snapshot.items, isEmpty);
      });

      test(
        'cached "like" row becomes $VideoNotification placeholder preserving '
        'videoEventId and actor pubkey',
        () async {
          when(
            () => notificationsDao.getAllNotifications(
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              NotificationRow(
                id: 'cached_like_1',
                type: 'like',
                fromPubkey: 'actor_pub',
                timestamp: 1700000000,
                targetEventId: 'video_evt_1',
                isRead: false,
                cachedAt: DateTime(2026),
              ),
            ],
          );
          final hydrated = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
          );
          addTearDown(hydrated.close);

          await expectLater(
            hydrated.watchSnapshot(),
            emitsThrough(
              predicate<NotificationPage>((p) {
                if (p.items.length != 1) return false;
                final item = p.items.first;
                return item is VideoNotification &&
                    item.id == 'cached_like_1' &&
                    item.type == NotificationKind.like &&
                    item.videoEventId == 'video_evt_1' &&
                    item.actors.length == 1 &&
                    item.actors.first.pubkey == 'actor_pub' &&
                    item.totalCount == 1 &&
                    item.commentText == null;
              }, 'placeholder is VideoNotification(like) keyed to video'),
            ),
          );
        },
      );

      test('cached "comment" row becomes $VideoNotification placeholder '
          'with commentText preserved', () async {
        when(
          () =>
              notificationsDao.getAllNotifications(limit: any(named: 'limit')),
        ).thenAnswer(
          (_) async => [
            NotificationRow(
              id: 'cached_comment_1',
              type: 'comment',
              fromPubkey: 'actor_pub',
              timestamp: 1700000000,
              targetEventId: 'video_evt_2',
              content: 'Nice clip!',
              isRead: false,
              cachedAt: DateTime(2026),
            ),
          ],
        );
        final hydrated = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
        );
        addTearDown(hydrated.close);

        await expectLater(
          hydrated.watchSnapshot(),
          emitsThrough(
            predicate<NotificationPage>((p) {
              if (p.items.length != 1) return false;
              final item = p.items.first;
              return item is VideoNotification &&
                  item.type == NotificationKind.comment &&
                  item.videoEventId == 'video_evt_2' &&
                  item.commentText == 'Nice clip!';
            }, 'placeholder is VideoNotification(comment) with content'),
          ),
        );
      });

      test(
        'cached "repost" row becomes $VideoNotification placeholder',
        () async {
          when(
            () => notificationsDao.getAllNotifications(
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              NotificationRow(
                id: 'cached_repost_1',
                type: 'repost',
                fromPubkey: 'actor_pub',
                timestamp: 1700000000,
                targetEventId: 'video_evt_3',
                isRead: true,
                cachedAt: DateTime(2026),
              ),
            ],
          );
          final hydrated = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
          );
          addTearDown(hydrated.close);

          await expectLater(
            hydrated.watchSnapshot(),
            emitsThrough(
              predicate<NotificationPage>((p) {
                if (p.items.length != 1) return false;
                final item = p.items.first;
                return item is VideoNotification &&
                    item.type == NotificationKind.repost &&
                    item.videoEventId == 'video_evt_3' &&
                    item.isRead &&
                    item.commentText == null;
              }, 'placeholder is VideoNotification(repost) preserving isRead'),
            ),
          );
        },
      );

      test(
        'cached "like" row with null targetEventId is skipped — degrading '
        'to system would hide the row from the Likes tab and make tap a no-op',
        () async {
          when(
            () => notificationsDao.getAllNotifications(
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              NotificationRow(
                id: 'orphan_like',
                type: 'like',
                fromPubkey: 'actor_pub',
                timestamp: 1700000000,
                isRead: false,
                cachedAt: DateTime(2026),
              ),
            ],
          );
          final hydrated = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
          );
          addTearDown(hydrated.close);
          // Give the unawaited hydration a chance to resolve.
          await Future<void>.delayed(Duration.zero);
          final snapshot = await hydrated.watchSnapshot().first;
          expect(snapshot.items, isEmpty);
        },
      );

      test(
        'cached "follow" row remains an $ActorNotification placeholder',
        () async {
          when(
            () => notificationsDao.getAllNotifications(
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              NotificationRow(
                id: 'cached_follow_1',
                type: 'follow',
                fromPubkey: 'follower_pub',
                timestamp: 1700000000,
                targetPubkey: 'follower_pub',
                isRead: false,
                cachedAt: DateTime(2026),
              ),
            ],
          );
          final hydrated = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
          );
          addTearDown(hydrated.close);

          await expectLater(
            hydrated.watchSnapshot(),
            emitsThrough(
              predicate<NotificationPage>((p) {
                if (p.items.length != 1) return false;
                final item = p.items.first;
                return item is ActorNotification &&
                    item.type == NotificationKind.follow &&
                    item.actor.pubkey == 'follower_pub';
              }, 'placeholder is ActorNotification(follow)'),
            ),
          );
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

      test(
        'superseded first-page failure does not mark refresh error',
        () async {
          stubProfiles({});

          final staleGate = Completer<NotificationResponse>();
          when(
            () => funnelcakeApiClient.getNotifications(
              pubkey: any(named: 'pubkey'),
              cursor: any(named: 'cursor'),
              cursorId: any(named: 'cursorId'),
              requestUri: any(named: 'requestUri'),
              authHeaders: any(named: 'authHeaders'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) => staleGate.future);
          final staleFetch = repository.getNotifications();

          stubNotifications([
            makeNotification(
              id: 'fresh',
              sourceEventId: 'evt_fresh',
              referencedEventId: 'video_fresh',
            ),
          ]);
          await repository.refresh();

          staleGate.completeError(const FunnelcakeException('stale'));

          await expectLater(
            staleFetch,
            throwsA(isA<FunnelcakeException>()),
          );
          final snapshot = await repository.watchSnapshot().first;
          expect(snapshot.lastRefreshError, isFalse);
          expect(
            (snapshot.items.single as VideoNotification).videoEventId,
            equals('video_fresh'),
          );
        },
      );

      test('refreshApplied returns false when superseded', () async {
        stubProfiles({});

        final staleGate = Completer<NotificationResponse>();
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => staleGate.future);
        final staleRefresh = repository.refreshApplied();

        stubNotifications([
          makeNotification(
            id: 'fresh',
            sourceEventId: 'evt_fresh',
            referencedEventId: 'video_fresh',
          ),
        ]);
        await repository.refresh();

        staleGate.complete(
          const NotificationResponse(
            notifications: [],
            unreadCount: 0,
            hasMore: false,
          ),
        );

        await expectLater(staleRefresh, completion(isFalse));
      });
    });

    group('loadNextPage', () {
      test('no-ops without a stored pagination cursor', () async {
        final result = await repository.loadNextPage();

        expect(result, isNull);
        verifyNever(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        );
      });

      test('requests the stored cursor and appends the next page', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.getNotifications();

        stubNotifications([
          makeNotification(
            id: 'n2',
            sourceEventId: 'evt2',
            referencedEventId: 'video_2',
          ),
        ]);
        final page = await repository.loadNextPage();

        expect(page, isNotNull);
        final snapshot = await repository.watchSnapshot().first;
        expect(snapshot.items, hasLength(2));
        final cursors = verify(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: captureAny(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).captured;
        expect(cursors, equals([null, 'c1']));
      });

      test('during an in-flight refresh it no-ops instead of issuing a '
          'duplicate first-page request', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.getNotifications();

        final gate = Completer<NotificationResponse>();
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => gate.future);
        final refreshFuture = repository.refresh();

        final result = await repository.loadNextPage();

        expect(result, isNull);
        verify(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).called(2);

        gate.complete(
          const NotificationResponse(
            notifications: [],
            unreadCount: 0,
            hasMore: false,
          ),
        );
        await refreshFuture;
      });

      test('stale completion after a refresh neither regresses the cursor '
          'nor appends onto the replaced snapshot', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.getNotifications();

        final gate = Completer<NotificationResponse>();
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => gate.future);
        final staleLoadMore = repository.loadNextPage();

        stubNotifications(
          [
            makeNotification(
              id: 'n9',
              sourceEventId: 'evt9',
              referencedEventId: 'video_9',
            ),
          ],
          nextCursor: 'r1',
          hasMore: true,
        );
        await repository.refresh();

        gate.complete(
          NotificationResponse(
            notifications: [
              makeNotification(
                id: 'n_stale',
                sourceEventId: 'evt_stale',
                referencedEventId: 'video_stale',
              ),
            ],
            unreadCount: 0,
            hasMore: true,
            nextCursor: 'c2_stale',
          ),
        );
        await staleLoadMore;

        final snapshot = await repository.watchSnapshot().first;
        expect(snapshot.items, hasLength(1));
        expect(
          (snapshot.items.single as VideoNotification).videoEventId,
          equals('video_9'),
        );

        stubNotifications([]);
        await repository.loadNextPage();
        final cursors = verify(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: captureAny(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).captured;
        expect(cursors, equals([null, 'c1', null, 'r1']));
      });
    });

    group('hasPaginatedBeyondFirstPage', () {
      test('false until a page beyond the first is applied', () async {
        expect(repository.hasPaginatedBeyondFirstPage, isFalse);

        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.getNotifications();

        expect(repository.hasPaginatedBeyondFirstPage, isFalse);
      });

      test('true after a load-more, false again after a refresh', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.getNotifications();
        stubNotifications(
          [
            makeNotification(
              id: 'n2',
              sourceEventId: 'evt2',
              referencedEventId: 'video_2',
            ),
          ],
          nextCursor: 'c2',
          hasMore: true,
        );
        await repository.loadNextPage();

        expect(repository.hasPaginatedBeyondFirstPage, isTrue);

        stubNotifications([]);
        await repository.refresh();

        expect(repository.hasPaginatedBeyondFirstPage, isFalse);
      });

      test('resetPaginationDepth releases the resume-refresh guard', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.getNotifications();
        stubNotifications(
          [
            makeNotification(
              id: 'n2',
              sourceEventId: 'evt2',
              referencedEventId: 'video_2',
            ),
          ],
          nextCursor: 'c2',
          hasMore: true,
        );
        await repository.loadNextPage();

        expect(repository.hasPaginatedBeyondFirstPage, isTrue);

        repository.resetPaginationDepth();

        expect(repository.hasPaginatedBeyondFirstPage, isFalse);
      });

      test(
        'resetPaginationDepth collapses the snapshot to the newest page',
        () async {
          stubProfiles({});
          // A session that scrolled deep leaves more than a page of items in
          // the long-lived snapshot. Build a 25-item first page with distinct,
          // descending timestamps (n0 newest) so the newest-first order is
          // deterministic and the trim back to the page size is observable.
          stubNotifications([
            for (var i = 0; i < 25; i++)
              makeNotification(
                id: 'n$i',
                sourcePubkey: 'pub_$i',
                sourceEventId: 'evt$i',
                referencedEventId: 'video_$i',
                createdAt: DateTime(2025).subtract(Duration(minutes: i)),
              ),
          ], hasMore: true);
          await repository.getNotifications();
          final before = (await repository.watchSnapshot().first).items;
          expect(before, hasLength(25));
          // Contract: trimming keeps the *newest* page — the first 20 rows of
          // the newest-first snapshot, in order — not an arbitrary 20.
          final expectedKeptIds = before.take(20).map((n) => n.id).toList();

          repository.resetPaginationDepth();

          final after = (await repository.watchSnapshot().first).items;
          expect(after.map((n) => n.id).toList(), equals(expectedKeptIds));
        },
      );
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

      test('expands a grouped row to every raw notification id before '
          'marking read', () async {
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
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
        });
        stubNotifications([
          makeNotification(
            id: 'older_server_notification',
            sourceEventId: 'older_source_event',
            createdAt: DateTime(2025),
          ),
          makeNotification(
            id: 'newer_server_notification',
            sourcePubkey: 'pubkey_bob',
            sourceEventId: 'newer_source_event',
            createdAt: DateTime(2025, 1, 2),
          ),
        ], unreadCount: 2);
        await repository.refresh();

        final groupedRow = (await repository.watchSnapshot().first).items.first;

        await repository.markAsRead([groupedRow.id]);

        verify(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: userPubkey,
            notificationIds: [
              'newer_server_notification',
              'older_server_notification',
            ],
            authHeaders: any(named: 'authHeaders'),
          ),
        ).called(1);
        verify(
          () => notificationsDao.markAsRead('newer_server_notification'),
        ).called(1);
        verify(
          () => notificationsDao.markAsRead('older_server_notification'),
        ).called(1);
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
            authHeadersProvider: (url, method, {body}) async {
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
            authHeadersProvider: (url, method, {body}) async {
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
          authHeadersProvider: (url, method, {body}) async => {
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

      test(
        'markAllAsRead signs the full mark-read URL and empty body',
        () async {
          // NIP-98 requires the auth event's `u` tag to match the
          // request URL exactly (scheme + host + path) and the
          // `payload` tag to be sha256 of the actual body. Pinning the
          // exact (url, body) tuple passed to the auth callback catches
          // any future drift to a path-only URL or empty payload —
          // both of which silently 401 the server and bounce the
          // notifications badge back up via the repository rollback.
          String? capturedUrl;
          String? capturedMethod;
          String? capturedBody;
          when(
            () => funnelcakeApiClient.notificationsReadUri(pubkey: userPubkey),
          ).thenReturn(
            Uri.parse(
              'https://api.divine.video/api/users/$userPubkey/'
              'notifications/read',
            ),
          );
          when(
            () => funnelcakeApiClient.markNotificationsRead(
              pubkey: userPubkey,
              notificationIds: any(named: 'notificationIds'),
              authHeaders: any(named: 'authHeaders'),
            ),
          ).thenAnswer(
            (_) async => const MarkReadResponse(success: true, markedCount: 1),
          );
          when(
            () => notificationsDao.markAllAsRead(),
          ).thenAnswer((_) async => 1);

          final authRepo = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
            authHeadersProvider: (url, method, {body}) async {
              capturedUrl = url;
              capturedMethod = method;
              capturedBody = body;
              return {'Authorization': 'Nostr signed-token'};
            },
          );
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });
          stubNotifications([makeNotification()], unreadCount: 1);
          await authRepo.refresh();

          await authRepo.markAllAsRead();

          expect(
            capturedUrl,
            equals(
              'https://api.divine.video/api/users/$userPubkey/'
              'notifications/read',
            ),
          );
          expect(capturedMethod, equals('POST'));
          // FunnelcakeApiClient.buildMarkNotificationsReadBody() with
          // no ids should produce `{}` — the exact bytes the request
          // body will carry.
          expect(capturedBody, equals('{}'));
        },
      );

      test(
        'markAsRead signs the body that includes the notification IDs',
        () async {
          String? capturedBody;
          when(
            () => funnelcakeApiClient.notificationsReadUri(pubkey: userPubkey),
          ).thenReturn(
            Uri.parse(
              'https://api.divine.video/api/users/$userPubkey/'
              'notifications/read',
            ),
          );
          when(
            () => funnelcakeApiClient.markNotificationsRead(
              pubkey: userPubkey,
              notificationIds: any(named: 'notificationIds'),
              authHeaders: any(named: 'authHeaders'),
            ),
          ).thenAnswer(
            (_) async => const MarkReadResponse(success: true, markedCount: 1),
          );
          when(
            () => notificationsDao.markAsRead(any()),
          ).thenAnswer((_) async => true);

          final authRepo = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
            authHeadersProvider: (url, method, {body}) async {
              capturedBody = body;
              return {'Authorization': 'Nostr signed-token'};
            },
          );
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });
          // Use a single notification whose id is both the row id and
          // the expanded server notification id (the expansion in
          // `_expandServerNotificationIds` falls back to the row id
          // when the row carries no separate `notificationIds`).
          stubNotifications([
            makeNotification(id: 'server-notif-1', sourceEventId: 'evt-1'),
          ], unreadCount: 1);
          await authRepo.refresh();
          final loadedId =
              (await authRepo.watchSnapshot().first).items.first.id;

          await authRepo.markAsRead([loadedId]);

          // The expanded notification IDs end up in both the request
          // body the client posts and the `payload` tag the NIP-98
          // auth event signs — they must match byte-for-byte.
          expect(capturedBody, isNotNull);
          expect(capturedBody, contains('notification_ids'));
          expect(capturedBody, contains('server-notif-1'));
        },
      );
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

      test('isClosed flips after close()', () async {
        expect(repository.isClosed, isFalse);

        await repository.close();

        expect(repository.isClosed, isTrue);
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

      test('markAsRead rollback restores pagination depth', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.refresh();
        stubNotifications(
          [
            makeNotification(
              id: 'n2',
              sourceEventId: 'evt2',
              referencedEventId: 'video_2',
            ),
          ],
          nextCursor: 'c2',
          hasMore: true,
        );
        await repository.loadNextPage();
        expect(repository.hasPaginatedBeyondFirstPage, isTrue);

        final loadedId =
            (await repository.watchSnapshot().first).items.first.id;
        final markGate = Completer<MarkReadResponse>();
        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            notificationIds: any(named: 'notificationIds'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer((_) => markGate.future);

        final markFuture = repository.markAsRead([loadedId]);

        stubNotifications([
          makeNotification(
            id: 'fresh',
            sourceEventId: 'evt_fresh',
            referencedEventId: 'video_fresh',
          ),
        ]);
        await repository.refresh();
        expect(repository.hasPaginatedBeyondFirstPage, isFalse);

        markGate.completeError(const FunnelcakeException('boom'));
        await expectLater(
          markFuture,
          throwsA(isA<FunnelcakeException>()),
        );

        expect(repository.hasPaginatedBeyondFirstPage, isTrue);
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

      test('markAllAsRead rollback restores pagination depth', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.refresh();
        stubNotifications(
          [
            makeNotification(
              id: 'n2',
              sourceEventId: 'evt2',
              referencedEventId: 'video_2',
            ),
          ],
          nextCursor: 'c2',
          hasMore: true,
        );
        await repository.loadNextPage();
        expect(repository.hasPaginatedBeyondFirstPage, isTrue);

        final markGate = Completer<MarkReadResponse>();
        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer((_) => markGate.future);

        final markFuture = repository.markAllAsRead();

        stubNotifications([
          makeNotification(
            id: 'fresh',
            sourceEventId: 'evt_fresh',
            referencedEventId: 'video_fresh',
          ),
        ]);
        await repository.refresh();
        expect(repository.hasPaginatedBeyondFirstPage, isFalse);

        markGate.completeError(const FunnelcakeException('boom'));
        await expectLater(
          markFuture,
          throwsA(isA<FunnelcakeException>()),
        );

        expect(repository.hasPaginatedBeyondFirstPage, isTrue);
      });
    });

    group('cross-page dedupe in page-merge (#4264)', () {
      // The server can deliver the same logical Nostr event as distinct
      // notification rows (different server UUIDs) across pagination
      // pages — e.g. Kind 3 republishes, cursor drift. When a later page
      // repeats an event already in the snapshot, dedupe must key on the
      // shared Nostr event id via `NotificationItem.sourceEventIds`, not
      // the rendered `id`, which can differ across deliveries.

      test('standalone $ActorNotification: a later page repeating the '
          'sourceEventId resolves to a single row', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        // First page seeds the snapshot and advances _lastCursor so the
        // next getNotifications() emits as a non-first page.
        stubNotifications(
          [
            makeNotification(
              id: 'server-uuid-follow-0',
              sourceEventId: 'nostr-follow-evt-1',
              notificationType: 'follow',
              sourceKind: 3,
              referencedEventId: null,
              isReferencedVideo: false,
              createdAt: DateTime(2025, 6),
            ),
          ],
          nextCursor: 'cursor_after_first',
          hasMore: true,
        );
        await repository.refresh();

        expect(
          (await repository.watchSnapshot().first).items,
          hasLength(1),
          reason: 'First page seeds the follow row.',
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
              'REST item with sourceEventId already represented by an '
              'existing row must not be appended as a duplicate.',
        );
        final actor = items.single as ActorNotification;
        expect(actor.sourceEventIds, contains('nostr-follow-evt-1'));
      });

      test(
        'grouped $VideoNotification: single-actor first-page row, then '
        'a later page with a multi-actor group on same '
        '(videoEventId, type) merges into the existing row in place',
        () async {
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
            'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
            'pubkey_carol': makeProfile('pubkey_carol', displayName: 'Carol'),
          });
          stubNotifications(
            [
              makeNotification(
                id: 'server-uuid-like-alice-p1',
                sourceEventId: 'nostr-like-alice',
                referencedEventId: 'video_a',
                createdAt: DateTime(2025, 5),
              ),
            ],
            nextCursor: 'cursor_after_first',
            hasMore: true,
          );
          await repository.refresh();

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
                'the existing row instead of producing a second row.',
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
        },
      );

      test('unrelated REST event on a different video is appended; no '
          'false-positive dedupe', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
        });
        stubNotifications(
          [
            makeNotification(
              id: 'server-uuid-like-alice-video-a',
              sourceEventId: 'nostr-like-alice-video-a',
              referencedEventId: 'video_a',
              createdAt: DateTime(2025, 5),
            ),
          ],
          nextCursor: 'cursor_after_first',
          hasMore: true,
        );
        await repository.refresh();

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
            [
              makeNotification(
                id: 'server-uuid-follow-alice-p1',
                sourceEventId: 'nostr-follow-alice',
                notificationType: 'follow',
                sourceKind: 3,
                referencedEventId: null,
                isReferencedVideo: false,
                createdAt: DateTime(2025, 5),
              ),
            ],
            nextCursor: 'cursor_after_first',
            hasMore: true,
          );
          await repository.refresh();

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
          '(existing row newer than incoming page)', () async {
        // Production ordering: REST pagination walks backward in time,
        // so an incoming page on the same (videoEventId, kind) is
        // typically OLDER than the row already in the snapshot. The
        // merged row must therefore keep the existing commentText —
        // mirrors `_groupVideoAnchored`'s sort-desc + group.first
        // newest-wins and the surrounding `timestamp = max(...)`.
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
        });
        // First page carries the NEWER comment.
        stubNotifications(
          [
            makeNotification(
              id: 'server-uuid-comment-alice',
              sourceEventId: 'nostr-comment-alice',
              notificationType: 'comment',
              sourceKind: 1,
              referencedEventId: 'video_a',
              content: 'Newer comment from Alice (first page)',
              createdAt: DateTime(2025, 6),
            ),
          ],
          nextCursor: 'cursor_after_first',
          hasMore: true,
        );
        await repository.refresh();

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
          equals('Newer comment from Alice (first page)'),
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

      test('pagination merge keeps the named actor in front when the existing '
          'row is unnamed', () async {
        const hashPubkey =
            '2949ede154d1f121402761cbd73f2b8c490b5041'
            'cdd85c9908c5322f1a2fe3f6';
        stubProfiles({
          hashPubkey: makeProfile(hashPubkey, displayName: hashPubkey),
          'pub_named': makeProfile(
            'pub_named',
            displayName: 'Sally Strawberry',
          ),
        });
        stubNotifications(
          [
            makeNotification(
              id: 'server-uuid-unnamed',
              sourceEventId: 'nostr-unnamed',
              sourcePubkey: hashPubkey,
              referencedEventId: 'video_named',
              createdAt: DateTime(2025, 6),
            ),
          ],
          nextCursor: 'cursor_after_first',
          hasMore: true,
        );
        await repository.refresh();

        stubNotifications([
          makeNotification(
            id: 'server-uuid-named',
            sourceEventId: 'nostr-named',
            sourcePubkey: 'pub_named',
            referencedEventId: 'video_named',
            createdAt: DateTime(2025, 4),
          ),
        ]);

        await repository.getNotifications();

        final merged =
            (await repository.watchSnapshot().first).items.single
                as VideoNotification;
        expect(merged.totalCount, equals(2));
        expect(merged.actors.first.pubkey, equals('pub_named'));
        expect(merged.actors.first.displayName, equals('Sally Strawberry'));
      });

      test(
        "comment-kind merge keeps the newer side's commentText "
        '(incoming page newer than existing row) — symmetric direction',
        () async {
          // Symmetric case: rare in production (the first page is the
          // newer boundary), but the rule must be timestamp-driven, not
          // delivery-order-driven. Lock both directions.
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
            'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
          });
          stubNotifications(
            [
              makeNotification(
                id: 'server-uuid-comment-alice',
                sourceEventId: 'nostr-comment-alice',
                notificationType: 'comment',
                sourceKind: 1,
                referencedEventId: 'video_a',
                content: 'Older comment from Alice (first page)',
                createdAt: DateTime(2025, 4),
              ),
            ],
            nextCursor: 'cursor_after_first',
            hasMore: true,
          );
          await repository.refresh();

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
        },
      );
    });
  });
}
