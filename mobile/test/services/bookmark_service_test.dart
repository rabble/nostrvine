// ABOUTME: Tests BookmarkService's NIP-51 kind 10003 read-modify-write contract
// ABOUTME: Pins that an unreconciled publish can never truncate the relay list

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(<Filter>[]);
  });

  group(BookmarkService, () {
    late _MockNostrClient nostrClient;
    late _MockAuthService authService;
    late SharedPreferences prefs;
    late String pubkey;

    /// The tags of the last kind-10003 handed to the signer.
    List<List<String>>? signedTags;
    String? signedContent;

    Event bookmarkListEvent(List<String> eventIds, {String content = ''}) {
      return Event(
        pubkey,
        10003,
        [
          for (final id in eventIds) ['e', id],
        ],
        content,
      );
    }

    /// Makes the relay answer a kind-10003 query with [events].
    void stubRelay({
      required List<Event> events,
      bool timedOut = false,
      bool noRelays = false,
    }) {
      when(
        () => nostrClient.queryEventsDetailed(any()),
      ).thenAnswer(
        (_) async => (events: events, timedOut: timedOut, noRelays: noRelays),
      );
    }

    BookmarkService createService() => BookmarkService(
      nostrService: nostrClient,
      authService: authService,
      prefs: prefs,
    );

    setUp(() async {
      pubkey = getPublicKey(generatePrivateKey());
      nostrClient = _MockNostrClient();
      authService = _MockAuthService();
      signedTags = null;
      signedContent = null;

      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);

      // Capture what the service asks to sign, and hand back a real event.
      when(
        () => authService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        signedTags =
            invocation.namedArguments[#tags] as List<List<String>>? ?? [];
        signedContent = invocation.namedArguments[#content] as String?;
        return Event(
          pubkey,
          invocation.namedArguments[#kind] as int,
          signedTags!,
          signedContent!,
        );
      });

      when(() => nostrClient.publishEvent(any())).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );
    });

    List<String> signedEventIds() => (signedTags ?? [])
        .where((tag) => tag.isNotEmpty && tag[0] == 'e')
        .map((tag) => tag[1])
        .toList();

    group('syncGlobalBookmarks', () {
      test('adopts the relay list when the local cache is empty', () async {
        stubRelay(
          events: [
            bookmarkListEvent(['video-a', 'video-b']),
          ],
        );
        final service = createService();

        final synced = await service.syncGlobalBookmarks();

        expect(synced, isTrue);
        expect(
          service.globalBookmarks.map((item) => item.id),
          equals(['video-a', 'video-b']),
        );
      });

      test('keeps the newest event when the relay returns several', () async {
        final older = Event(
          pubkey,
          10003,
          [
            ['e', 'stale'],
          ],
          '',
          createdAt: 1000,
        );
        final newer = Event(
          pubkey,
          10003,
          [
            ['e', 'fresh'],
          ],
          '',
          createdAt: 2000,
        );
        stubRelay(events: [older, newer]);
        final service = createService();

        await service.syncGlobalBookmarks();

        expect(
          service.globalBookmarks.map((item) => item.id),
          equals(['fresh']),
        );
      });

      test(
        'reports failure and keeps the cache when the query times out',
        () async {
          SharedPreferences.setMockInitialValues({
            BookmarkService.globalBookmarksStorageKey: jsonEncode([
              {'type': 'e', 'id': 'cached', 'relay': null, 'petname': null},
            ]),
          });
          prefs = await SharedPreferences.getInstance();
          stubRelay(events: [], timedOut: true);
          final service = createService();

          final synced = await service.syncGlobalBookmarks();

          expect(synced, isFalse);
          expect(
            service.globalBookmarks.map((item) => item.id),
            equals(['cached']),
            reason: 'a timeout must not be read as an empty list',
          );
        },
      );

      test('reports failure when no relay was reachable', () async {
        stubRelay(events: [], noRelays: true);
        final service = createService();

        expect(await service.syncGlobalBookmarks(), isFalse);
      });

      test('accepts an empty answer from a relay that did reply', () async {
        stubRelay(events: []);
        final service = createService();

        expect(await service.syncGlobalBookmarks(), isTrue);
        expect(service.globalBookmarks, isEmpty);
      });

      test('reports failure when signed out, without throwing', () async {
        when(() => authService.isAuthenticated).thenReturn(false);
        when(() => authService.currentPublicKeyHex).thenReturn(null);
        final service = createService();

        expect(await service.syncGlobalBookmarks(), isFalse);
        verifyNever(
          () => nostrClient.queryEventsDetailed(any()),
        );
      });

      test('asks the relay only for kind 10003 by this author', () async {
        stubRelay(events: []);
        final service = createService();

        await service.syncGlobalBookmarks();

        final filters =
            verify(
                  () => nostrClient.queryEventsDetailed(captureAny()),
                ).captured.single
                as List<Filter>;
        expect(filters, hasLength(1));
        expect(filters.single.kinds, equals([10003]));
        expect(filters.single.authors, equals([pubkey]));
        expect(
          filters.single.limit,
          equals(1),
          reason: 'an unbounded author query costs O(all events the user made)',
        );
      });
    });

    group('addToGlobalBookmarks', () {
      test('preserves bookmarks this device has never seen', () async {
        // The regression this whole change exists for: relay holds a list,
        // local cache is empty (fresh install), user saves one video.
        stubRelay(
          events: [
            bookmarkListEvent(['relay-a', 'relay-b']),
          ],
        );
        final service = createService();

        final added = await service.addToGlobalBookmarks(
          const BookmarkItem(type: 'e', id: 'new-one'),
        );

        expect(added, isTrue);
        expect(
          signedEventIds(),
          equals(['relay-a', 'relay-b', 'new-one']),
          reason:
              'kind 10003 is replaceable — publishing only the local '
              'item would delete relay-a and relay-b',
        );
      });

      test('does not publish when the relay could not be reached', () async {
        stubRelay(events: [], timedOut: true);
        final service = createService();

        final added = await service.addToGlobalBookmarks(
          const BookmarkItem(type: 'e', id: 'new-one'),
        );

        expect(added, isFalse);
        verifyNever(() => nostrClient.publishEvent(any()));
      });

      test('reports failure when the relay rejects the publish', () async {
        stubRelay(events: []);
        when(
          () => nostrClient.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());
        final service = createService();

        expect(
          await service.addToGlobalBookmarks(
            const BookmarkItem(type: 'e', id: 'new-one'),
          ),
          isFalse,
        );
      });

      test('leaves content empty rather than writing prose into it', () async {
        // NIP-51 reserves `content` for the encrypted private item array.
        stubRelay(events: []);
        final service = createService();

        await service.addToGlobalBookmarks(
          const BookmarkItem(type: 'e', id: 'new-one'),
        );

        expect(signedContent, isEmpty);
      });

      test(
        "carries another client's encrypted content through untouched",
        () async {
          const ciphertext = 'AhjoBRIcKJZSgAGz/y0uYsggKpn6dgeRHYs=';
          stubRelay(
            events: [
              bookmarkListEvent(['relay-a'], content: ciphertext),
            ],
          );
          final service = createService();

          await service.addToGlobalBookmarks(
            const BookmarkItem(type: 'e', id: 'new-one'),
          );

          expect(
            signedContent,
            equals(ciphertext),
            reason:
                'overwriting it would delete the private bookmarks that '
                'Divine cannot yet decrypt',
          );
        },
      );
    });

    group('removeFromGlobalBookmarks', () {
      test('removes only the requested item from the relay list', () async {
        stubRelay(
          events: [
            bookmarkListEvent(['keep-a', 'drop', 'keep-b']),
          ],
        );
        final service = createService();

        final removed = await service.removeFromGlobalBookmarks(
          const BookmarkItem(type: 'e', id: 'drop'),
        );

        expect(removed, isTrue);
        expect(signedEventIds(), equals(['keep-a', 'keep-b']));
      });

      test('does not publish when the relay could not be reached', () async {
        stubRelay(events: [], timedOut: true);
        final service = createService();

        expect(
          await service.removeFromGlobalBookmarks(
            const BookmarkItem(type: 'e', id: 'drop'),
          ),
          isFalse,
        );
        verifyNever(() => nostrClient.publishEvent(any()));
      });
    });

    group('toggleVideoInGlobalBookmarks', () {
      test('removes a video bookmarked on another device', () async {
        // Local cache knows nothing, so a pre-read would have said "add".
        stubRelay(
          events: [
            bookmarkListEvent(['elsewhere']),
          ],
        );
        final service = createService();

        final result = await service.toggleVideoInGlobalBookmarks('elsewhere');

        expect(result.succeeded, isTrue);
        expect(result.wasBookmarked, isTrue);
        expect(result.isBookmarked, isFalse);
        expect(signedEventIds(), isEmpty);
      });

      test(
        'adds a video that is on neither the relay nor the device',
        () async {
          stubRelay(
            events: [
              bookmarkListEvent(['other']),
            ],
          );
          final service = createService();

          final result = await service.toggleVideoInGlobalBookmarks('wanted');

          expect(result.succeeded, isTrue);
          expect(result.wasBookmarked, isFalse);
          expect(result.isBookmarked, isTrue);
          expect(signedEventIds(), equals(['other', 'wanted']));
        },
      );

      test('reports failure and no state change when the sync fails', () async {
        stubRelay(events: [], timedOut: true);
        final service = createService();

        final result = await service.toggleVideoInGlobalBookmarks('wanted');

        expect(result.succeeded, isFalse);
        expect(result.isBookmarked, equals(result.wasBookmarked));
        verifyNever(() => nostrClient.publishEvent(any()));
      });
    });
  });
}
