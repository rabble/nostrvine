// ABOUTME: Tests BookmarkService's NIP-51 kind 10003 read-modify-write contract
// ABOUTME: Pins that an unreconciled publish can never truncate the relay list

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
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

    /// Makes the relay answer a kind-10003 query with [events], in both
    /// reconcile modes.
    void stubRelay({
      required List<Event> events,
      bool timedOut = false,
      bool noRelays = false,
    }) {
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer(
        (_) async => (events: events, timedOut: timedOut, noRelays: noRelays),
      );
    }

    /// Answers only the reconcile that did (or did not) demand full
    /// settlement, so a test can make the two modes disagree — which is the
    /// only way the write path's choice is observable.
    void stubRelayForSettlementMode({
      required bool fullSettlement,
      required List<Event> events,
      bool timedOut = false,
      bool noRelays = false,
    }) {
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
          requireAllRelaysSettled: fullSettlement,
        ),
      ).thenAnswer(
        (_) async => (events: events, timedOut: timedOut, noRelays: noRelays),
      );
    }

    /// Puts [eventIds] in the SharedPreferences snapshot a service reads at
    /// construction — the state a device has before it reconciles.
    Future<void> seedCachedBookmarks(List<String> eventIds) async {
      SharedPreferences.setMockInitialValues({
        BookmarkService.globalBookmarksStorageKey: jsonEncode([
          for (final id in eventIds)
            {'type': 'e', 'id': id, 'relay': null, 'petname': null},
        ]),
      });
      prefs = await SharedPreferences.getInstance();
    }

    /// Makes every relay refuse the kind-10003 publish.
    void stubPublishRejected() {
      when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer(
        (invocation) async => PublishOutcome(
          eventId: (invocation.positionalArguments.first as Event).id,
          acceptedBy: const [],
          rejectedBy: const {'wss://relay.example': 'blocked: policy'},
          noResponseFrom: const [],
        ),
      );
    }

    BookmarkService createService({DateTime Function()? now}) =>
        BookmarkService(
          nostrService: nostrClient,
          authService: authService,
          prefs: prefs,
          now: now ?? DateTime.now,
        );

    /// The `requireAllRelaysSettled` argument of every reconcile query so far,
    /// in call order.
    List<dynamic> capturedSettlementDemands() => verify(
      () => nostrClient.queryEventsDetailed(
        any(),
        useCache: any(named: 'useCache'),
        requireAllRelaysSettled: captureAny(named: 'requireAllRelaysSettled'),
      ),
    ).captured;

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

      when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer(
        (invocation) async => PublishOutcome(
          eventId: (invocation.positionalArguments.first as Event).id,
          acceptedBy: const ['wss://relay.example'],
          rejectedBy: const {},
          noResponseFrom: const [],
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

      test(
        'confirms an empty answer against every relay before dropping a '
        'cached list',
        () async {
          await seedCachedBookmarks(['cached']);
          // The fast read finds nothing because a relay stayed mute; the
          // relay that holds the list answers once the query waits for it.
          stubRelayForSettlementMode(fullSettlement: false, events: []);
          stubRelayForSettlementMode(
            fullSettlement: true,
            events: [
              bookmarkListEvent(['cached', 'from-another-device']),
            ],
          );
          final service = createService();

          expect(await service.syncGlobalBookmarks(), isTrue);
          expect(
            service.globalBookmarks.map((item) => item.id),
            equals(['cached', 'from-another-device']),
          );
        },
      );

      test(
        'keeps the cached list when the confirming query cannot settle',
        () async {
          await seedCachedBookmarks(['cached']);
          // Some relay says there is nothing, and the query that would confirm
          // it never settles. Acting on the first answer would drop the list —
          // from memory and from the snapshot Saved falls back to offline.
          stubRelayForSettlementMode(fullSettlement: false, events: []);
          stubRelayForSettlementMode(
            fullSettlement: true,
            events: [],
            timedOut: true,
          );
          final service = createService();

          expect(await service.syncGlobalBookmarks(), isFalse);
          expect(
            service.globalBookmarks.map((item) => item.id),
            equals(['cached']),
            reason: 'an unconfirmed empty answer is not an empty list',
          );
          expect(
            jsonDecode(
              prefs.getString(BookmarkService.globalBookmarksStorageKey)!,
            ),
            hasLength(1),
            reason: 'and it must not overwrite the offline snapshot either',
          );
        },
      );

      test(
        'confirms an empty answer on a fresh install, where there is no cache '
        'to protect',
        () async {
          // The filed bug: a reinstall has an empty cache, so gating the
          // confirmation on having something to lose would leave Saved
          // showing "Nothing saved yet" for a user who has bookmarks.
          stubRelayForSettlementMode(fullSettlement: false, events: []);
          stubRelayForSettlementMode(
            fullSettlement: true,
            events: [
              bookmarkListEvent(['from-before-the-reinstall']),
            ],
          );
          final service = createService();

          expect(await service.syncGlobalBookmarks(), isTrue);
          expect(
            service.globalBookmarks.map((item) => item.id),
            equals(['from-before-the-reinstall']),
          );
        },
      );

      test(
        'does not let a cached event stand in for an authoritative read',
        () async {
          stubRelay(events: []);
          final service = createService();

          await service.syncGlobalBookmarks(requireAuthoritative: true);

          verify(
            () => nostrClient.queryEventsDetailed(
              any(),
              useCache: false,
              requireAllRelaysSettled: true,
            ),
          ).called(1);
        },
      );

      test('clears the cache once every relay confirms it is empty', () async {
        await seedCachedBookmarks(['removed-elsewhere']);
        stubRelay(events: []);
        final service = createService();

        expect(await service.syncGlobalBookmarks(), isTrue);
        expect(
          service.globalBookmarks,
          isEmpty,
          reason: 'a bookmark cleared on another device must disappear here',
        );
      });

      test('keeps the fast trade when the relay returns a list', () async {
        // Opening Saved only renders what it finds, so the read keeps the
        // settle window's latency trade. Only a *no list at all* answer is
        // ever confirmed, because that is the one this cannot afford to be
        // wrong about.
        stubRelay(
          events: [
            bookmarkListEvent(['video-a']),
          ],
        );
        final service = createService();

        await service.syncGlobalBookmarks();

        final demandedSettlement = verify(
          () => nostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: captureAny(
              named: 'requireAllRelaysSettled',
            ),
          ),
        ).captured.single;
        expect(demandedSettlement, isFalse);
      });

      test(
        'reuses a fresh absence confirmation instead of re-paying for it',
        () async {
          // A user who genuinely has no bookmarks must not pay a
          // full-settlement wait every time Saved opens.
          stubRelay(events: []);
          final service = createService();

          await service.syncGlobalBookmarks();
          await service.syncGlobalBookmarks();

          expect(
            capturedSettlementDemands(),
            equals([false, true, false]),
            reason: 'the second read reuses the confirmation from the first',
          );
        },
      );

      test(
        'stops trusting a confirmed absence once the list turns up',
        () async {
          // A list whose items are all private carries no public tags, so it
          // leaves the bookmark list empty while holding another client's
          // ciphertext. A stamp from before it existed must not let a later
          // partial empty answer through unconfirmed and wipe that content.
          var clock = DateTime(2026);
          final service = createService(now: () => clock);

          stubRelay(events: []);
          await service.syncGlobalBookmarks();

          clock = clock.add(const Duration(minutes: 1));
          stubRelay(events: [bookmarkListEvent([], content: 'ciphertext')]);
          await service.syncGlobalBookmarks();

          clock = clock.add(const Duration(minutes: 1));
          stubRelayForSettlementMode(fullSettlement: false, events: []);
          stubRelayForSettlementMode(
            fullSettlement: true,
            events: [],
            timedOut: true,
          );
          expect(await service.syncGlobalBookmarks(), isFalse);

          // The unconfirmed empty must not have reached the content, so a
          // publish still carries the other client's private items.
          stubRelay(events: [bookmarkListEvent([], content: 'ciphertext')]);
          await service.addToGlobalBookmarks(
            const BookmarkItem(type: 'e', id: 'mine'),
          );
          expect(
            signedContent,
            equals('ciphertext'),
            reason: 'a stale absence must not strip private bookmarks',
          );
        },
      );

      test(
        'does not let unconfirmed reads slide the confirmation window',
        () async {
          // Each skipped read must leave the deadline where the confirmation
          // put it. Renewing it here would restore the permanent latch for
          // any session that opens Saved more often than the TTL.
          stubRelay(events: []);
          var clock = DateTime(2026);
          final service = createService(now: () => clock);

          await service.syncGlobalBookmarks();
          clock = clock.add(const Duration(minutes: 4));
          await service.syncGlobalBookmarks();
          clock = clock.add(const Duration(minutes: 4));
          await service.syncGlobalBookmarks();

          expect(
            capturedSettlementDemands(),
            equals([false, true, false, false, true]),
            reason:
                'the third read is past the original deadline, so it '
                're-confirms even though the second read was recent',
          );
        },
      );

      test(
        'confirms absence again once the last confirmation ages out',
        () async {
          // Latching the absence for the life of the service would hide a list
          // created on another device for as long as a relay stays mute.
          stubRelay(events: []);
          var clock = DateTime(2026);
          final service = createService(now: () => clock);

          await service.syncGlobalBookmarks();
          clock = clock.add(
            BookmarkService.absenceConfirmationTtl + const Duration(seconds: 1),
          );
          await service.syncGlobalBookmarks();

          expect(
            capturedSettlementDemands(),
            equals([false, true, false, true]),
            reason: 'a stale absence is re-confirmed, not believed',
          );
        },
      );

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
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test('reports failure when the relay rejects the publish', () async {
        stubRelay(events: []);
        stubPublishRejected();
        final service = createService();

        expect(
          await service.addToGlobalBookmarks(
            const BookmarkItem(type: 'e', id: 'new-one'),
          ),
          isFalse,
        );
      });

      test('reports failure when no relay answered the publish', () async {
        // `OK` never arrived. The frame left the socket, which is all
        // publishEvent would have proved, so gating on that would have told
        // the user their bookmark was saved.
        stubRelay(events: []);
        when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async => PublishOutcome(
            eventId: (invocation.positionalArguments.first as Event).id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const ['wss://relay.example'],
          ),
        );
        final service = createService();

        expect(
          await service.addToGlobalBookmarks(
            const BookmarkItem(type: 'e', id: 'new-one'),
          ),
          isFalse,
        );
      });

      test('waits for a relay OK rather than a socket handoff', () async {
        stubRelay(events: []);
        final service = createService();

        await service.addToGlobalBookmarks(
          const BookmarkItem(type: 'e', id: 'new-one'),
        );

        verify(() => nostrClient.publishEventAwaitOk(any())).called(1);
        verifyNever(() => nostrClient.publishEvent(any()));
      });

      test('reconciles with full settlement before publishing', () async {
        stubRelay(
          events: [
            bookmarkListEvent(['relay-a']),
          ],
        );
        final service = createService();

        await service.addToGlobalBookmarks(
          const BookmarkItem(type: 'e', id: 'new-one'),
        );

        verify(
          () => nostrClient.queryEventsDetailed(
            any(),
            useCache: false,
            requireAllRelaysSettled: true,
          ),
        ).called(1);
      });

      test(
        'refuses when a relay never settled, even though another answered '
        'empty',
        () async {
          // The destructive shape this whole change exists to close: the
          // settle window releases the query one second after a fast relay
          // EOSEs with nothing, while the relay actually holding the list is
          // still silent. That answer arrives as timedOut: false, and
          // republishing on it replaces the real list with a one-item one.
          stubRelayForSettlementMode(fullSettlement: false, events: []);
          stubRelayForSettlementMode(
            fullSettlement: true,
            events: [],
            timedOut: true,
          );
          final service = createService();

          final added = await service.addToGlobalBookmarks(
            const BookmarkItem(type: 'e', id: 'new-one'),
          );

          expect(added, isFalse);
          verifyNever(() => nostrClient.publishEventAwaitOk(any()));
        },
      );

      test('leaves no phantom bookmark when the publish is refused', () async {
        stubRelay(
          events: [
            bookmarkListEvent(['relay-a']),
          ],
        );
        stubPublishRejected();
        final service = createService();

        final added = await service.addToGlobalBookmarks(
          const BookmarkItem(type: 'e', id: 'new-one'),
        );

        expect(added, isFalse);
        expect(
          service.globalBookmarks.map((item) => item.id),
          equals(['relay-a']),
          reason:
              'the item reached no relay, so the device must not show it as '
              'saved until some later sync happens to wipe it',
        );
        expect(
          prefs.getString(BookmarkService.globalBookmarksStorageKey) ?? '',
          isNot(contains('new-one')),
          reason: 'an unconfirmed item must not survive a restart either',
        );
      });

      test('persists the new list once a relay accepts it', () async {
        stubRelay(
          events: [
            bookmarkListEvent(['relay-a']),
          ],
        );
        final service = createService();

        final added = await service.addToGlobalBookmarks(
          const BookmarkItem(type: 'e', id: 'new-one'),
        );

        expect(added, isTrue);
        expect(
          service.globalBookmarks.map((item) => item.id),
          equals(['relay-a', 'new-one']),
        );
        expect(
          prefs.getString(BookmarkService.globalBookmarksStorageKey) ?? '',
          contains('new-one'),
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
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test('keeps the item when the removal is refused', () async {
        stubRelay(
          events: [
            bookmarkListEvent(['keep', 'drop']),
          ],
        );
        stubPublishRejected();
        final service = createService();

        final removed = await service.removeFromGlobalBookmarks(
          const BookmarkItem(type: 'e', id: 'drop'),
        );

        expect(removed, isFalse);
        expect(
          service.globalBookmarks.map((item) => item.id),
          equals(['keep', 'drop']),
          reason:
              'the relay still holds drop, so hiding it locally would make '
              'the device disagree with the list it just failed to change',
        );
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
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });
    });
  });
}
