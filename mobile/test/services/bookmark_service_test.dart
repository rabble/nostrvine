// ABOUTME: Tests BookmarkService's NIP-51 kind 10003 read-modify-write contract
// ABOUTME: Pins that an unreconciled publish can never truncate the relay list

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip04/nip04.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/utils/nostr_timestamp.dart';
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

    /// A real local identity, so NIP-44 in these tests is the actual crypto
    /// rather than a stub. `NostrIdentity` is sealed and cannot be mocked, and
    /// using the real signer is what makes the private-item fixtures genuine
    /// NIP-51 payloads.
    late LocalNostrIdentity identity;

    /// The tags of the last kind-10003 handed to the signer.
    List<List<String>>? signedTags;
    String? signedContent;
    int? signedCreatedAt;

    Event bookmarkListEvent(
      List<String> eventIds, {
      String content = '',
      int? createdAt,
    }) {
      return Event(
        pubkey,
        10003,
        [
          for (final id in eventIds) ['e', id],
        ],
        content,
        createdAt: createdAt,
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

    /// A genuine NIP-51 private payload: a stringified tag array, NIP-44
    /// encrypted to the author's own key.
    Future<String> encryptToSelf(List<List<String>> items) async {
      final ciphertext = await identity.nip44Encrypt(pubkey, jsonEncode(items));
      return ciphertext!;
    }

    /// The same payload under the scheme NIP-51 deprecated but still tells
    /// clients to read. Genuine ciphertext, not a `?iv=`-shaped literal: only
    /// a real one exercises the decrypt branch rather than the failure path.
    Future<String> encryptToSelfNip04(List<List<String>> items) async {
      final ciphertext = await identity.encrypt(pubkey, jsonEncode(items));
      return ciphertext!;
    }

    Future<List<List<String>>> decryptToSelf(String ciphertext) async {
      final plaintext = await identity.nip44Decrypt(pubkey, ciphertext);
      return [
        for (final entry in jsonDecode(plaintext!) as List)
          [for (final value in entry as List) value as String],
      ];
    }

    setUp(() async {
      final privateKeyHex = generatePrivateKey();
      pubkey = getPublicKey(privateKeyHex);
      identity = LocalNostrIdentity(
        keyContainer: SecureKeyContainer.fromPrivateKeyHex(privateKeyHex),
      );
      nostrClient = _MockNostrClient();
      authService = _MockAuthService();
      signedTags = null;
      signedContent = null;
      signedCreatedAt = null;

      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
      when(() => authService.currentIdentity).thenReturn(identity);

      // Capture what the service asks to sign, and hand back a real event.
      when(
        () => authService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) async {
        signedTags =
            invocation.namedArguments[#tags] as List<List<String>>? ?? [];
        signedContent = invocation.namedArguments[#content] as String?;
        signedCreatedAt = invocation.namedArguments[#createdAt] as int?;
        return Event(
          pubkey,
          invocation.namedArguments[#kind] as int,
          signedTags!,
          signedContent!,
          createdAt: signedCreatedAt,
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
          final ciphertext = await encryptToSelf([
            ['e', 'their-private-one'],
          ]);
          var clock = DateTime(2026);
          // Contemporaneous with the injected clock: left at the SDK's
          // real-wall-clock default the event sits months ahead of it, a skew
          // no relay would serve and one the publish path now declines (#7629).
          final theirRevisionAt = clock.millisecondsSinceEpoch ~/ 1000;
          final service = createService(now: () => clock);

          stubRelay(events: []);
          await service.syncGlobalBookmarks();

          clock = clock.add(const Duration(minutes: 1));
          stubRelay(
            events: [
              bookmarkListEvent(
                [],
                content: ciphertext,
                createdAt: theirRevisionAt,
              ),
            ],
          );
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
          stubRelay(
            events: [
              bookmarkListEvent(
                [],
                content: ciphertext,
                createdAt: theirRevisionAt,
              ),
            ],
          );
          await service.addToGlobalBookmarks(
            const BookmarkItem(type: 'e', id: 'mine'),
          );
          expect(
            signedContent,
            equals(ciphertext),
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

      test(
        'does not start a window on a confirmation that could not settle',
        () async {
          // The window is keyed on a *confirmed* absence, not on having
          // tried. A confirmation that times out establishes nothing, so
          // suppressing the next one would leave the reinstall case resting
          // on an empty answer nobody stood behind — #6627 all over again.
          stubRelayForSettlementMode(fullSettlement: false, events: []);
          stubRelayForSettlementMode(
            fullSettlement: true,
            events: [],
            timedOut: true,
          );
          var clock = DateTime(2026);
          final service = createService(now: () => clock);

          expect(await service.syncGlobalBookmarks(), isFalse);
          clock = clock.add(const Duration(minutes: 1));
          expect(await service.syncGlobalBookmarks(), isFalse);

          expect(
            capturedSettlementDemands(),
            equals([false, true, false, true]),
            reason: 'well inside the TTL, but nothing was ever confirmed',
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
        'drops the legacy Divine prose instead of republishing it',
        () async {
          // The kind 10003 every user who saved a bookmark on an older build
          // carries: the pre-reconcile code wrote this literal into `content`,
          // where NIP-51 reserves the NIP-44 private-item array. Read verbatim
          // off relay.divine.video from a live account.
          stubRelay(
            events: [bookmarkListEvent([], content: 'Divine global bookmarks')],
          );
          final service = createService();

          await service.addToGlobalBookmarks(
            const BookmarkItem(type: 'e', id: 'new-one'),
          );

          expect(
            signedContent,
            isEmpty,
            reason:
                "the carry-through protects another client's ciphertext, but "
                "this literal is Divine's own former output and is not "
                'ciphertext — preserving it republishes the malformed content '
                'forever for exactly the users who already have it',
          );
        },
      );

      test(
        "carries another client's encrypted content through untouched",
        () async {
          final ciphertext = await encryptToSelf([
            ['e', 'their-private-one'],
          ]);
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
                'a public-item write must re-emit the payload byte-for-byte '
                'rather than re-encrypting it',
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

      test('drops every public copy of a duplicated tag', () async {
        // Nothing stops another client from writing the same `e` tag twice.
        // `List.remove` drops only the first, so the republished list would
        // still carry the video while the sheet reports "Removed" — the same
        // lie the private path already uses `removeWhere` to avoid.
        stubRelay(
          events: [
            bookmarkListEvent(['keep', 'drop', 'drop']),
          ],
        );
        final service = createService();

        final removed = await service.removeFromGlobalBookmarks(
          const BookmarkItem(type: 'e', id: 'drop'),
        );

        expect(removed, isTrue);
        expect(signedEventIds(), equals(['keep']));
        expect(
          service.isVideoBookmarkedGlobally('drop'),
          isFalse,
          reason: 'a surviving duplicate makes the reported removal a lie',
        );
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

      test(
        'reports couldNotReachRelays, not timedOut, when the device is '
        'offline and the query sets both flags',
        () async {
          // An offline device reports noRelays *and* timedOut. Testing
          // timedOut first would route offline to the wrong message, so the
          // precedence is pinned here.
          stubRelay(events: [], timedOut: true, noRelays: true);
          final service = createService();

          final result = await service.toggleVideoInGlobalBookmarks('wanted');

          expect(
            result.failure,
            equals(BookmarkToggleFailure.couldNotReachRelays),
          );
          verifyNever(() => nostrClient.publishEventAwaitOk(any()));
        },
      );

      test('reports timedOut when relays were reachable but silent', () async {
        stubRelay(events: [], timedOut: true);
        final service = createService();

        final result = await service.toggleVideoInGlobalBookmarks('wanted');

        expect(result.failure, equals(BookmarkToggleFailure.timedOut));
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test(
        'reports publishDidNotComplete when the publish is rejected',
        () async {
          stubRelay(events: []);
          stubPublishRejected();
          final service = createService();

          final result = await service.toggleVideoInGlobalBookmarks('wanted');

          expect(result.succeeded, isFalse);
          expect(
            result.failure,
            equals(BookmarkToggleFailure.publishDidNotComplete),
          );
        },
      );

      test('carries no failure reason when the toggle succeeds', () async {
        stubRelay(events: []);
        final service = createService();

        final result = await service.toggleVideoInGlobalBookmarks('wanted');

        expect(result.succeeded, isTrue);
        expect(result.failure, isNull);
      });
    });

    group('concurrent syncs and publishes', () {
      /// A revision published a minute ago — what a relay still answers with
      /// while a newer one from this device has not replaced it yet.
      Event supersededRevision(List<String> eventIds) => bookmarkListEvent(
        eventIds,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60,
      );

      test('a stale relay answer cannot undo a completed save', () async {
        stubRelay(
          events: [
            supersededRevision(['video-a']),
          ],
        );
        final service = createService();

        final toggle = await service.toggleVideoInGlobalBookmarks('video-b');
        expect(toggle.succeeded, isTrue);
        expect(signedEventIds(), ['video-a', 'video-b']);

        // The relay still answers with the revision the save replaced: `OK`
        // means the new one is queued for storage, not that it is stored. This
        // is the share sheet's display read landing after the toggle.
        await service.syncGlobalBookmarks();

        expect(service.globalBookmarks.map((item) => item.id), [
          'video-a',
          'video-b',
        ]);
        expect(
          jsonDecode(
            prefs.getString(BookmarkService.globalBookmarksStorageKey)!,
          ),
          [
            {'type': 'e', 'id': 'video-a', 'relay': null, 'petname': null},
            {'type': 'e', 'id': 'video-b', 'relay': null, 'petname': null},
          ],
        );
      });

      test(
        'a service built after the save still refuses the revision it '
        'replaced',
        () async {
          // The writing surface builds a fresh BookmarkService per sheet
          // (#7596), so an in-memory-only watermark is blank again by the
          // next save. That makes the ordinary save / close / save loop
          // reproduce #7163 with no concurrency involved at all.
          stubRelay(
            events: [
              supersededRevision(['video-a']),
            ],
          );

          final firstSheet = createService();
          expect(
            (await firstSheet.toggleVideoInGlobalBookmarks(
              'video-b',
            )).succeeded,
            isTrue,
          );
          expect(signedEventIds(), ['video-a', 'video-b']);

          // The sheet closes and that instance is dropped. The relay still
          // answers with the revision the save replaced, because `OK` means
          // queued for storage, not readable back.
          final secondSheet = createService();
          expect(
            (await secondSheet.toggleVideoInGlobalBookmarks(
              'video-c',
            )).succeeded,
            isTrue,
          );

          expect(
            signedEventIds(),
            ['video-a', 'video-b', 'video-c'],
            reason: 'the second sheet must not publish over video-b',
          );
        },
      );

      test(
        'a display read issued before a save cannot land after it',
        () async {
          final staleRead = supersededRevision(['video-a']);
          var relayHeld = staleRead;
          final releaseRead = Completer<void>();
          var queries = 0;

          when(
            () => nostrClient.queryEventsDetailed(
              any(),
              useCache: any(named: 'useCache'),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer((_) async {
            if (++queries == 1) {
              await releaseRead.future;
              return (events: [staleRead], timedOut: false, noRelays: false);
            }
            return (events: [relayHeld], timedOut: false, noRelays: false);
          });
          when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
            invocation,
          ) async {
            final event = invocation.positionalArguments.first as Event;
            relayHeld = event;
            if (!releaseRead.isCompleted) releaseRead.complete();
            return PublishOutcome(
              eventId: event.id,
              acceptedBy: const ['wss://relay.example'],
              rejectedBy: const {},
              noResponseFrom: const [],
            );
          });

          final service = createService();
          final read = service.syncGlobalBookmarks();
          final save = service.toggleVideoInGlobalBookmarks('video-b');

          await Future<void>.delayed(Duration.zero);
          if (queries == 1 && !releaseRead.isCompleted) releaseRead.complete();
          await Future.wait([read, save]);

          expect(service.globalBookmarks.map((item) => item.id), [
            'video-a',
            'video-b',
          ]);
        },
      );

      test('an empty relay answer cannot undo a recent first save', () async {
        final clock = DateTime(2026);
        stubRelay(events: []);
        final service = createService(now: () => clock);

        final first = await service.toggleVideoInGlobalBookmarks('video-b');
        expect(first.succeeded, isTrue);

        final second = await service.toggleVideoInGlobalBookmarks('video-c');
        expect(second.succeeded, isTrue);
        expect(signedEventIds(), ['video-b', 'video-c']);
        expect(service.globalBookmarks.map((item) => item.id), [
          'video-b',
          'video-c',
        ]);
      });

      test(
        'a confirmed absence clears after the local publish grace expires',
        () async {
          var clock = DateTime(2026);
          stubRelay(events: []);
          final service = createService(now: () => clock);

          final result = await service.toggleVideoInGlobalBookmarks('video-b');
          expect(result.succeeded, isTrue);

          clock = clock.add(
            BookmarkService.localPublishAbsenceGracePeriod +
                const Duration(seconds: 1),
          );
          expect(
            await service.syncGlobalBookmarks(requireAuthoritative: true),
            isTrue,
          );

          expect(
            service.globalBookmarks,
            isEmpty,
            reason: 'a real delete elsewhere must not be hidden forever',
          );
        },
      );

      test('overlapping toggles do not publish from the same base', () async {
        var relayHeld = supersededRevision(['video-a']);
        final holdFirstPublish = Completer<void>();
        var publishes = 0;

        when(
          () => nostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (events: [relayHeld], timedOut: false, noRelays: false),
        );
        when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments.first as Event;
          // Acknowledging the first publish only after the second toggle has
          // had its chance to read is what an unserialized pair would see.
          if (++publishes == 1) await holdFirstPublish.future;
          relayHeld = event;
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const ['wss://relay.example'],
            rejectedBy: const {},
            noResponseFrom: const [],
          );
        });

        final service = createService();
        final first = service.toggleVideoInGlobalBookmarks('video-b');
        final second = service.toggleVideoInGlobalBookmarks('video-c');
        // _serialized schedules on a microtask, so completing synchronously
        // here would resolve before the first publish ever awaits it and the
        // hold would gate nothing. Let the queue reach the publish first.
        await pumpEventQueue();
        holdFirstPublish.complete();
        await Future.wait([first, second]);

        final published = verify(
          () => nostrClient.publishEventAwaitOk(captureAny()),
        ).captured.cast<Event>();
        expect(published, hasLength(2));
        expect(
          published.last.tags.map((tag) => tag[1]),
          ['video-a', 'video-b', 'video-c'],
          reason: "the second toggle must build on the first one's result",
        );
      });

      test('keeps the lower id when two revisions share a timestamp', () async {
        final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final one = bookmarkListEvent(['video-a'], createdAt: createdAt);
        final other = bookmarkListEvent(['video-b'], createdAt: createdAt);
        // NIP-01 tells relays to retain the lexically lower id on a tie, so
        // reading the same way keeps this device and the relays agreeing.
        final lower = one.id.compareTo(other.id) < 0 ? one : other;
        final higher = identical(lower, one) ? other : one;
        // The ids are random per run, so the higher one has to go in first: a
        // comparator that returns 0 on the tie leaves the pair in input order,
        // which would otherwise match on about half of runs by luck.
        stubRelay(events: [higher, lower]);
        final service = createService();

        await service.syncGlobalBookmarks();

        expect(service.globalBookmarks.map((item) => item.id), [
          lower.tags.first[1],
        ]);
      });
    });

    group('publish timestamps', () {
      final clock = DateTime.utc(2026);
      final nowSeconds = clock.millisecondsSinceEpoch ~/ 1000;
      final drift = NostrTimestamp.getDriftToleranceForKind(
        BookmarkService.globalBookmarksKind,
      );

      test(
        'backdates for relay clock drift when there is nothing to supersede',
        () async {
          stubRelay(events: []);
          final service = createService(now: () => clock);

          expect(
            (await service.toggleVideoInGlobalBookmarks('video-a')).succeeded,
            isTrue,
          );

          expect(signedCreatedAt, nowSeconds - drift);
        },
      );

      test(
        'steps past a revision a non-backdating client left behind',
        () async {
          // NIP-51 interop: a client that stamps exact wall clock leaves the
          // current revision newer than this device's backdated stamp, and the
          // relay keeps the higher created_at.
          final theirs = bookmarkListEvent(
            ['video-a'],
            createdAt: nowSeconds - 5,
          );
          stubRelay(events: [theirs]);
          final service = createService(now: () => clock);

          expect(
            (await service.toggleVideoInGlobalBookmarks('video-b')).succeeded,
            isTrue,
          );

          expect(
            signedCreatedAt,
            theirs.createdAt + 1,
            reason: 'a backdated stamp would lose the relay merge silently',
          );
        },
      );

      test('steps past a revision that lands exactly on the cap', () async {
        // The boundary is inclusive: this is still a stamp the relay accepts,
        // so it must be used rather than treated as over the line.
        final theirs = bookmarkListEvent(
          ['video-a'],
          createdAt: nowSeconds + BookmarkService.maxPublishFutureSkew - 1,
        );
        stubRelay(events: [theirs]);
        final service = createService(now: () => clock);

        expect(
          (await service.toggleVideoInGlobalBookmarks('video-b')).succeeded,
          isTrue,
        );

        expect(
          signedCreatedAt,
          nowSeconds + BookmarkService.maxPublishFutureSkew,
        );
      });

      test(
        'still publishes, capped, against an implausible revision',
        () async {
          // Milliseconds written as seconds. Refusing here would block every
          // later write on this device until the wall clock caught up — and
          // `_revision` is persisted, so a restart would not clear it. A capped
          // stamp still wins everywhere the bogus revision is absent.
          stubRelay(
            events: [
              bookmarkListEvent(
                ['video-a'],
                createdAt: clock.millisecondsSinceEpoch,
              ),
            ],
          );
          final service = createService(now: () => clock);

          final result = await service.toggleVideoInGlobalBookmarks('video-b');

          expect(result.succeeded, isTrue);
          expect(
            signedCreatedAt,
            nowSeconds + BookmarkService.maxPublishFutureSkew,
          );
        },
      );

      test('stays monotonic across two publishes in the same second', () async {
        stubRelay(events: []);
        final service = createService(now: () => clock);

        expect(
          (await service.toggleVideoInGlobalBookmarks('video-a')).succeeded,
          isTrue,
        );
        final first = signedCreatedAt!;

        expect(
          (await service.toggleVideoInGlobalBookmarks('video-b')).succeeded,
          isTrue,
        );

        expect(
          signedCreatedAt,
          greaterThan(first),
          reason: 'the clock has not moved, so the revision has to carry it',
        );
      });
    });

    group('NIP-51 private items', () {
      const privateVideo = 'privately-bookmarked-video';

      test('reads a list whose items are all private', () async {
        stubRelay(
          events: [
            bookmarkListEvent(
              [],
              content: await encryptToSelf([
                ['e', privateVideo],
              ]),
            ),
          ],
        );
        final service = createService();

        await service.syncGlobalBookmarks();

        expect(
          service.isVideoBookmarkedGlobally(privateVideo),
          isTrue,
          reason: 'a private item is still a bookmark',
        );
        expect(
          service.globalBookmarks.map((item) => item.id),
          contains(privateVideo),
          reason: 'Saved must list it, not render an empty state',
        );
      });

      test('merges public and private items without duplicating', () async {
        stubRelay(
          events: [
            bookmarkListEvent(
              ['public-one', 'in-both'],
              content: await encryptToSelf([
                ['e', privateVideo],
                ['e', 'in-both'],
              ]),
            ),
          ],
        );
        final service = createService();

        await service.syncGlobalBookmarks();

        expect(
          service.globalBookmarks.map((item) => item.id),
          equals(['public-one', 'in-both', privateVideo]),
        );
      });

      test(
        'saving a privately-bookmarked video does not publish a public tag',
        () async {
          final ciphertext = await encryptToSelf([
            ['e', privateVideo],
          ]);
          stubRelay(events: [bookmarkListEvent([], content: ciphertext)]);
          final service = createService();

          final result = await service.toggleVideoInGlobalBookmarks(
            privateVideo,
          );

          expect(
            result.wasBookmarked,
            isTrue,
            reason: 'the private item decides the direction',
          );
          expect(
            signedEventIds(),
            isNot(contains(privateVideo)),
            reason:
                'publishing it as a public tag would disclose a bookmark the '
                'user chose to keep private (#7136)',
          );
        },
      );

      test(
        'removing a private item drops it from the encrypted array',
        () async {
          final ciphertext = await encryptToSelf([
            ['e', privateVideo],
            ['e', 'keep-me'],
          ]);
          stubRelay(events: [bookmarkListEvent([], content: ciphertext)]);
          final service = createService();

          final result = await service.toggleVideoInGlobalBookmarks(
            privateVideo,
          );

          expect(result.succeeded, isTrue);
          expect(result.isBookmarked, isFalse);
          expect(
            await decryptToSelf(signedContent!),
            equals([
              ['e', 'keep-me'],
            ]),
            reason:
                'leaving it in `content` would make the reported removal a lie '
                'for every conforming client (#7136)',
          );
          expect(
            service.isVideoBookmarkedGlobally(privateVideo),
            isFalse,
            reason: 'and the local read must agree with what was published',
          );
        },
      );

      test('counts an item held in both halves once', () async {
        const inBoth = 'in-both';
        stubRelay(
          events: [
            bookmarkListEvent(
              [inBoth],
              content: await encryptToSelf([
                ['e', inBoth],
              ]),
            ),
          ],
        );
        final service = createService();

        await service.syncGlobalBookmarks();

        expect(
          service.globalBookmarks,
          hasLength(1),
          reason:
              'one bookmarked video, so summing the two halves would report '
              'two - the count the sync log reads from',
        );
      });

      test('removing an item held in both halves drops both copies', () async {
        const inBoth = 'in-both';
        stubRelay(
          events: [
            bookmarkListEvent(
              [inBoth],
              content: await encryptToSelf([
                ['e', inBoth],
              ]),
            ),
          ],
        );
        final service = createService();

        final result = await service.toggleVideoInGlobalBookmarks(inBoth);

        expect(result.succeeded, isTrue);
        expect(result.isBookmarked, isFalse);
        expect(
          signedEventIds(),
          isNot(contains(inBoth)),
          reason:
              'a surviving public tag makes the reported removal a lie - the '
              'pre-fix leak (#7136) is what puts an item in both halves',
        );
        expect(
          service.isVideoBookmarkedGlobally(inBoth),
          isFalse,
          reason: 'and the local read must agree with what was published',
        );
      });

      test(
        'a racing sync never blanks the private items it is re-reading',
        () async {
          stubRelay(
            events: [
              bookmarkListEvent(
                [],
                content: await encryptToSelf([
                  ['e', privateVideo],
                ]),
              ),
            ],
          );
          final service = createService();
          await service.syncGlobalBookmarks();

          // Syncs are not serialized (#7163), so a second one re-reads the
          // list while the share sheet is still asking whether this video is
          // saved. Sample that question across the whole re-read rather than
          // at one instant, since the window is only as wide as the decrypt.
          var settled = false;
          final racing = service.syncGlobalBookmarks().whenComplete(
            () => settled = true,
          );
          var everReadUnsaved = false;
          var sampledToCompletion = false;
          for (var i = 0; i < 1000; i++) {
            if (settled) {
              sampledToCompletion = true;
              break;
            }
            everReadUnsaved |= !service.isVideoBookmarkedGlobally(privateVideo);
            await Future<void>.value();
          }
          await racing;

          expect(
            sampledToCompletion,
            isTrue,
            reason:
                'the loop has to outlast the sync, or the assertion below '
                'passes without ever having sampled the window - which is the '
                'inert shape this test replaced',
          );
          expect(
            everReadUnsaved,
            isFalse,
            reason:
                'clearing the private items before the decrypt await makes a '
                'saved video read as unsaved mid-sync, and a save taken in '
                'that window publishes it as a public tag (#7136)',
          );
        },
      );

      test('a removal rewrites only the entry it removes', () async {
        stubRelay(
          events: [
            bookmarkListEvent(
              [],
              content: await encryptToSelf([
                ['title', 'Reading list'],
                ['e', privateVideo],
                ['e', 'keep-me', 'wss://relay.example', 'a petname', 'extra'],
              ]),
            ),
          ],
        );
        final service = createService();

        await service.toggleVideoInGlobalBookmarks(privateVideo);

        expect(
          await decryptToSelf(signedContent!),
          equals([
            ['title', 'Reading list'],
            ['e', 'keep-me', 'wss://relay.example', 'a petname', 'extra'],
          ]),
          reason:
              're-encrypting from parsed items would drop another client tag '
              'this one does not model, and truncate the fifth position - '
              'losses the byte-for-byte carry-through could never cause',
        );
      });

      test('clears content once the last private item is removed', () async {
        stubRelay(
          events: [
            bookmarkListEvent(
              [],
              content: await encryptToSelf([
                ['e', privateVideo],
              ]),
            ),
          ],
        );
        final service = createService();

        await service.toggleVideoInGlobalBookmarks(privateVideo);

        expect(
          signedContent,
          isEmpty,
          reason: 'an empty private array carries no payload at all',
        );
      });

      test('refuses a private tag carrying a non-string value', () async {
        // Dropping the offending value instead would shift every position
        // after it: `['e', id, null, petname]` re-encrypts as
        // `['e', id, petname]`, promoting the label to the relay hint. The
        // verbatim carry-through exists precisely to make losses like that
        // impossible, so a payload this client cannot represent is unreadable.
        stubRelay(
          events: [
            bookmarkListEvent(
              [],
              content: (await identity.nip44Encrypt(
                pubkey,
                jsonEncode([
                  ['e', privateVideo, null, 'a petname'],
                ]),
              ))!,
            ),
          ],
        );
        final service = createService();

        final result = await service.toggleVideoInGlobalBookmarks('wanted');

        expect(
          result.failure,
          equals(BookmarkToggleFailure.privateItemsUnreadable),
        );
        expect(signedTags, isNull, reason: 'nothing may be published');
      });

      test('never writes private items into SharedPreferences', () async {
        stubRelay(
          events: [
            bookmarkListEvent(
              ['public-one'],
              content: await encryptToSelf([
                ['e', privateVideo],
              ]),
            ),
          ],
        );
        final service = createService();

        await service.syncGlobalBookmarks();

        expect(
          prefs.getString(BookmarkService.globalBookmarksStorageKey),
          allOf(contains('public-one'), isNot(contains(privateVideo))),
          reason:
              'SharedPreferences is unencrypted, so caching private items '
              'would move them into plaintext local storage',
        );
      });

      group('deprecated NIP-04 payloads', () {
        test('reads private items written under NIP-04', () async {
          stubRelay(
            events: [
              bookmarkListEvent(
                [],
                content: await encryptToSelfNip04([
                  ['e', privateVideo],
                ]),
              ),
            ],
          );
          final service = createService();

          await service.syncGlobalBookmarks();

          expect(service.hasUnreadablePrivateItems, isFalse);
          expect(
            service.globalBookmarks.map((item) => item.id),
            contains(privateVideo),
          );
        });

        test('toggles a list whose private items are NIP-04', () async {
          // The list this unblocks: before, every mutation was refused and the
          // user could never save or unsave again.
          stubRelay(
            events: [
              bookmarkListEvent(
                [],
                content: await encryptToSelfNip04([
                  ['e', privateVideo],
                ]),
              ),
            ],
          );
          final service = createService();

          final result = await service.toggleVideoInGlobalBookmarks('wanted');

          expect(result.succeeded, isTrue);
          expect(result.failure, isNull);
          expect(signedEventIds(), contains('wanted'));
        });

        test(
          're-encrypts the array as NIP-44 when an item is removed',
          () async {
            stubRelay(
              events: [
                bookmarkListEvent(
                  [],
                  content: await encryptToSelfNip04([
                    ['e', privateVideo],
                    ['e', 'kept-private'],
                  ]),
                ),
              ],
            );
            final service = createService();

            final result = await service.toggleVideoInGlobalBookmarks(
              privateVideo,
            );

            expect(result.succeeded, isTrue);
            expect(
              NIP04.isEncrypted(signedContent!),
              isFalse,
              reason: 'a rewrite upgrades the array off the deprecated scheme',
            );
            expect(
              await decryptToSelf(signedContent!),
              equals([
                ['e', 'kept-private'],
              ]),
              reason: 'only the removed entry is dropped',
            );
          },
        );
      });

      group('unreadable content', () {
        test('refuses to publish when the signer cannot decrypt', () async {
          // Content encrypted to a different identity: real ciphertext this
          // signer will never read.
          final stranger = LocalNostrIdentity(
            keyContainer: SecureKeyContainer.fromPrivateKeyHex(
              generatePrivateKey(),
            ),
          );
          final foreign = await stranger.nip44Encrypt(
            stranger.pubkey,
            jsonEncode([
              ['e', privateVideo],
            ]),
          );
          stubRelay(events: [bookmarkListEvent([], content: foreign!)]);
          final service = createService();

          final result = await service.toggleVideoInGlobalBookmarks('wanted');

          expect(result.succeeded, isFalse);
          expect(
            result.failure,
            equals(BookmarkToggleFailure.privateItemsUnreadable),
          );
          expect(signedTags, isNull);
        });

        test(
          'refuses to publish when the plaintext is not a tag array',
          () async {
            stubRelay(
              events: [
                bookmarkListEvent(
                  [],
                  content: (await identity.nip44Encrypt(pubkey, 'not json'))!,
                ),
              ],
            );
            final service = createService();

            final result = await service.toggleVideoInGlobalBookmarks('wanted');

            expect(result.succeeded, isFalse);
            expect(
              result.failure,
              equals(BookmarkToggleFailure.privateItemsUnreadable),
            );
            expect(signedTags, isNull);
          },
        );

        test(
          'reports the blind spot so callers can stay indeterminate',
          () async {
            // Carries the `iv` marker but is not decryptable under either
            // scheme, so it stays a blind spot rather than reading as empty.
            stubRelay(
              events: [
                bookmarkListEvent([], content: 'c29tZQ==?iv=aXY='),
              ],
            );
            final service = createService();

            await service.syncGlobalBookmarks();

            expect(service.hasUnreadablePrivateItems, isTrue);
          },
        );

        test('stays false for a list Divine can read end to end', () async {
          stubRelay(
            events: [
              bookmarkListEvent(
                [],
                content: await encryptToSelf([
                  ['e', privateVideo],
                ]),
              ),
            ],
          );
          final service = createService();

          await service.syncGlobalBookmarks();

          expect(service.hasUnreadablePrivateItems, isFalse);
        });
      });
    });
  });
}
