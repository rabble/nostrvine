import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:sticker_pack_repository/sticker_pack_repository.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _testCuratorPubkey1 =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _testCuratorPubkey2 =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _testUserPubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _externalAuthorPubkey =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

/// Kind 30030 — NIP-51 emoji set.
const int _emojiSetKind = 30030;

/// Kind 10030 — NIP-51 user emoji list.
const int _userEmojiListKind = 10030;

/// Counter to generate unique 64-char hex event IDs.
int _eventIdCounter = 0;

/// Generates a unique full-length 64-character hex event ID.
String _generateEventId() {
  _eventIdCounter++;
  return _eventIdCounter.toRadixString(16).padLeft(64, '0');
}

Event _createEmojiSetEvent({
  required String pubkey,
  required String dTag,
  String? title,
  String? imageUrl,
  List<List<String>> emojiTags = const [],
  List<List<String>> extraTags = const [],
  int createdAt = 1000,
}) {
  final tags = <List<String>>[
    ['d', dTag],
    if (title != null) ['title', title],
    if (imageUrl != null) ['image', imageUrl],
    ...emojiTags,
    ...extraTags,
  ];
  return Event(pubkey, _emojiSetKind, tags, '', createdAt: createdAt)
    ..id = _generateEventId();
}

/// Creates a Kind 30030 event using NIP-51 canonical tag names (`name`,
/// `picture`) instead of the legacy `title`/`image` variants.
Event _createNip51EmojiSetEvent({
  required String pubkey,
  required String dTag,
  String? name,
  String? pictureUrl,
  List<List<String>> emojiTags = const [],
  int createdAt = 1000,
}) {
  final tags = <List<String>>[
    ['d', dTag],
    if (name != null) ['name', name],
    if (pictureUrl != null) ['picture', pictureUrl],
    ...emojiTags,
  ];
  return Event(pubkey, _emojiSetKind, tags, '', createdAt: createdAt)
    ..id = _generateEventId();
}

Event _createUserEmojiListEvent({
  required String pubkey,
  required List<String> aTagValues,
  int createdAt = 1000,
}) {
  final tags = <List<String>>[
    for (final value in aTagValues) ['a', value],
  ];
  return Event(pubkey, _userEmojiListKind, tags, '', createdAt: createdAt)
    ..id = _generateEventId();
}

void main() {
  group(StickerPackRepository, () {
    late _MockNostrClient mockNostrClient;

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
    });

    setUp(() {
      mockNostrClient = _MockNostrClient();
      _eventIdCounter = 0;
    });

    group('constructor', () {
      test('creates repository with required parameters', () {
        final repo = StickerPackRepository(
          nostrClient: mockNostrClient,
          curatorPubkeys: [_testCuratorPubkey1],
        );
        expect(repo, isNotNull);
      });

      test('creates repository with optional userPubkey', () {
        final repo = StickerPackRepository(
          nostrClient: mockNostrClient,
          curatorPubkeys: [_testCuratorPubkey1],
          userPubkey: _testUserPubkey,
        );
        expect(repo, isNotNull);
      });
    });

    group('loadStickerPacks', () {
      group('curated packs', () {
        test('returns packs from a single curator', () async {
          final event = _createEmojiSetEvent(
            pubkey: _testCuratorPubkey1,
            dTag: 'fire-pack',
            title: 'Fire Pack',
            emojiTags: [
              ['emoji', 'fire', 'https://cdn.example.com/fire.png'],
            ],
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [event]);

          final repo = StickerPackRepository(
            nostrClient: mockNostrClient,
            curatorPubkeys: [_testCuratorPubkey1],
          );

          final packs = await repo.loadStickerPacks();

          expect(packs, hasLength(1));
          expect(packs.first.id, equals('fire-pack'));
          expect(packs.first.title, equals('Fire Pack'));
          expect(packs.first.authorPubkey, equals(_testCuratorPubkey1));
          expect(packs.first.stickers, hasLength(1));
          expect(packs.first.stickers.first.shortcode, equals('fire'));
        });

        test('returns packs from multiple curators', () async {
          final event1 = _createEmojiSetEvent(
            pubkey: _testCuratorPubkey1,
            dTag: 'pack-a',
            title: 'Pack A',
            emojiTags: [
              ['emoji', 'smile', 'https://cdn.example.com/smile.png'],
            ],
          );
          final event2 = _createEmojiSetEvent(
            pubkey: _testCuratorPubkey2,
            dTag: 'pack-b',
            title: 'Pack B',
            emojiTags: [
              ['emoji', 'wave', 'https://cdn.example.com/wave.png'],
            ],
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [event1, event2]);

          final repo = StickerPackRepository(
            nostrClient: mockNostrClient,
            curatorPubkeys: [_testCuratorPubkey1, _testCuratorPubkey2],
          );

          final packs = await repo.loadStickerPacks();

          expect(packs, hasLength(2));
          final ids = packs.map((p) => p.id).toSet();
          expect(ids, containsAll(['pack-a', 'pack-b']));
        });

        test('returns empty list when no curators have packs', () async {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => []);

          final repo = StickerPackRepository(
            nostrClient: mockNostrClient,
            curatorPubkeys: [_testCuratorPubkey1],
          );

          final packs = await repo.loadStickerPacks();

          expect(packs, isEmpty);
        });

        test('returns empty list when curatorPubkeys is empty', () async {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => []);

          final repo = StickerPackRepository(
            nostrClient: mockNostrClient,
            curatorPubkeys: const [],
          );

          final packs = await repo.loadStickerPacks();

          expect(packs, isEmpty);
        });

        test('filters out packs with no stickers', () async {
          final emptyPack = _createEmojiSetEvent(
            pubkey: _testCuratorPubkey1,
            dTag: 'empty-pack',
            title: 'Empty',
          );
          final validPack = _createEmojiSetEvent(
            pubkey: _testCuratorPubkey1,
            dTag: 'valid-pack',
            title: 'Valid',
            emojiTags: [
              ['emoji', 'ok', 'https://cdn.example.com/ok.png'],
            ],
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [emptyPack, validPack]);

          final repo = StickerPackRepository(
            nostrClient: mockNostrClient,
            curatorPubkeys: [_testCuratorPubkey1],
          );

          final packs = await repo.loadStickerPacks();

          expect(packs, hasLength(1));
          expect(packs.first.id, equals('valid-pack'));
        });
      });

      group('user-subscribed packs', () {
        test('resolves packs from Kind 10030 a-tag references', () async {
          final emojiListEvent = _createUserEmojiListEvent(
            pubkey: _testUserPubkey,
            aTagValues: [
              '$_emojiSetKind:$_externalAuthorPubkey:external-pack',
            ],
          );

          final externalPack = _createEmojiSetEvent(
            pubkey: _externalAuthorPubkey,
            dTag: 'external-pack',
            title: 'External Pack',
            emojiTags: [
              ['emoji', 'star', 'https://cdn.example.com/star.png'],
            ],
          );

          when(() => mockNostrClient.queryEvents(any())).thenAnswer((inv) {
            final filters = inv.positionalArguments[0] as List<Filter>;
            final filter = filters.first;

            if (filter.kinds?.contains(_emojiSetKind) == true &&
                filter.authors?.contains(_testUserPubkey) != true) {
              // Curated pack query or resolved a-tag query
              if (filter.authors?.contains(_externalAuthorPubkey) == true) {
                return Future.value([externalPack]);
              }
              return Future.value([]);
            }
            if (filter.kinds?.contains(_userEmojiListKind) == true) {
              return Future.value([emojiListEvent]);
            }
            return Future.value([]);
          });

          final repo = StickerPackRepository(
            nostrClient: mockNostrClient,
            curatorPubkeys: const [],
            userPubkey: _testUserPubkey,
          );

          final packs = await repo.loadStickerPacks();

          expect(packs, hasLength(1));
          expect(packs.first.id, equals('external-pack'));
          expect(packs.first.authorPubkey, equals(_externalAuthorPubkey));
        });

        test('skips user-subscribed when userPubkey is null', () async {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => []);

          final repo = StickerPackRepository(
            nostrClient: mockNostrClient,
            curatorPubkeys: [_testCuratorPubkey1],
          );

          final packs = await repo.loadStickerPacks();

          expect(packs, isEmpty);

          // Curated only (no discoveryRelays, no userPubkey)
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('handles empty Kind 10030 event', () async {
          final emojiListEvent = _createUserEmojiListEvent(
            pubkey: _testUserPubkey,
            aTagValues: const [],
          );

          when(() => mockNostrClient.queryEvents(any())).thenAnswer((inv) {
            final filters = inv.positionalArguments[0] as List<Filter>;
            final filter = filters.first;

            if (filter.kinds?.contains(_userEmojiListKind) == true) {
              return Future.value([emojiListEvent]);
            }
            return Future.value([]);
          });

          final repo = StickerPackRepository(
            nostrClient: mockNostrClient,
            curatorPubkeys: const [],
            userPubkey: _testUserPubkey,
          );

          final packs = await repo.loadStickerPacks();

          expect(packs, isEmpty);
        });

        test('handles malformed a-tag values gracefully', () async {
          final emojiListEvent = _createUserEmojiListEvent(
            pubkey: _testUserPubkey,
            aTagValues: [
              // Missing d-tag
              '$_emojiSetKind:$_externalAuthorPubkey',
              // Wrong kind prefix
              '99999:$_externalAuthorPubkey:some-pack',
              // Empty pubkey
              '$_emojiSetKind::some-pack',
              // Empty d-tag
              '$_emojiSetKind:$_externalAuthorPubkey:',
              // Completely malformed
              'garbage',
            ],
          );

          when(() => mockNostrClient.queryEvents(any())).thenAnswer((inv) {
            final filters = inv.positionalArguments[0] as List<Filter>;
            final filter = filters.first;

            if (filter.kinds?.contains(_userEmojiListKind) == true) {
              return Future.value([emojiListEvent]);
            }
            return Future.value([]);
          });

          final repo = StickerPackRepository(
            nostrClient: mockNostrClient,
            curatorPubkeys: const [],
            userPubkey: _testUserPubkey,
          );

          final packs = await repo.loadStickerPacks();

          expect(packs, isEmpty);
        });

        test('uses most recent Kind 10030 event when multiple exist', () async {
          final olderEmojiList = _createUserEmojiListEvent(
            pubkey: _testUserPubkey,
            aTagValues: [
              '$_emojiSetKind:$_externalAuthorPubkey:old-pack',
            ],
            createdAt: 500,
          );

          final newerEmojiList = _createUserEmojiListEvent(
            pubkey: _testUserPubkey,
            aTagValues: [
              '$_emojiSetKind:$_externalAuthorPubkey:new-pack',
            ],
          );

          final newPack = _createEmojiSetEvent(
            pubkey: _externalAuthorPubkey,
            dTag: 'new-pack',
            title: 'New Pack',
            emojiTags: [
              ['emoji', 'new', 'https://cdn.example.com/new.png'],
            ],
          );

          when(() => mockNostrClient.queryEvents(any())).thenAnswer((inv) {
            final filters = inv.positionalArguments[0] as List<Filter>;
            final filter = filters.first;

            if (filter.kinds?.contains(_userEmojiListKind) == true) {
              return Future.value([olderEmojiList, newerEmojiList]);
            }
            if (filter.kinds?.contains(_emojiSetKind) == true &&
                filter.authors?.contains(_externalAuthorPubkey) == true) {
              return Future.value([newPack]);
            }
            return Future.value([]);
          });

          final repo = StickerPackRepository(
            nostrClient: mockNostrClient,
            curatorPubkeys: const [],
            userPubkey: _testUserPubkey,
          );

          final packs = await repo.loadStickerPacks();

          expect(packs, hasLength(1));
          expect(packs.first.id, equals('new-pack'));
        });

        test('handles d-tags containing colons', () async {
          final emojiListEvent = _createUserEmojiListEvent(
            pubkey: _testUserPubkey,
            aTagValues: [
              '$_emojiSetKind:$_externalAuthorPubkey:pack:with:colons',
            ],
          );

          final pack = _createEmojiSetEvent(
            pubkey: _externalAuthorPubkey,
            dTag: 'pack:with:colons',
            title: 'Colon Pack',
            emojiTags: [
              ['emoji', 'colon', 'https://cdn.example.com/colon.png'],
            ],
          );

          when(() => mockNostrClient.queryEvents(any())).thenAnswer((inv) {
            final filters = inv.positionalArguments[0] as List<Filter>;
            final filter = filters.first;

            if (filter.kinds?.contains(_userEmojiListKind) == true) {
              return Future.value([emojiListEvent]);
            }
            if (filter.kinds?.contains(_emojiSetKind) == true &&
                filter.authors?.contains(_externalAuthorPubkey) == true) {
              return Future.value([pack]);
            }
            return Future.value([]);
          });

          final repo = StickerPackRepository(
            nostrClient: mockNostrClient,
            curatorPubkeys: const [],
            userPubkey: _testUserPubkey,
          );

          final packs = await repo.loadStickerPacks();

          expect(packs, hasLength(1));
          expect(packs.first.id, equals('pack:with:colons'));
        });
      });

      group('deduplication', () {
        test('deduplicates packs by authorPubkey:id', () async {
          final curatedPack = _createEmojiSetEvent(
            pubkey: _testCuratorPubkey1,
            dTag: 'shared-pack',
            title: 'Curated Version',
            emojiTags: [
              ['emoji', 'dup', 'https://cdn.example.com/dup.png'],
            ],
          );

          final emojiListEvent = _createUserEmojiListEvent(
            pubkey: _testUserPubkey,
            aTagValues: [
              '$_emojiSetKind:$_testCuratorPubkey1:shared-pack',
            ],
          );

          // Same pack returned from user subscription query
          final userSubscribedPack = _createEmojiSetEvent(
            pubkey: _testCuratorPubkey1,
            dTag: 'shared-pack',
            title: 'Curated Version',
            emojiTags: [
              ['emoji', 'dup', 'https://cdn.example.com/dup.png'],
            ],
          );

          when(() => mockNostrClient.queryEvents(any())).thenAnswer((inv) {
            final filters = inv.positionalArguments[0] as List<Filter>;
            final filter = filters.first;

            if (filter.kinds?.contains(_emojiSetKind) == true &&
                filter.authors?.contains(_testCuratorPubkey1) == true &&
                filter.d != null) {
              return Future.value([userSubscribedPack]);
            }
            if (filter.kinds?.contains(_emojiSetKind) == true) {
              return Future.value([curatedPack]);
            }
            if (filter.kinds?.contains(_userEmojiListKind) == true) {
              return Future.value([emojiListEvent]);
            }
            return Future.value([]);
          });

          final repo = StickerPackRepository(
            nostrClient: mockNostrClient,
            curatorPubkeys: [_testCuratorPubkey1],
            userPubkey: _testUserPubkey,
          );

          final packs = await repo.loadStickerPacks();

          // Should only have 1 pack, not 2 duplicates
          expect(packs, hasLength(1));
          expect(packs.first.id, equals('shared-pack'));
        });

        test('keeps packs with same id but different authors', () async {
          final pack1 = _createEmojiSetEvent(
            pubkey: _testCuratorPubkey1,
            dTag: 'same-id',
            title: 'From Curator 1',
            emojiTags: [
              ['emoji', 'a', 'https://cdn.example.com/a.png'],
            ],
          );
          final pack2 = _createEmojiSetEvent(
            pubkey: _testCuratorPubkey2,
            dTag: 'same-id',
            title: 'From Curator 2',
            emojiTags: [
              ['emoji', 'b', 'https://cdn.example.com/b.png'],
            ],
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [pack1, pack2]);

          final repo = StickerPackRepository(
            nostrClient: mockNostrClient,
            curatorPubkeys: [_testCuratorPubkey1, _testCuratorPubkey2],
          );

          final packs = await repo.loadStickerPacks();

          expect(packs, hasLength(2));
        });
      });

      group('caching', () {
        test('returns cached result on second call', () async {
          final event = _createEmojiSetEvent(
            pubkey: _testCuratorPubkey1,
            dTag: 'cached-pack',
            title: 'Cached',
            emojiTags: [
              ['emoji', 'cache', 'https://cdn.example.com/cache.png'],
            ],
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [event]);

          final repo = StickerPackRepository(
            nostrClient: mockNostrClient,
            curatorPubkeys: [_testCuratorPubkey1],
          );

          final first = await repo.loadStickerPacks();
          final second = await repo.loadStickerPacks();

          expect(first, hasLength(1));
          expect(second, hasLength(1));
          // First load triggers 1 query (curated; no discoveryRelays).
          // Second load uses cache — no additional queries.
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('fetches fresh data after clearCache', () async {
          final event = _createEmojiSetEvent(
            pubkey: _testCuratorPubkey1,
            dTag: 'pack',
            title: 'Pack',
            emojiTags: [
              ['emoji', 'x', 'https://cdn.example.com/x.png'],
            ],
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [event]);

          final repo = StickerPackRepository(
            nostrClient: mockNostrClient,
            curatorPubkeys: [_testCuratorPubkey1],
          );

          await repo.loadStickerPacks();
          repo.clearCache();
          await repo.loadStickerPacks();

          // Each load triggers 1 query (curated; no discoveryRelays).
          // Two loads = 2 total queries.
          verify(() => mockNostrClient.queryEvents(any())).called(2);
        });
      });

      group('error handling', () {
        test(
          'throws $LoadStickerPacksFailedException when all sources fail',
          () async {
            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenThrow(Exception('Network error'));

            when(
              () => mockNostrClient.queryEvents(
                any(),
                tempRelays: any(named: 'tempRelays'),
              ),
            ).thenThrow(Exception('Discovery also fails'));

            final repo = StickerPackRepository(
              nostrClient: mockNostrClient,
              curatorPubkeys: [_testCuratorPubkey1],
              userPubkey: _testUserPubkey,
              discoveryRelays: const ['wss://fail.relay'],
            );

            expect(
              repo.loadStickerPacks,
              throwsA(isA<LoadStickerPacksFailedException>()),
            );
          },
        );

        test(
          'returns curated packs when discovery fails',
          () async {
            final curatedEvent = _createEmojiSetEvent(
              pubkey: _testCuratorPubkey1,
              dTag: 'curated-only',
              title: 'Curated Only',
              emojiTags: [
                ['emoji', 'ok', 'https://cdn.example.com/ok.png'],
              ],
            );

            var callCount = 0;
            when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) {
              callCount++;
              // First call is curated, second is user-subscribed (empty),
              // third is discovery — make it fail
              if (callCount == 1) return Future.value([curatedEvent]);
              if (callCount == 3) throw Exception('Discovery failed');
              return Future.value([]);
            });

            // No discoveryRelays → discovery returns [], so we need them
            when(
              () => mockNostrClient.queryEvents(
                any(),
                tempRelays: any(named: 'tempRelays'),
              ),
            ).thenThrow(Exception('Discovery relay failed'));

            // Default mock for curated (no tempRelays)
            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((inv) async {
              final filters = inv.positionalArguments[0] as List<Filter>;
              final filter = filters.first;
              if (filter.authors?.contains(_testCuratorPubkey1) == true) {
                return [curatedEvent];
              }
              return [];
            });

            final repo = StickerPackRepository(
              nostrClient: mockNostrClient,
              curatorPubkeys: [_testCuratorPubkey1],
              discoveryRelays: const ['wss://failing.relay'],
            );

            final packs = await repo.loadStickerPacks();

            expect(packs, hasLength(1));
            expect(packs.first.id, equals('curated-only'));
          },
        );

        test(
          'returns discovered packs when curated fails',
          () async {
            final discoveredEvent = _createEmojiSetEvent(
              pubkey: _externalAuthorPubkey,
              dTag: 'discovered-only',
              title: 'Discovered Only',
              emojiTags: [
                ['emoji', 'star', 'https://cdn.example.com/star.png'],
              ],
            );

            // Curated query throws, discovery succeeds
            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenThrow(Exception('Curated failed'));

            when(
              () => mockNostrClient.queryEvents(
                any(),
                tempRelays: any(named: 'tempRelays'),
              ),
            ).thenAnswer((_) async => [discoveredEvent]);

            final repo = StickerPackRepository(
              nostrClient: mockNostrClient,
              curatorPubkeys: [_testCuratorPubkey1],
              discoveryRelays: const ['wss://good.relay'],
            );

            final packs = await repo.loadStickerPacks();

            expect(packs, hasLength(1));
            expect(packs.first.id, equals('discovered-only'));
          },
        );
      });
    });

    group('broad discovery', () {
      test('returns packs from relays without author filter', () async {
        final discoveredPack = _createEmojiSetEvent(
          pubkey: _externalAuthorPubkey,
          dTag: 'discovered',
          title: 'Discovered Pack',
          emojiTags: [
            ['emoji', 'found', 'https://cdn.example.com/found.png'],
          ],
        );

        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
          ),
        ).thenAnswer((_) async => [discoveredPack]);

        // Default mock for curated (no tempRelays)
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        final repo = StickerPackRepository(
          nostrClient: mockNostrClient,
          curatorPubkeys: const [],
          discoveryRelays: const ['wss://test.relay'],
        );

        final packs = await repo.loadStickerPacks();

        expect(packs, hasLength(1));
        expect(packs.first.id, equals('discovered'));
      });

      test('deduplicates discovered packs against curated', () async {
        final pack = _createEmojiSetEvent(
          pubkey: _testCuratorPubkey1,
          dTag: 'overlap',
          title: 'Overlap',
          emojiTags: [
            ['emoji', 'x', 'https://cdn.example.com/x.png'],
          ],
        );

        // Both curated and discovery return the same pack
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [pack]);

        final repo = StickerPackRepository(
          nostrClient: mockNostrClient,
          curatorPubkeys: [_testCuratorPubkey1],
        );

        final packs = await repo.loadStickerPacks();

        expect(packs, hasLength(1));
      });
    });

    group('getStickerPack', () {
      test('returns null before loadStickerPacks is called', () {
        final repo = StickerPackRepository(
          nostrClient: mockNostrClient,
          curatorPubkeys: [_testCuratorPubkey1],
        );

        expect(repo.getStickerPack('some-pack'), isNull);
      });

      test('returns pack by id after loading', () async {
        final event = _createEmojiSetEvent(
          pubkey: _testCuratorPubkey1,
          dTag: 'target',
          title: 'Target Pack',
          emojiTags: [
            ['emoji', 'ok', 'https://cdn.example.com/ok.png'],
          ],
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final repo = StickerPackRepository(
          nostrClient: mockNostrClient,
          curatorPubkeys: [_testCuratorPubkey1],
        );

        await repo.loadStickerPacks();
        final pack = repo.getStickerPack('target');

        expect(pack, isNotNull);
        expect(pack!.title, equals('Target Pack'));
      });

      test('returns null for non-existent id', () async {
        final event = _createEmojiSetEvent(
          pubkey: _testCuratorPubkey1,
          dTag: 'exists',
          title: 'Exists',
          emojiTags: [
            ['emoji', 'ok', 'https://cdn.example.com/ok.png'],
          ],
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final repo = StickerPackRepository(
          nostrClient: mockNostrClient,
          curatorPubkeys: [_testCuratorPubkey1],
        );

        await repo.loadStickerPacks();

        expect(repo.getStickerPack('nope'), isNull);
      });
    });

    group('clearCache', () {
      test('clears cached packs', () async {
        final event = _createEmojiSetEvent(
          pubkey: _testCuratorPubkey1,
          dTag: 'pack',
          title: 'Pack',
          emojiTags: [
            ['emoji', 'x', 'https://cdn.example.com/x.png'],
          ],
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final repo = StickerPackRepository(
          nostrClient: mockNostrClient,
          curatorPubkeys: [_testCuratorPubkey1],
        );

        await repo.loadStickerPacks();
        expect(repo.getStickerPack('pack'), isNotNull);

        repo.clearCache();
        expect(repo.getStickerPack('pack'), isNull);
      });
    });

    group('event parsing', () {
      test('uses d-tag as title fallback when title tag is missing', () async {
        final event = _createEmojiSetEvent(
          pubkey: _testCuratorPubkey1,
          dTag: 'fallback-title',
          emojiTags: [
            ['emoji', 'x', 'https://cdn.example.com/x.png'],
          ],
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final repo = StickerPackRepository(
          nostrClient: mockNostrClient,
          curatorPubkeys: [_testCuratorPubkey1],
        );

        final packs = await repo.loadStickerPacks();

        expect(packs.first.title, equals('fallback-title'));
      });

      test('parses image tag when present', () async {
        final event = _createEmojiSetEvent(
          pubkey: _testCuratorPubkey1,
          dTag: 'with-image',
          imageUrl: 'https://cdn.example.com/thumb.png',
          emojiTags: [
            ['emoji', 'x', 'https://cdn.example.com/x.png'],
          ],
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final repo = StickerPackRepository(
          nostrClient: mockNostrClient,
          curatorPubkeys: [_testCuratorPubkey1],
        );

        final packs = await repo.loadStickerPacks();

        expect(
          packs.first.imageUrl,
          equals('https://cdn.example.com/thumb.png'),
        );
      });

      test('skips events with missing d-tag', () async {
        // Create an event with no d-tag manually
        final event = Event(
          _testCuratorPubkey1,
          _emojiSetKind,
          <List<String>>[
            ['emoji', 'x', 'https://cdn.example.com/x.png'],
          ],
          '',
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final repo = StickerPackRepository(
          nostrClient: mockNostrClient,
          curatorPubkeys: [_testCuratorPubkey1],
        );

        final packs = await repo.loadStickerPacks();

        expect(packs, isEmpty);
      });

      test('parses NIP-51 name tag as title', () async {
        final event = _createNip51EmojiSetEvent(
          pubkey: _testCuratorPubkey1,
          dTag: 'nip51-pack',
          name: 'NIP-51 Name',
          emojiTags: [
            ['emoji', 'x', 'https://cdn.example.com/x.png'],
          ],
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final repo = StickerPackRepository(
          nostrClient: mockNostrClient,
          curatorPubkeys: [_testCuratorPubkey1],
        );

        final packs = await repo.loadStickerPacks();

        expect(packs.first.title, equals('NIP-51 Name'));
      });

      test('parses NIP-51 picture tag as imageUrl', () async {
        final event = _createNip51EmojiSetEvent(
          pubkey: _testCuratorPubkey1,
          dTag: 'nip51-pic',
          pictureUrl: 'https://cdn.example.com/pic.png',
          emojiTags: [
            ['emoji', 'x', 'https://cdn.example.com/x.png'],
          ],
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final repo = StickerPackRepository(
          nostrClient: mockNostrClient,
          curatorPubkeys: [_testCuratorPubkey1],
        );

        final packs = await repo.loadStickerPacks();

        expect(
          packs.first.imageUrl,
          equals('https://cdn.example.com/pic.png'),
        );
      });

      test('prefers first-seen tag when both name and title present', () async {
        // name appears before title — name wins via ??= semantics
        final event = _createNip51EmojiSetEvent(
          pubkey: _testCuratorPubkey1,
          dTag: 'both-tags',
          name: 'Name Tag',
          emojiTags: [
            ['emoji', 'x', 'https://cdn.example.com/x.png'],
          ],
        );
        // Append a title tag after name
        (event.tags as List<List<String>>).add(['title', 'Title Tag']);

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final repo = StickerPackRepository(
          nostrClient: mockNostrClient,
          curatorPubkeys: [_testCuratorPubkey1],
        );

        final packs = await repo.loadStickerPacks();

        expect(packs.first.title, equals('Name Tag'));
      });

      test('skips emoji tags with fewer than 3 elements', () async {
        final event = Event(
          _testCuratorPubkey1,
          _emojiSetKind,
          <List<String>>[
            ['d', 'pack'],
            ['emoji', 'only-shortcode'], // missing URL
            ['emoji', 'valid', 'https://cdn.example.com/valid.png'],
          ],
          '',
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final repo = StickerPackRepository(
          nostrClient: mockNostrClient,
          curatorPubkeys: [_testCuratorPubkey1],
        );

        final packs = await repo.loadStickerPacks();

        expect(packs, hasLength(1));
        expect(packs.first.stickers, hasLength(1));
        expect(packs.first.stickers.first.shortcode, equals('valid'));
      });
    });
  });
}
