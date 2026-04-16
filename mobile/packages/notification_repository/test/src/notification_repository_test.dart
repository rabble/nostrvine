// ABOUTME: Tests for NotificationRepository covering enrichment, like
// ABOUTME: grouping, follow consolidation, type mapping, and truncation.

import 'package:db_client/db_client.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:test/test.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockNotificationsDao extends Mock implements NotificationsDao {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  late _MockFunnelcakeApiClient funnelcakeApiClient;
  late _MockProfileRepository profileRepository;
  late _MockNotificationsDao notificationsDao;
  late _MockNostrClient nostrClient;
  late NotificationRepository repository;

  const userPubkey = 'user1234567890abcdef';

  setUp(() {
    funnelcakeApiClient = _MockFunnelcakeApiClient();
    profileRepository = _MockProfileRepository();
    notificationsDao = _MockNotificationsDao();
    nostrClient = _MockNostrClient();
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
          cursor ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      return Uri.parse(
        'https://api.example.com/api/users/$pubkey/notifications',
      ).replace(
        queryParameters: <String, String>{
          'limit': '$limit',
          'before': effectiveBefore,
        },
      );
    });
    repository = NotificationRepository(
      funnelcakeApiClient: funnelcakeApiClient,
      profileRepository: profileRepository,
      notificationsDao: notificationsDao,
      userPubkey: userPubkey,
      nostrClient: nostrClient,
    );
  });

  /// Helper to create a [RelayNotification] with sensible defaults.
  RelayNotification makeNotification({
    String id = 'n1',
    String sourcePubkey = 'pubkey_alice',
    String sourceEventId = 'evt1',
    int sourceKind = 7,
    String notificationType = 'reaction',
    DateTime? createdAt,
    bool read = false,
    String? referencedEventId,
    String? content,
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
      content: content,
    );
  }

  /// Stubs [ProfileRepository.fetchBatchProfiles] to return the given map.
  void stubProfiles(Map<String, UserProfile> profiles) {
    when(
      () => profileRepository.fetchBatchProfiles(
        pubkeys: any(named: 'pubkeys'),
      ),
    ).thenAnswer((_) async => profiles);
  }

  /// Stubs [FunnelcakeApiClient.getNotifications] to return a response
  /// containing [notifications].
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
          nostrClient: nostrClient,
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
          equals(
            'https://api.example.com/api/users/$userPubkey/notifications',
          ),
        );
        expect(signedUri.queryParameters['limit'], equals('50'));
        expect(signedUri.queryParameters['before'], isNotNull);
        expect(
          int.tryParse(signedUri.queryParameters['before']!),
          isNotNull,
        );
        expect(signedMethod, equals('GET'));
      });

      test('signs the full paginated notifications URL with cursor', () async {
        var signedUrl = '';
        repository = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
          nostrClient: nostrClient,
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

      test('returns enriched items with real profile data', () async {
        stubNotifications([
          makeNotification(
            sourcePubkey: 'alice_pub',
            referencedEventId: 'video1',
          ),
        ]);
        stubProfiles({
          'alice_pub': makeProfile(
            'alice_pub',
            displayName: 'Alice',
            picture: 'https://example.com/alice.jpg',
          ),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.first as SingleNotification;
        expect(item.actor.displayName, equals('Alice'));
        expect(item.actor.pictureUrl, equals('https://example.com/alice.jpg'));
        expect(item.type, equals(NotificationKind.like));
      });

      test('falls back to "Unknown user" for missing profiles', () async {
        stubNotifications([
          makeNotification(
            sourcePubkey: 'unknown_pub',
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.first as SingleNotification;
        expect(item.actor.displayName, equals('Unknown user'));
        expect(item.actor.pictureUrl, isNull);
      });

      test('returns empty page on API error', () async {
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(Exception('network error'));

        final page = await repository.getNotifications();

        expect(page.items, isEmpty);
        expect(page.unreadCount, equals(0));
      });

      test('passes cursor for pagination', () async {
        stubNotifications([], nextCursor: 'cursor_abc', hasMore: true);
        stubProfiles({});

        final page = await repository.getNotifications();
        expect(page.nextCursor, equals('cursor_abc'));
        expect(page.hasMore, isTrue);

        // Second call should use stored cursor.
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
            nostrClient: nostrClient,
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
            nostrClient: nostrClient,
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

    group('like grouping', () {
      test(
        '3 likes on same video become 1 GroupedNotification '
        'with totalCount 3',
        () async {
          stubNotifications([
            makeNotification(
              id: 'l1',
              sourcePubkey: 'pub_a',
              referencedEventId: 'video_x',
              createdAt: DateTime(2025, 1, 3),
            ),
            makeNotification(
              id: 'l2',
              sourcePubkey: 'pub_b',
              referencedEventId: 'video_x',
              createdAt: DateTime(2025, 1, 2),
            ),
            makeNotification(
              id: 'l3',
              sourcePubkey: 'pub_c',
              referencedEventId: 'video_x',
              createdAt: DateTime(2025),
            ),
          ]);
          stubProfiles({
            'pub_a': makeProfile('pub_a', displayName: 'Alice'),
            'pub_b': makeProfile('pub_b', displayName: 'Bob'),
            'pub_c': makeProfile('pub_c', displayName: 'Charlie'),
          });

          final page = await repository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.first as GroupedNotification;
          expect(item.type, equals(NotificationKind.like));
          expect(item.totalCount, equals(3));
          expect(item.actors, hasLength(3));
          expect(item.actors.first.displayName, equals('Alice'));
          expect(item.targetEventId, equals('video_x'));
          expect(item.id, equals('group_like_video_x'));
        },
      );

      test('single like stays as SingleNotification', () async {
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: 'pub_a',
            referencedEventId: 'video_y',
          ),
        ]);
        stubProfiles({
          'pub_a': makeProfile('pub_a', displayName: 'Alice'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        expect(page.items.first, isA<SingleNotification>());
      });

      test('likes on different videos are not grouped together', () async {
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: 'pub_a',
            referencedEventId: 'video_1',
          ),
          makeNotification(
            id: 'l2',
            sourcePubkey: 'pub_b',
            referencedEventId: 'video_2',
          ),
        ]);
        stubProfiles({
          'pub_a': makeProfile('pub_a', displayName: 'Alice'),
          'pub_b': makeProfile('pub_b', displayName: 'Bob'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(2));
        expect(page.items[0], isA<SingleNotification>());
        expect(page.items[1], isA<SingleNotification>());
      });
    });

    group('follow consolidation', () {
      test(
        '2 follows from same pubkey become 1 notification '
        'with earliest timestamp',
        () async {
          final earlier = DateTime(2025);
          final later = DateTime(2025, 1, 5);
          stubNotifications([
            makeNotification(
              id: 'f1',
              sourcePubkey: 'follower_pub',
              notificationType: 'follow',
              sourceKind: 3,
              createdAt: later,
            ),
            makeNotification(
              id: 'f2',
              sourcePubkey: 'follower_pub',
              notificationType: 'follow',
              sourceKind: 3,
              createdAt: earlier,
            ),
          ]);
          stubProfiles({
            'follower_pub': makeProfile(
              'follower_pub',
              displayName: 'Follower',
            ),
          });

          final page = await repository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.first as SingleNotification;
          expect(item.type, equals(NotificationKind.follow));
          expect(item.timestamp, equals(earlier));
        },
      );

      test(
        'follows from different pubkeys are not consolidated',
        () async {
          stubNotifications([
            makeNotification(
              id: 'f1',
              sourcePubkey: 'pub_a',
              notificationType: 'follow',
              sourceKind: 3,
            ),
            makeNotification(
              id: 'f2',
              sourcePubkey: 'pub_b',
              notificationType: 'follow',
              sourceKind: 3,
            ),
          ]);
          stubProfiles({
            'pub_a': makeProfile('pub_a', displayName: 'Alice'),
            'pub_b': makeProfile('pub_b', displayName: 'Bob'),
          });

          final page = await repository.getNotifications();

          expect(page.items, hasLength(2));
        },
      );
    });

    group('comments stay individual', () {
      test('comments are not grouped even on same video', () async {
        stubNotifications([
          makeNotification(
            id: 'c1',
            sourcePubkey: 'pub_a',
            notificationType: 'comment',
            sourceKind: 1,
            referencedEventId: 'video_x',
            content: 'Great video!',
          ),
          makeNotification(
            id: 'c2',
            sourcePubkey: 'pub_b',
            notificationType: 'comment',
            sourceKind: 1,
            referencedEventId: 'video_x',
            content: 'Amazing!',
          ),
        ]);
        stubProfiles({
          'pub_a': makeProfile('pub_a', displayName: 'Alice'),
          'pub_b': makeProfile('pub_b', displayName: 'Bob'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(2));
        expect(page.items[0], isA<SingleNotification>());
        expect(page.items[1], isA<SingleNotification>());
      });
    });

    group('type mapping', () {
      test('reaction maps to like', () async {
        stubNotifications([
          makeNotification(),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.first as SingleNotification;
        expect(item.type, equals(NotificationKind.like));
      });

      test('reply maps to reply', () async {
        stubNotifications([
          makeNotification(notificationType: 'reply', sourceKind: 1),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.first as SingleNotification;
        expect(item.type, equals(NotificationKind.reply));
      });

      test('comment maps to comment', () async {
        stubNotifications([
          makeNotification(notificationType: 'comment', sourceKind: 1),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.first as SingleNotification;
        expect(item.type, equals(NotificationKind.comment));
      });

      test('repost maps to repost', () async {
        stubNotifications([
          makeNotification(notificationType: 'repost', sourceKind: 6),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.first as SingleNotification;
        expect(item.type, equals(NotificationKind.repost));
      });

      test('mention maps to mention', () async {
        stubNotifications([
          makeNotification(notificationType: 'mention', sourceKind: 1),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.first as SingleNotification;
        expect(item.type, equals(NotificationKind.mention));
      });

      test('follow maps to follow', () async {
        stubNotifications([
          makeNotification(notificationType: 'follow', sourceKind: 3),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.first as SingleNotification;
        expect(item.type, equals(NotificationKind.follow));
      });

      test('contact maps to follow', () async {
        stubNotifications([
          makeNotification(notificationType: 'contact', sourceKind: 3),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.first as SingleNotification;
        expect(item.type, equals(NotificationKind.follow));
      });

      test('zap maps to like', () async {
        stubNotifications([
          makeNotification(notificationType: 'zap', sourceKind: 9735),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.first as SingleNotification;
        expect(item.type, equals(NotificationKind.like));
      });

      test('sourceKind 7 with unknown type maps to like', () async {
        stubNotifications([
          makeNotification(notificationType: 'unknown'),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.first as SingleNotification;
        expect(item.type, equals(NotificationKind.like));
      });

      test('sourceKind 6 with unknown type maps to repost', () async {
        stubNotifications([
          makeNotification(notificationType: 'unknown', sourceKind: 6),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.first as SingleNotification;
        expect(item.type, equals(NotificationKind.repost));
      });

      test('sourceKind 3 with unknown type maps to follow', () async {
        stubNotifications([
          makeNotification(notificationType: 'unknown', sourceKind: 3),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.first as SingleNotification;
        expect(item.type, equals(NotificationKind.follow));
      });

      test('sourceKind 1 with unknown type maps to comment', () async {
        stubNotifications([
          makeNotification(notificationType: 'unknown', sourceKind: 1),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.first as SingleNotification;
        expect(item.type, equals(NotificationKind.comment));
      });

      test('completely unknown type and kind maps to system', () async {
        stubNotifications([
          makeNotification(notificationType: 'unknown', sourceKind: 9999),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.first as SingleNotification;
        expect(item.type, equals(NotificationKind.system));
      });
    });

    group('comment text truncation', () {
      test('truncates comment text > 50 chars', () async {
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
        final item = page.items.first as SingleNotification;
        expect(item.commentText, equals('${'A' * 50}...'));
      });

      test('keeps short comment text unchanged', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'comment',
            sourceKind: 1,
            content: 'Short comment',
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.first as SingleNotification;
        expect(item.commentText, equals('Short comment'));
      });

      test('does not set commentText for non-comment types', () async {
        stubNotifications([
          makeNotification(
            content: '+',
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.first as SingleNotification;
        expect(item.commentText, isNull);
      });
    });

    group('refresh', () {
      test('resets cursor and fetches from beginning', () async {
        // First fetch sets a cursor.
        stubNotifications([], nextCursor: 'cursor_1');
        stubProfiles({});
        await repository.getNotifications();

        // Refresh should clear cursor.
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
        ).called(2); // Initial call + refresh call both use null cursor.
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
    });

    group('markAllAsRead', () {
      test('calls API and DAO', () async {
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
            createdAt: DateTime(2025),
            content: 'Old',
          ),
          makeNotification(
            id: 'new',
            sourcePubkey: 'pub_b',
            notificationType: 'comment',
            sourceKind: 1,
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
        expect((page.items[0] as SingleNotification).id, equals('new'));
        expect((page.items[1] as SingleNotification).id, equals('old'));
      });
    });

    group('block filter', () {
      const blockedPubkey = 'blocked_pubkey_abc';

      late NotificationRepository filteredRepository;

      setUp(() {
        filteredRepository = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
          nostrClient: nostrClient,
          blockFilter: (pubkey) => pubkey == blockedPubkey,
        );
      });

      test(
        'filters single notification from blocked user',
        () async {
          stubNotifications([
            makeNotification(
              id: 'n_blocked',
              sourcePubkey: blockedPubkey,
              referencedEventId: 'video1',
            ),
            makeNotification(
              id: 'n_allowed',
              sourcePubkey: 'pub_allowed',
              referencedEventId: 'video2',
            ),
          ]);
          stubProfiles({
            blockedPubkey: makeProfile(
              blockedPubkey,
              displayName: 'Blocked',
            ),
            'pub_allowed': makeProfile(
              'pub_allowed',
              displayName: 'Allowed',
            ),
          });

          final page = await filteredRepository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.first as SingleNotification;
          expect(item.actor.pubkey, equals('pub_allowed'));
        },
      );

      test(
        'strips blocked actors from grouped notification',
        () async {
          // 3 likes on the same video — will be grouped.
          stubNotifications([
            makeNotification(
              id: 'l1',
              sourcePubkey: 'pub_a',
              referencedEventId: 'video_x',
              createdAt: DateTime(2025, 1, 3),
            ),
            makeNotification(
              id: 'l2',
              sourcePubkey: blockedPubkey,
              referencedEventId: 'video_x',
              createdAt: DateTime(2025, 1, 2),
            ),
            makeNotification(
              id: 'l3',
              sourcePubkey: 'pub_c',
              referencedEventId: 'video_x',
              createdAt: DateTime(2025),
            ),
          ]);
          stubProfiles({
            'pub_a': makeProfile('pub_a', displayName: 'Alice'),
            blockedPubkey: makeProfile(
              blockedPubkey,
              displayName: 'Blocked',
            ),
            'pub_c': makeProfile('pub_c', displayName: 'Charlie'),
          });

          final page = await filteredRepository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.first as GroupedNotification;
          expect(item.actors, hasLength(2));
          expect(item.totalCount, equals(2));
          expect(
            item.actors.map((a) => a.pubkey),
            isNot(contains(blockedPubkey)),
          );
        },
      );

      test(
        'removes grouped notification when all actors blocked',
        () async {
          // 3 likes on the same video — all from blocked pubkey.
          stubNotifications([
            makeNotification(
              id: 'l1',
              sourcePubkey: blockedPubkey,
              referencedEventId: 'video_x',
              createdAt: DateTime(2025, 1, 3),
            ),
            makeNotification(
              id: 'l2',
              sourcePubkey: blockedPubkey,
              referencedEventId: 'video_x',
              createdAt: DateTime(2025, 1, 2),
            ),
            makeNotification(
              id: 'l3',
              sourcePubkey: blockedPubkey,
              referencedEventId: 'video_x',
              createdAt: DateTime(2025),
            ),
          ]);
          stubProfiles({
            blockedPubkey: makeProfile(
              blockedPubkey,
              displayName: 'Blocked',
            ),
          });

          final page = await filteredRepository.getNotifications();

          expect(page.items, isEmpty);
        },
      );

      test(
        'filterRealtimeNotification returns null for blocked single '
        'notification',
        () {
          final item = SingleNotification(
            id: 'rt1',
            type: NotificationKind.like,
            actor: const ActorInfo(
              pubkey: blockedPubkey,
              displayName: 'Blocked',
            ),
            timestamp: DateTime(2025),
          );

          final result = filteredRepository.filterRealtimeNotification(item);

          expect(result, isNull);
        },
      );

      test(
        'filterRealtimeNotification returns notification for '
        'non-blocked user',
        () {
          final item = SingleNotification(
            id: 'rt2',
            type: NotificationKind.follow,
            actor: const ActorInfo(
              pubkey: 'pub_allowed',
              displayName: 'Allowed',
            ),
            timestamp: DateTime(2025),
          );

          final result = filteredRepository.filterRealtimeNotification(item);

          expect(result, isNotNull);
          expect(
            (result! as SingleNotification).actor.pubkey,
            equals('pub_allowed'),
          );
        },
      );
    });
  });
}
