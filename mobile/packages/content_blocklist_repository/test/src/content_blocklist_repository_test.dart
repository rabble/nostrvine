import 'dart:async';
import 'dart:convert';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockBlockListSigner extends Mock implements BlockListSigner {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(_FakeEvent());
  });

  group('ContentBlocklistRepository', () {
    late ContentBlocklistRepository service;

    setUp(() {
      service = ContentBlocklistRepository();
    });

    test('should initialize with no hardcoded blocked accounts', () {
      // Moderation should happen at relay level, not hardcoded in app
      expect(service.totalBlockedCount, equals(0));
    });

    test('should block users at runtime', () async {
      const testPubkey1 = 'pubkey_to_block_1';
      const testPubkey2 = 'pubkey_to_block_2';

      // Initially no blocks
      expect(service.totalBlockedCount, equals(0));
      expect(service.isBlocked(testPubkey1), isFalse);
      expect(service.isBlocked(testPubkey2), isFalse);

      // Block users at runtime
      await service.blockUser(testPubkey1);
      await service.blockUser(testPubkey2);

      expect(service.totalBlockedCount, equals(2));
      expect(service.isBlocked(testPubkey1), isTrue);
      expect(service.isBlocked(testPubkey2), isTrue);
    });

    test('should filter blocked content from feeds', () async {
      const blockedPubkey = 'blocked_user_pubkey';
      const allowedPubkey = 'allowed_user_pubkey';

      // Block a user first
      await service.blockUser(blockedPubkey);

      expect(service.shouldFilterFromFeeds(blockedPubkey), isTrue);
      expect(service.shouldFilterFromFeeds(allowedPubkey), isFalse);
    });

    test('should allow runtime blocking and unblocking', () async {
      const testPubkey = 'test_pubkey_for_runtime_blocking';

      // Initially not blocked
      expect(service.isBlocked(testPubkey), isFalse);

      // Block user
      await service.blockUser(testPubkey);
      expect(service.isBlocked(testPubkey), isTrue);

      // Unblock user
      await service.unblockUser(testPubkey);
      expect(service.isBlocked(testPubkey), isFalse);
    });

    test('should filter content list correctly', () async {
      const blockedPubkey1 = 'blocked_pubkey_1';
      const blockedPubkey2 = 'blocked_pubkey_2';

      // Block users first
      await service.blockUser(blockedPubkey1);
      await service.blockUser(blockedPubkey2);

      final testItems = [
        {'pubkey': blockedPubkey1, 'content': 'blocked'},
        {'pubkey': 'allowed_user', 'content': 'allowed'},
        {'pubkey': blockedPubkey2, 'content': 'blocked2'},
      ];

      final filtered = service.filterContent(
        testItems,
        (item) => item['pubkey']!,
      );

      expect(filtered.length, equals(1));
      expect(filtered.first['content'], equals('allowed'));
    });

    test('filterBlockedConversations filters blocked participants', () async {
      const userPubkey = 'current_user';
      const blockedPubkey = 'blocked_user';
      const allowedPubkey = 'allowed_user';

      await service.blockUser(blockedPubkey);

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final conversations = [
        DmConversation(
          id: 'conv1',
          participantPubkeys: const [userPubkey, blockedPubkey],
          isGroup: false,
          createdAt: now,
        ),
        DmConversation(
          id: 'conv2',
          participantPubkeys: const [userPubkey, allowedPubkey],
          isGroup: false,
          createdAt: now,
        ),
      ];

      final filtered = service.filterBlockedConversations(
        conversations,
        userPubkey: userPubkey,
      );

      expect(filtered, hasLength(1));
      expect(filtered.first.id, equals('conv2'));
    });

    test('filterBlockedConversations returns all when no blocks', () {
      const userPubkey = 'current_user';

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final conversations = [
        DmConversation(
          id: 'conv1',
          participantPubkeys: const [userPubkey, 'other1'],
          isGroup: false,
          createdAt: now,
        ),
        DmConversation(
          id: 'conv2',
          participantPubkeys: const [userPubkey, 'other2'],
          isGroup: false,
          createdAt: now,
        ),
      ];

      final filtered = service.filterBlockedConversations(
        conversations,
        userPubkey: userPubkey,
      );

      expect(filtered, hasLength(2));
    });

    test('filterBlockedConversations excludes self-conversations', () {
      const userPubkey = 'current_user';

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final conversations = [
        DmConversation(
          id: 'self_conv',
          participantPubkeys: const [userPubkey, userPubkey],
          isGroup: false,
          createdAt: now,
        ),
        DmConversation(
          id: 'normal_conv',
          participantPubkeys: const [userPubkey, 'other_user'],
          isGroup: false,
          createdAt: now,
        ),
      ];

      final filtered = service.filterBlockedConversations(
        conversations,
        userPubkey: userPubkey,
      );

      expect(filtered, hasLength(1));
      expect(filtered.first.id, equals('normal_conv'));
    });

    test('should provide blocking stats', () {
      final stats = service.blockingStats;

      expect(stats['total_blocks'], isA<int>());
      expect(stats['runtime_blocks'], isA<int>());
      expect(stats['internal_blocks'], isA<int>());
    });

    test('invokes onChanged callback for local block changes', () async {
      var changeCount = 0;
      service = ContentBlocklistRepository(onChanged: () => changeCount++);

      await service.blockUser('blocked_pubkey');
      await service.unblockUser('blocked_pubkey');

      expect(changeCount, equals(2));
    });

    group('changes stream', () {
      test('blockUser emits BlocklistOp.blocked', () async {
        const target = 'pubkey-target';
        final emitted = <BlocklistChange>[];
        final sub = service.changes.listen(emitted.add);
        addTearDown(sub.cancel);

        await service.blockUser(target);
        await Future<void>.delayed(Duration.zero);

        expect(
          emitted,
          equals([
            const BlocklistChange(
              pubkey: target,
              op: BlocklistOp.blocked,
            ),
          ]),
        );
      });

      test('unblockUser emits BlocklistOp.unblocked', () async {
        const target = 'pubkey-target';
        await service.blockUser(target);

        final emitted = <BlocklistChange>[];
        final sub = service.changes.listen(emitted.add);
        addTearDown(sub.cancel);

        await service.unblockUser(target);
        await Future<void>.delayed(Duration.zero);

        expect(
          emitted,
          equals([
            const BlocklistChange(
              pubkey: target,
              op: BlocklistOp.unblocked,
            ),
          ]),
        );
      });

      test('block + unblock round-trip emits both ops in order', () async {
        const target = 'pubkey-target';
        final emitted = <BlocklistChange>[];
        final sub = service.changes.listen(emitted.add);
        addTearDown(sub.cancel);

        await service.blockUser(target);
        await service.unblockUser(target);
        await Future<void>.delayed(Duration.zero);

        expect(
          emitted.map((c) => c.op),
          equals([
            BlocklistOp.blocked,
            BlocklistOp.unblocked,
          ]),
        );
        expect(emitted.every((c) => c.pubkey == target), isTrue);
      });

      test(
        're-blocking the same pubkey is a no-op (no duplicate emit)',
        () async {
          const target = 'pubkey-target';
          await service.blockUser(target);

          final emitted = <BlocklistChange>[];
          final sub = service.changes.listen(emitted.add);
          addTearDown(sub.cancel);

          await service.blockUser(target);
          await Future<void>.delayed(Duration.zero);

          expect(emitted, isEmpty);
        },
      );

      test('isAddition is correct for every op', () {
        const additions = [
          BlocklistOp.blocked,
          BlocklistOp.muted,
          BlocklistOp.mutedByUs,
          BlocklistOp.blockedUs,
        ];
        const removals = [
          BlocklistOp.unblocked,
          BlocklistOp.unmuted,
          BlocklistOp.unmutedByUs,
          BlocklistOp.unblockedUs,
        ];

        for (final op in additions) {
          expect(
            BlocklistChange(pubkey: 'p', op: op).isAddition,
            isTrue,
            reason: 'op $op should be an addition',
          );
        }
        for (final op in removals) {
          expect(
            BlocklistChange(pubkey: 'p', op: op).isAddition,
            isFalse,
            reason: 'op $op should NOT be an addition',
          );
        }
      });
    });

    group('self-block prevention', () {
      test(
        'blockUser() ignores when pubkey matches ourPubkey parameter',
        () async {
          const ourPubkey = 'test_our_pubkey';

          await service.blockUser(ourPubkey, ourPubkey: ourPubkey);

          expect(service.isBlocked(ourPubkey), isFalse);
          expect(service.totalBlockedCount, equals(0));
        },
      );

      test('blockUser() allows blocking other users', () async {
        const ourPubkey = 'our_pubkey';
        const otherPubkey = 'other_pubkey';

        await service.blockUser(otherPubkey, ourPubkey: ourPubkey);

        expect(service.isBlocked(otherPubkey), isTrue);
        expect(service.totalBlockedCount, equals(1));
      });

      test('blockUser() allows blocking when ourPubkey is null', () async {
        const otherPubkey = 'other_pubkey';

        // No ourPubkey provided - should allow blocking
        await service.blockUser(otherPubkey);

        expect(service.isBlocked(otherPubkey), isTrue);
        expect(service.totalBlockedCount, equals(1));
      });
    });
  });

  group('ContentBlocklistRepository - Mutual Mute Sync', () {
    late ContentBlocklistRepository service;
    late _MockNostrClient mockNostrService;

    setUp(() {
      service = ContentBlocklistRepository();
      mockNostrService = _MockNostrClient();
    });

    test(
      'syncMuteListsInBackground subscribes to mutual and own kind 10000',
      () async {
        const ourPubkey = 'test_our_pubkey_hex';

        List<dynamic>? capturedFilters;
        when(() => mockNostrService.subscribe(any())).thenAnswer((invocation) {
          capturedFilters = invocation.positionalArguments[0] as List;
          return const Stream.empty();
        });

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        // Verify subscribeToEvents was called
        verify(() => mockNostrService.subscribe(any())).called(1);

        expect(capturedFilters, isNotNull);
        expect(capturedFilters!.length, equals(2));

        final mutualFilter = capturedFilters![0] as Filter;
        expect(mutualFilter.kinds, contains(10000));
        expect(mutualFilter.p, contains(ourPubkey));

        final ownFilter = capturedFilters![1] as Filter;
        expect(ownFilter.kinds, contains(10000));
        expect(ownFilter.authors, contains(ourPubkey));
      },
    );

    test('syncMuteListsInBackground only subscribes once', () async {
      const ourPubkey = 'test_our_pubkey_hex';

      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

      // Should only subscribe once
      verify(() => mockNostrService.subscribe(any())).called(1);
    });

    test(
      'handleMuteListEvent adds muter to blocklist when our pubkey is in tags',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const muterPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';

        // Create a kind 10000 event with our pubkey in the 'p' tags
        final event =
            Event(
                muterPubkey,
                10000,
                [
                  ['p', ourPubkey],
                  ['p', 'some_other_pubkey'],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'event-id'
              ..sig = 'signature';

        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => Stream.fromIterable([event]));

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        // Give the stream time to emit
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify muter is now blocked
        expect(service.shouldFilterFromFeeds(muterPubkey), isTrue);
      },
    );

    test(
      'handleMuteListEvent removes muter when our pubkey not in tags (unmuted)',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const muterPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';

        // First event: muter adds us to their list
        final muteEvent =
            Event(
                muterPubkey,
                10000,
                [
                  ['p', ourPubkey],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'event-id-1'
              ..sig = 'signature';

        // Second event: muter removes us from their list (replaceable event)
        final unmuteEvent =
            Event(
                muterPubkey,
                10000,
                [
                  ['p', 'some_other_pubkey'], // Our pubkey is gone
                ],
                '',
                createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 60,
              )
              ..id = 'event-id-2'
              ..sig = 'signature';

        // Create a stream controller to manually emit events
        final controller = StreamController<Event>();

        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => controller.stream);

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        // First event - adds to blocklist
        controller.add(muteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.shouldFilterFromFeeds(muterPubkey), isTrue);

        // Second event - removes from blocklist
        controller.add(unmuteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.shouldFilterFromFeeds(muterPubkey), isFalse);

        await controller.close();
      },
    );

    test(
      'ignores stale older mute event after newer unmute event',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const muterPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';

        final newerUnmuteEvent =
            Event(
                muterPubkey,
                10000,
                [
                  ['p', 'some_other_pubkey'],
                ],
                '',
                createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 60,
              )
              ..id = 'newer-unmute-event-id'
              ..sig = 'signature';

        final olderMuteEvent =
            Event(
                muterPubkey,
                10000,
                [
                  ['p', ourPubkey],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'older-mute-event-id'
              ..sig = 'signature';

        final controller = StreamController<Event>();

        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => controller.stream);

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        controller.add(newerUnmuteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.hasMutedUs(muterPubkey), isFalse);

        controller.add(olderMuteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.hasMutedUs(muterPubkey), isFalse);
        expect(service.shouldFilterFromFeeds(muterPubkey), isFalse);

        await controller.close();
      },
    );

    test('shouldFilterFromFeeds checks mutual mute blocklist', () async {
      const ourPubkey =
          '0000000000000000000000000000000000000000000000000000000000000001';
      const muterPubkey =
          '0000000000000000000000000000000000000000000000000000000000000002';
      const randomPubkey =
          '0000000000000000000000000000000000000000000000000000000000000003';

      final event =
          Event(
              muterPubkey,
              10000,
              [
                ['p', ourPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            )
            ..id = 'event-id'
            ..sig = 'signature';

      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => Stream.fromIterable([event]));

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

      // Give the stream time to emit
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Mutual muter should be filtered
      expect(service.shouldFilterFromFeeds(muterPubkey), isTrue);

      // Random user should not be filtered
      expect(service.shouldFilterFromFeeds(randomPubkey), isFalse);
    });

    test(
      'hasMutedUs only checks mutual mute blocklist, not runtime blocks',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const muterPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';
        const blockedByUsPubkey =
            '0000000000000000000000000000000000000000000000000000000000000003';

        final event =
            Event(
                muterPubkey,
                10000,
                [
                  ['p', ourPubkey],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'event-id'
              ..sig = 'signature';

        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => Stream.fromIterable([event]));

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        // Give the stream time to emit
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Block a user ourselves
        await service.blockUser(blockedByUsPubkey);

        // hasMutedUs should return true for mutual muter
        expect(service.hasMutedUs(muterPubkey), isTrue);

        // hasMutedUs should return false for user WE blocked
        // (this is the key distinction - we can still view their profile)
        expect(service.hasMutedUs(blockedByUsPubkey), isFalse);

        // But shouldFilterFromFeeds includes both
        expect(service.shouldFilterFromFeeds(muterPubkey), isTrue);
        expect(service.shouldFilterFromFeeds(blockedByUsPubkey), isTrue);
      },
    );
  });

  group('ContentBlocklistRepository - Own Mute List Sync', () {
    const ourPubkey =
        '0000000000000000000000000000000000000000000000000000000000000001';
    const mutedPubkey =
        '0000000000000000000000000000000000000000000000000000000000000002';
    const otherMutedPubkey =
        '0000000000000000000000000000000000000000000000000000000000000003';

    late ContentBlocklistRepository service;
    late _MockNostrClient mockNostrService;
    late StreamController<Event> controller;

    Event ownMuteListEvent({
      required List<String> mutedPubkeys,
      required int createdAt,
      String id = 'own-mute-event-id',
    }) =>
        Event(
            ourPubkey,
            10000,
            [
              for (final pubkey in mutedPubkeys) ['p', pubkey],
            ],
            '',
            createdAt: createdAt,
          )
          ..id = id
          ..sig = 'signature';

    setUp(() {
      service = ContentBlocklistRepository();
      mockNostrService = _MockNostrClient();
      controller = StreamController<Event>();
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => controller.stream);
    });

    tearDown(() async {
      await controller.close();
    });

    test('own kind 10000 event populates muted authors', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [mutedPubkey, otherMutedPubkey],
          createdAt: now,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.isMutedByUs(mutedPubkey), isTrue);
      expect(service.isMutedByUs(otherMutedPubkey), isTrue);
      expect(service.shouldFilterFromFeeds(mutedPubkey), isTrue);
      expect(
        service.currentState.mutedPubkeys,
        containsAll(<String>{mutedPubkey, otherMutedPubkey}),
      );
      // Mutes are not blocks — the block-specific queries stay false.
      expect(service.isBlocked(mutedPubkey), isFalse);
      expect(service.hasMutedUs(mutedPubkey), isFalse);
    });

    test('own kind 10000 echo does not double-count our own blocks as '
        'mutes', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      // We blocked mutedPubkey in-app (no signer wired, so publishing is a
      // no-op here), then our own kind 10000 echoes back containing both
      // that block and a mute authored from another client.
      await service.blockUser(mutedPubkey, ourPubkey: ourPubkey);
      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [mutedPubkey, otherMutedPubkey],
          createdAt: now,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Our own block stays tracked as a block, not duplicated into the
      // mute set — otherwise unblocking could never drop it from the
      // republished kind 10000 list.
      expect(service.isBlocked(mutedPubkey), isTrue);
      expect(service.isMutedByUs(mutedPubkey), isFalse);
      // The external mute is still recorded.
      expect(service.isMutedByUs(otherMutedPubkey), isTrue);
      // Both are filtered from feeds regardless.
      expect(service.shouldFilterFromFeeds(mutedPubkey), isTrue);
      expect(service.shouldFilterFromFeeds(otherMutedPubkey), isTrue);
    });

    test('newer own event replaces the muted set (unmute)', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [mutedPubkey, otherMutedPubkey],
          createdAt: now,
          id: 'own-mute-event-id-1',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [otherMutedPubkey],
          createdAt: now + 60,
          id: 'own-mute-event-id-2',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.isMutedByUs(mutedPubkey), isFalse);
      expect(service.shouldFilterFromFeeds(mutedPubkey), isFalse);
      expect(service.isMutedByUs(otherMutedPubkey), isTrue);
    });

    test('ignores stale older own mute event', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [],
          createdAt: now + 60,
          id: 'own-mute-event-id-newer',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [mutedPubkey],
          createdAt: now,
          id: 'own-mute-event-id-older',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.isMutedByUs(mutedPubkey), isFalse);
      expect(service.shouldFilterFromFeeds(mutedPubkey), isFalse);
    });

    test('excludes our own pubkey from a self-referential mute list', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [ourPubkey, mutedPubkey],
          createdAt: now,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // A malformed self-referential list must never filter our own
      // content (#2192).
      expect(service.isMutedByUs(ourPubkey), isFalse);
      expect(service.shouldFilterFromFeeds(ourPubkey), isFalse);
      expect(service.isMutedByUs(mutedPubkey), isTrue);
    });

    test('own mute event does not touch the mutual-mute set', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      // Our own list naming our own pubkey-of-interest must route to the
      // own-mute handler, not register as "they muted us".
      controller.add(
        ownMuteListEvent(mutedPubkeys: [mutedPubkey], createdAt: now),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.hasMutedUs(ourPubkey), isFalse);
      expect(service.hasMutedUs(mutedPubkey), isFalse);
      expect(service.isMutedByUs(mutedPubkey), isTrue);
    });

    test('emits mutedByUs and unmutedByUs on the changes stream', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final changes = <BlocklistChange>[];
      final subscription = service.changes.listen(changes.add);

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [mutedPubkey],
          createdAt: now,
          id: 'own-mute-event-id-1',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [],
          createdAt: now + 60,
          id: 'own-mute-event-id-2',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        changes,
        containsAllInOrder([
          const BlocklistChange(
            pubkey: mutedPubkey,
            op: BlocklistOp.mutedByUs,
          ),
          const BlocklistChange(
            pubkey: mutedPubkey,
            op: BlocklistOp.unmutedByUs,
          ),
        ]),
      );
      expect(
        changes.firstWhere((c) => c.op == BlocklistOp.mutedByUs).isAddition,
        isTrue,
      );
      expect(
        changes.firstWhere((c) => c.op == BlocklistOp.unmutedByUs).isAddition,
        isFalse,
      );

      await subscription.cancel();
    });

    test('continues when persisting muted authors throws', () async {
      final mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenThrow(Exception('disk full'));

      final failingService = ContentBlocklistRepository(prefs: mockPrefs);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await failingService.syncMuteListsInBackground(
        mockNostrService,
        ourPubkey,
      );
      controller.add(
        ownMuteListEvent(mutedPubkeys: [mutedPubkey], createdAt: now),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The in-memory set still updates even though the write failed.
      expect(failingService.isMutedByUs(mutedPubkey), isTrue);

      failingService.dispose();
    });

    test('persists muted authors and rehydrates at construction', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final persistedService = ContentBlocklistRepository(prefs: prefs);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await persistedService.syncMuteListsInBackground(
        mockNostrService,
        ourPubkey,
      );
      controller.add(
        ownMuteListEvent(mutedPubkeys: [mutedPubkey], createdAt: now),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(persistedService.isMutedByUs(mutedPubkey), isTrue);

      // A fresh instance over the same prefs hydrates the muted set
      // before any relay event arrives.
      final rehydrated = ContentBlocklistRepository(prefs: prefs);
      expect(rehydrated.isMutedByUs(mutedPubkey), isTrue);
      expect(rehydrated.shouldFilterFromFeeds(mutedPubkey), isTrue);
      expect(rehydrated.currentState.mutedPubkeys, contains(mutedPubkey));

      persistedService.dispose();
      rehydrated.dispose();
    });
  });

  group('ContentBlocklistRepository - identity change (#4969)', () {
    const accountA =
        '00000000000000000000000000000000000000000000000000000000000000aa';
    const accountB =
        '00000000000000000000000000000000000000000000000000000000000000bb';
    const blockerX =
        '0000000000000000000000000000000000000000000000000000000000000011';
    const someoneElse =
        '0000000000000000000000000000000000000000000000000000000000000022';

    late _MockNostrClient mockNostrService;
    late StreamController<Event> controller;

    Event blockListEvent({
      required String author,
      required List<String> blockedPubkeys,
      required int createdAt,
      String id = 'block-event-id',
    }) =>
        Event(
            author,
            30000,
            [
              ['d', 'block'],
              for (final pubkey in blockedPubkeys) ['p', pubkey],
            ],
            '',
            createdAt: createdAt,
          )
          ..id = id
          ..sig = 'signature';

    setUp(() {
      mockNostrService = _MockNostrClient();
      controller = StreamController<Event>.broadcast();
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => controller.stream);
    });

    tearDown(() async {
      await controller.close();
    });

    test(
      'switching accounts clears relay-synced blocked-by and mute state',
      () async {
        final service = ContentBlocklistRepository();
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        await service.syncBlockListsInBackground(
          mockNostrService,
          _MockBlockListSigner(),
          accountA,
        );
        controller.add(
          blockListEvent(
            author: blockerX,
            blockedPubkeys: [accountA],
            createdAt: now,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.hasBlockedUs(blockerX), isTrue);

        // Switch to account B: X never blocked B, so the gate must clear.
        await service.syncBlockListsInBackground(
          mockNostrService,
          _MockBlockListSigner(),
          accountB,
        );
        expect(service.hasBlockedUs(blockerX), isFalse);
        expect(service.shouldFilterFromFeeds(blockerX), isFalse);
        expect(service.hasMutedUs(blockerX), isFalse);
        expect(service.currentState.pubkeysBlockingUs, isEmpty);
        expect(service.currentState.mutedPubkeys, isEmpty);

        service.dispose();
      },
    );

    test('switching accounts re-subscribes with the new pubkey', () async {
      final captured = <List<dynamic>>[];
      when(() => mockNostrService.subscribe(any())).thenAnswer((invocation) {
        captured.add(invocation.positionalArguments[0] as List);
        return controller.stream;
      });

      final service = ContentBlocklistRepository();
      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await service.syncMuteListsInBackground(mockNostrService, accountB);

      expect(captured, hasLength(2));
      final secondMutual = captured[1][0] as Filter;
      expect(secondMutual.p, contains(accountB));
      final secondOwn = captured[1][1] as Filter;
      expect(secondOwn.authors, contains(accountB));

      service.dispose();
    });

    test('per-account blocks do not leak across a switch and survive '
        'switching back', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await service.blockUser(blockerX);
      expect(service.isBlocked(blockerX), isTrue);

      await service.syncMuteListsInBackground(mockNostrService, accountB);
      expect(
        service.isBlocked(blockerX),
        isFalse,
        reason: "account A's blocks must not apply to account B",
      );
      await service.blockUser(someoneElse);

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      expect(service.isBlocked(blockerX), isTrue);
      expect(service.isBlocked(someoneElse), isFalse);

      service.dispose();
    });

    test('first identity adopts legacy un-namespaced persisted data', () async {
      SharedPreferences.setMockInitialValues({
        'blocked_users_list': jsonEncode([blockerX]),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      // Legacy data hydrates before any identity is known.
      expect(service.isBlocked(blockerX), isTrue);

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      expect(service.isBlocked(blockerX), isTrue);

      // A fresh instance over the same prefs loads the migrated,
      // account-scoped data.
      final rehydrated = ContentBlocklistRepository(prefs: prefs);
      expect(rehydrated.isBlocked(blockerX), isTrue);
      expect(prefs.getString('blocked_users_list'), isNull);

      service.dispose();
      rehydrated.dispose();
    });

    test('continues when legacy key migration throws', () async {
      final mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.getString('blocked_users_list'),
      ).thenReturn(jsonEncode([blockerX]));
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenThrow(Exception('disk full'));

      final service = ContentBlocklistRepository(prefs: mockPrefs);
      expect(service.isBlocked(blockerX), isTrue);

      // Adoption triggers migration; the failed move must not throw and
      // the in-memory state must survive.
      await service.syncMuteListsInBackground(mockNostrService, accountA);
      expect(service.isBlocked(blockerX), isTrue);

      service.dispose();
    });

    test('keeps the legacy key when the scoped copy reports failure', () async {
      final mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.getString('blocked_users_list'),
      ).thenReturn(jsonEncode([blockerX]));
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenAnswer((_) async => false);
      when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);

      final service = ContentBlocklistRepository(prefs: mockPrefs);
      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await Future<void>.delayed(Duration.zero);

      // The scoped copy never landed, so the legacy data must survive
      // for the next attempt.
      verifyNever(() => mockPrefs.remove('blocked_users_list'));
      expect(service.isBlocked(blockerX), isTrue);

      service.dispose();
    });

    test('survives an asynchronous setString failure during '
        'migration', () async {
      final mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.getString('blocked_users_list'),
      ).thenReturn(jsonEncode([blockerX]));
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenAnswer((_) => Future.error(Exception('platform write failed')));
      when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);

      final service = ContentBlocklistRepository(prefs: mockPrefs);
      await service.syncMuteListsInBackground(mockNostrService, accountA);
      // Flush the unawaited migration; a rejection it failed to catch
      // would surface as an unhandled error and fail this test.
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => mockPrefs.remove('blocked_users_list'));
      expect(service.isBlocked(blockerX), isTrue);

      service.dispose();
    });

    test('retries a failed legacy migration on the next launch and '
        'recovers the data in-session', () async {
      // An earlier launch recorded the active account but its legacy
      // move failed: the data still sits at the un-namespaced keys.
      SharedPreferences.setMockInitialValues({
        'blocklist_active_pubkey': accountA,
        'blocked_users_list': jsonEncode([blockerX]),
        'severed_followers_list': jsonEncode([someoneElse]),
      });
      final prefs = await SharedPreferences.getInstance();
      var changeCount = 0;
      final service = ContentBlocklistRepository(
        prefs: prefs,
        onChanged: () => changeCount++,
      );

      // Hydration reads the (empty) scoped keys, so the data starts
      // invisible.
      expect(service.isBlocked(blockerX), isFalse);
      expect(service.isFollowSevered(someoneElse), isFalse);
      final changesBefore = changeCount;

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString('blocked_users_list'), isNull);
      expect(
        prefs.getString('blocked_users_list.$accountA'),
        equals(jsonEncode([blockerX])),
      );
      expect(prefs.getString('severed_followers_list'), isNull);
      expect(
        prefs.getString('severed_followers_list.$accountA'),
        equals(jsonEncode([someoneElse])),
      );
      expect(service.isBlocked(blockerX), isTrue);
      expect(service.isFollowSevered(someoneElse), isTrue);
      expect(
        changeCount,
        greaterThan(changesBefore),
        reason: 'watchers must re-filter with the recovered data',
      );

      service.dispose();
    });

    test('merges legacy data with a scoped value written by a save '
        'that raced the migration', () async {
      // The recorded account's scoped key was absent at construction,
      // so a value appearing there mid-session comes from this
      // session's own saves — those entries and the legacy entries
      // must both survive.
      SharedPreferences.setMockInitialValues({
        'blocklist_active_pubkey': accountA,
        'blocked_users_list': jsonEncode([blockerX]),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      // A user action lands before the session identity resolves.
      await service.blockUser(someoneElse);
      expect(prefs.getString('blocked_users_list.$accountA'), isNotNull);

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString('blocked_users_list'), isNull);
      final scoped =
          (jsonDecode(prefs.getString('blocked_users_list.$accountA')!)
                  as List<dynamic>)
              .cast<String>();
      expect(scoped, containsAll([blockerX, someoneElse]));
      expect(service.isBlocked(blockerX), isTrue);
      expect(service.isBlocked(someoneElse), isTrue);

      service.dispose();
    });

    test('prefers a pre-adoption scoped value over the legacy snapshot '
        'when no account was recorded', () async {
      // A previous launch copied the legacy data but failed to remove
      // it and to record the account: the scoped value may hold newer
      // writes, so it wins and the stale legacy key is dropped.
      SharedPreferences.setMockInitialValues({
        'blocked_users_list': jsonEncode([blockerX]),
        'blocked_users_list.$accountA': jsonEncode([blockerX, someoneElse]),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString('blocked_users_list'), isNull);
      expect(
        prefs.getString('blocked_users_list.$accountA'),
        equals(jsonEncode([blockerX, someoneElse])),
      );

      service.dispose();
    });

    test('skips a corrupt legacy value without dropping it', () async {
      SharedPreferences.setMockInitialValues({
        'blocked_users_list': 'not-json',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString('blocked_users_list'), equals('not-json'));
      expect(prefs.getString('blocked_users_list.$accountA'), isNull);

      service.dispose();
    });

    test('tolerates a failed stale legacy cleanup', () async {
      final mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.getString('blocklist_active_pubkey'),
      ).thenReturn(accountA);
      when(
        () => mockPrefs.getString('blocked_users_list'),
      ).thenReturn(jsonEncode([blockerX]));
      when(
        () => mockPrefs.getString('blocked_users_list.$accountA'),
      ).thenReturn(jsonEncode([someoneElse]));
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenAnswer((_) async => true);
      when(() => mockPrefs.remove(any())).thenThrow(Exception('disk error'));

      final service = ContentBlocklistRepository(prefs: mockPrefs);
      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await Future<void>.delayed(Duration.zero);

      // The cleanup failure is swallowed and the hydrated state stays
      // usable; the stale key is retried on the next launch.
      verify(() => mockPrefs.remove('blocked_users_list')).called(1);
      expect(service.isBlocked(someoneElse), isTrue);

      service.dispose();
    });

    test('stops migrating remaining keys when the account switches '
        'mid-flight', () async {
      final mockPrefs = _MockSharedPreferences();
      final firstWrite = Completer<bool>();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.getString('blocklist_active_pubkey'),
      ).thenReturn(accountA);
      when(
        () => mockPrefs.getString('blocked_users_list'),
      ).thenReturn(jsonEncode([blockerX]));
      when(
        () => mockPrefs.getString('severed_followers_list'),
      ).thenReturn(jsonEncode([someoneElse]));
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockPrefs.setString('blocked_users_list.$accountA', any()),
      ).thenAnswer((_) => firstWrite.future);
      when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);

      final service = ContentBlocklistRepository(prefs: mockPrefs);
      await service.syncMuteListsInBackground(mockNostrService, accountA);
      // The first key's platform write is in flight when the session
      // switches identity.
      await service.syncMuteListsInBackground(mockNostrService, accountB);
      firstWrite.complete(true);
      await Future<void>.delayed(Duration.zero);

      // The in-flight write already serialized account A's set, so its
      // move completes — but the remaining legacy key must not be
      // serialized under the new identity.
      verify(() => mockPrefs.remove('blocked_users_list')).called(1);
      verifyNever(
        () => mockPrefs.setString('severed_followers_list.$accountA', any()),
      );
      verifyNever(() => mockPrefs.remove('severed_followers_list'));

      service.dispose();
    });

    test('does not clobber newer scoped data when retrying the legacy '
        'move', () async {
      // An earlier copy landed but its remove failed, and the scoped
      // set has been written since: the legacy snapshot is stale.
      SharedPreferences.setMockInitialValues({
        'blocklist_active_pubkey': accountA,
        'blocked_users_list': jsonEncode([blockerX]),
        'blocked_users_list.$accountA': jsonEncode([someoneElse]),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString('blocked_users_list'), isNull);
      expect(
        prefs.getString('blocked_users_list.$accountA'),
        equals(jsonEncode([someoneElse])),
      );
      expect(service.isBlocked(someoneElse), isTrue);
      expect(service.isBlocked(blockerX), isFalse);

      service.dispose();
    });

    test('leaves legacy data untouched when a different account than '
        'its owner signs in', () async {
      SharedPreferences.setMockInitialValues({
        'blocklist_active_pubkey': accountA,
        'blocked_users_list': jsonEncode([blockerX]),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.syncMuteListsInBackground(mockNostrService, accountB);
      await Future<void>.delayed(Duration.zero);

      expect(
        prefs.getString('blocked_users_list'),
        equals(jsonEncode([blockerX])),
      );
      expect(prefs.getString('blocked_users_list.$accountB'), isNull);
      expect(service.isBlocked(blockerX), isFalse);

      service.dispose();
    });

    test('adopting a different identity than the stored account resets '
        'hydrated state', () async {
      SharedPreferences.setMockInitialValues({
        'blocklist_active_pubkey': accountA,
        'blocked_users_list.$accountA': jsonEncode([blockerX]),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      // Construction hydrates account A's persisted blocks.
      expect(service.isBlocked(blockerX), isTrue);

      // The session resolves to account B: A's blocks must not apply.
      await service.syncMuteListsInBackground(mockNostrService, accountB);
      expect(service.isBlocked(blockerX), isFalse);

      service.dispose();
    });

    test('notifies listeners when a switch resets state', () async {
      var changeCount = 0;
      final service = ContentBlocklistRepository(
        onChanged: () => changeCount++,
      );

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      final before = changeCount;

      await service.syncMuteListsInBackground(mockNostrService, accountB);
      expect(
        changeCount,
        greaterThan(before),
        reason: 'watchers must re-filter after an account switch',
      );

      service.dispose();
    });
  });

  group('ContentBlocklistRepository - Block List Sync', () {
    late ContentBlocklistRepository service;
    late _MockNostrClient mockNostrService;
    late _MockBlockListSigner mockSigner;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockSigner = _MockBlockListSigner();
    });

    test(
      'syncBlockListsInBackground subscribes with two filters',
      () async {
        const ourPubkey = 'test_our_pubkey_hex';
        service = ContentBlocklistRepository();

        List<dynamic>? capturedFilters;
        when(
          () => mockNostrService.subscribe(
            any(),
          ),
        ).thenAnswer((invocation) {
          capturedFilters = invocation.positionalArguments[0] as List;
          return const Stream.empty();
        });

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );

        verify(
          () => mockNostrService.subscribe(
            any(),
          ),
        ).called(1);

        expect(capturedFilters, isNotNull);
        expect(capturedFilters!.length, equals(2));

        // Filter 1: others' block lists containing our pubkey
        final othersFilter = capturedFilters![0] as Filter;
        expect(othersFilter.kinds, contains(30000));
        expect(othersFilter.p, contains(ourPubkey));

        // Filter 2: our own block list for relay restoration
        // No #d constraint — handler checks d=block, avoids relay compat issues
        final ownFilter = capturedFilters![1] as Filter;
        expect(ownFilter.kinds, contains(30000));
        expect(ownFilter.authors, contains(ourPubkey));
      },
    );

    test(
      'handleBlockListEvent adds blocker when our pubkey is in block list',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const blockerPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';

        var changeCount = 0;
        service = ContentBlocklistRepository(onChanged: () => changeCount++);

        final event =
            Event(
                blockerPubkey,
                30000,
                [
                  ['d', 'block'],
                  ['p', ourPubkey],
                ],
                'Block list',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'block-event-id'
              ..sig = 'signature';

        when(
          () => mockNostrService.subscribe(
            any(),
          ),
        ).thenAnswer((_) => Stream.fromIterable([event]));

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(service.hasBlockedUs(blockerPubkey), isTrue);
        expect(service.shouldFilterFromFeeds(blockerPubkey), isTrue);
        expect(changeCount, equals(1));
      },
    );

    test(
      'handleBlockListEvent removes blocker when updated event no longer '
      'contains our pubkey',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const blockerPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';

        var changeCount = 0;
        service = ContentBlocklistRepository(onChanged: () => changeCount++);

        final blockEvent =
            Event(
                blockerPubkey,
                30000,
                [
                  ['d', 'block'],
                  ['p', ourPubkey],
                ],
                'Block list',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'block-event-id'
              ..sig = 'signature';

        final unblockEvent =
            Event(
                blockerPubkey,
                30000,
                [
                  ['d', 'block'],
                  ['p', 'some_other_pubkey'],
                ],
                'Block list',
                createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 60,
              )
              ..id = 'unblock-event-id'
              ..sig = 'signature';

        final controller = StreamController<Event>();

        when(
          () => mockNostrService.subscribe(
            any(),
          ),
        ).thenAnswer((_) => controller.stream);

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );

        controller.add(blockEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.hasBlockedUs(blockerPubkey), isTrue);

        controller.add(unblockEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.hasBlockedUs(blockerPubkey), isFalse);
        expect(changeCount, equals(2));

        await controller.close();
      },
    );

    test(
      'ignores stale older block event after newer unblock event',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const blockerPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';

        service = ContentBlocklistRepository();

        final newerUnblockEvent =
            Event(
                blockerPubkey,
                30000,
                [
                  ['d', 'block'],
                  ['p', 'some_other_pubkey'],
                ],
                'Block list',
                createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 60,
              )
              ..id = 'newer-unblock-event-id'
              ..sig = 'signature';

        final olderBlockEvent =
            Event(
                blockerPubkey,
                30000,
                [
                  ['d', 'block'],
                  ['p', ourPubkey],
                ],
                'Block list',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'older-block-event-id'
              ..sig = 'signature';

        final controller = StreamController<Event>();

        when(
          () => mockNostrService.subscribe(
            any(),
          ),
        ).thenAnswer((_) => controller.stream);

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );

        controller.add(newerUnblockEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.hasBlockedUs(blockerPubkey), isFalse);

        controller.add(olderBlockEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.hasBlockedUs(blockerPubkey), isFalse);
        expect(service.shouldFilterFromFeeds(blockerPubkey), isFalse);

        await controller.close();
      },
    );
  });

  group('ContentBlocklistRepository - Relay Block List Restoration', () {
    late ContentBlocklistRepository service;
    late _MockNostrClient mockNostrService;
    late _MockBlockListSigner mockSigner;
    late StreamController<Event> controller;

    const ourPubkey =
        '0000000000000000000000000000000000000000000000000000000000000001';
    const blockedPubkey1 =
        '0000000000000000000000000000000000000000000000000000000000000002';
    const blockedPubkey2 =
        '0000000000000000000000000000000000000000000000000000000000000003';

    Event makeOwnBlockListEvent(List<String> blockedPubkeys) {
      return Event(
          ourPubkey,
          30000,
          [
            const ['d', 'block'],
            const ['title', 'Block List'],
            for (final pk in blockedPubkeys) ['p', pk],
          ],
          'Block list',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        )
        ..id = 'own-block-event-${blockedPubkeys.length}'
        ..sig = 'signature';
    }

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockSigner = _MockBlockListSigner();
      controller = StreamController<Event>();

      when(
        () => mockNostrService.subscribe(
          any(),
        ),
      ).thenAnswer((_) => controller.stream);
    });

    tearDown(() async {
      await controller.close();
    });

    test(
      'restores blocks from own relay event when local blocklist is empty',
      () async {
        var changeCount = 0;
        service = ContentBlocklistRepository(onChanged: () => changeCount++);

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );

        controller.add(makeOwnBlockListEvent([blockedPubkey1, blockedPubkey2]));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(service.isBlocked(blockedPubkey1), isTrue);
        expect(service.isBlocked(blockedPubkey2), isTrue);
        expect(service.totalBlockedCount, equals(2));
        expect(changeCount, equals(1));
      },
    );

    test(
      'merges relay blocks with existing local blocks without duplicates',
      () async {
        var changeCount = 0;
        service = ContentBlocklistRepository(onChanged: () => changeCount++);

        // Pre-block one user locally
        await service.blockUser(blockedPubkey1, ourPubkey: ourPubkey);
        expect(service.totalBlockedCount, equals(1));
        changeCount = 0;

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );

        // Relay has both the already-local one and a new one
        controller.add(
          makeOwnBlockListEvent([blockedPubkey1, blockedPubkey2]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(service.isBlocked(blockedPubkey1), isTrue);
        expect(service.isBlocked(blockedPubkey2), isTrue);
        expect(service.totalBlockedCount, equals(2));
        expect(changeCount, equals(1));
      },
    );

    test(
      'does not notify when relay blocks already present locally',
      () async {
        var changeCount = 0;
        service = ContentBlocklistRepository(onChanged: () => changeCount++);

        await service.blockUser(blockedPubkey1, ourPubkey: ourPubkey);
        await service.blockUser(blockedPubkey2, ourPubkey: ourPubkey);
        changeCount = 0;

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );

        controller.add(
          makeOwnBlockListEvent([blockedPubkey1, blockedPubkey2]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(changeCount, equals(0));
        expect(service.totalBlockedCount, equals(2));
      },
    );

    test(
      'skips own pubkey in relay event p-tags',
      () async {
        service = ContentBlocklistRepository();

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );

        controller.add(makeOwnBlockListEvent([ourPubkey, blockedPubkey1]));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(service.isBlocked(blockedPubkey1), isTrue);
        expect(service.isBlocked(ourPubkey), isFalse);
        expect(service.totalBlockedCount, equals(1));
      },
    );

    test(
      'still detects others blocking us alongside own event restoration',
      () async {
        var changeCount = 0;
        service = ContentBlocklistRepository(onChanged: () => changeCount++);

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );

        // Our own block list arrives (restoration)
        controller.add(makeOwnBlockListEvent([blockedPubkey1]));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(service.isBlocked(blockedPubkey1), isTrue);
        expect(changeCount, equals(1));

        // Another user blocks us
        final othersEvent =
            Event(
                blockedPubkey2,
                30000,
                [
                  const ['d', 'block'],
                  ['p', ourPubkey],
                ],
                'Block list',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'others-block-event'
              ..sig = 'signature';

        controller.add(othersEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(service.hasBlockedUs(blockedPubkey2), isTrue);
        expect(changeCount, equals(2));
      },
    );
  });

  group('ContentBlocklistRepository - persistence', () {
    const blockedUsersKey = 'blocked_users_list';
    const severedFollowersKey = 'severed_followers_list';

    test('loads existing blocked users from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        blockedUsersKey: jsonEncode(['pubkey1', 'pubkey2']),
      });
      final prefs = await SharedPreferences.getInstance();

      final service = ContentBlocklistRepository(prefs: prefs);

      expect(service.isBlocked('pubkey1'), isTrue);
      expect(service.isBlocked('pubkey2'), isTrue);
      expect(service.totalBlockedCount, equals(2));
    });

    test('ignores corrupt blocked users JSON without throwing', () async {
      SharedPreferences.setMockInitialValues({
        blockedUsersKey: 'not valid json',
      });
      final prefs = await SharedPreferences.getInstance();

      final service = ContentBlocklistRepository(prefs: prefs);

      expect(service.totalBlockedCount, equals(0));
    });

    test('ignores corrupt muted authors JSON without throwing', () async {
      SharedPreferences.setMockInitialValues({
        'muted_users_list': 'not valid json',
      });
      final prefs = await SharedPreferences.getInstance();

      final service = ContentBlocklistRepository(prefs: prefs);

      expect(service.currentState.mutedPubkeys, isEmpty);
    });

    test('loads existing severed followers from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        severedFollowersKey: jsonEncode(['severed1']),
      });
      final prefs = await SharedPreferences.getInstance();

      final service = ContentBlocklistRepository(prefs: prefs);

      expect(service.isFollowSevered('severed1'), isTrue);
    });

    test('ignores corrupt severed followers JSON without throwing', () async {
      SharedPreferences.setMockInitialValues({
        severedFollowersKey: 'not valid json',
      });
      final prefs = await SharedPreferences.getInstance();

      final service = ContentBlocklistRepository(prefs: prefs);

      expect(service.isFollowSevered('anything'), isFalse);
    });

    test('persists blocked user and severed follower on blockUser', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.blockUser('pubkey1');

      final blockedJson = prefs.getString(blockedUsersKey);
      expect(blockedJson, isNotNull);
      expect(
        (jsonDecode(blockedJson!) as List).cast<String>(),
        contains('pubkey1'),
      );

      final severedJson = prefs.getString(severedFollowersKey);
      expect(severedJson, isNotNull);
      expect(
        (jsonDecode(severedJson!) as List).cast<String>(),
        contains('pubkey1'),
      );
    });

    test('continues when SharedPreferences.setString throws', () async {
      final mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenThrow(Exception('disk full'));

      final service = ContentBlocklistRepository(prefs: mockPrefs);

      // Should not rethrow even though setString fails for both
      // blocked_users_list and severed_followers_list writes.
      await service.blockUser('pubkey1');

      expect(service.isBlocked('pubkey1'), isTrue);
    });
  });

  group('ContentBlocklistRepository - severed followers', () {
    test('isFollowSevered returns true after blocking', () async {
      final service = ContentBlocklistRepository();
      await service.blockUser('pubkey1');

      expect(service.isFollowSevered('pubkey1'), isTrue);
    });

    test('isFollowSevered returns false for unknown pubkey', () {
      final service = ContentBlocklistRepository();

      expect(service.isFollowSevered('unknown'), isFalse);
    });

    test('removeSeveredFollower clears entry and persists', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.blockUser('pubkey1');
      expect(service.isFollowSevered('pubkey1'), isTrue);

      service.removeSeveredFollower('pubkey1');

      expect(service.isFollowSevered('pubkey1'), isFalse);
    });

    test('removeSeveredFollower is a no-op for unknown pubkey', () {
      final service = ContentBlocklistRepository()
        ..removeSeveredFollower('never_severed');

      expect(service.isFollowSevered('never_severed'), isFalse);
    });
  });

  group('ContentBlocklistRepository - getters and utility', () {
    test('blockedPubkeys exposes the combined runtime set', () async {
      final service = ContentBlocklistRepository();
      await service.blockUser('pubkey1');

      expect(service.blockedPubkeys, contains('pubkey1'));
    });

    test('isInternallyBlocked returns false (internal list is empty)', () {
      final service = ContentBlocklistRepository();

      expect(service.isInternallyBlocked('any_pubkey'), isFalse);
    });

    test('runtimeBlockedUsers is unmodifiable', () async {
      final service = ContentBlocklistRepository();
      await service.blockUser('pubkey1');

      expect(service.runtimeBlockedUsers, contains('pubkey1'));
      expect(
        () => service.runtimeBlockedUsers.add('pubkey2'),
        throwsUnsupportedError,
      );
    });

    test('clearRuntimeBlocks empties runtime blocks', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.blockUser('pubkey1');
      expect(service.totalBlockedCount, equals(1));

      service.clearRuntimeBlocks();

      expect(service.totalBlockedCount, equals(0));
    });

    test('clearRuntimeBlocks is a no-op when already empty', () {
      final service = ContentBlocklistRepository()..clearRuntimeBlocks();

      expect(service.totalBlockedCount, equals(0));
    });
  });

  group('feedHiddenPubkeys', () {
    const ourPubkey =
        '0000000000000000000000000000000000000000000000000000000000000001';
    const runtimeBlocked =
        '0000000000000000000000000000000000000000000000000000000000000002';
    const mutedByUs =
        '0000000000000000000000000000000000000000000000000000000000000003';
    const mutualMuter =
        '0000000000000000000000000000000000000000000000000000000000000004';
    const blockedByOther =
        '0000000000000000000000000000000000000000000000000000000000000005';
    const stranger =
        '0000000000000000000000000000000000000000000000000000000000000006';

    test('is empty when no hide bucket is populated', () {
      expect(ContentBlocklistRepository().feedHiddenPubkeys, isEmpty);
    });

    test(
      'unions every hide bucket and stays equivalent to shouldFilterFromFeeds',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final service = ContentBlocklistRepository(prefs: prefs);

        final muteController = StreamController<Event>();
        final blockController = StreamController<Event>();
        final mockMuteClient = _MockNostrClient();
        final mockBlockClient = _MockNostrClient();
        final mockSigner = _MockBlockListSigner();
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        // Runtime-block bucket.
        await service.blockUser(runtimeBlocked, ourPubkey: ourPubkey);

        // Own-mute + mutual-mute buckets, both via the kind 10000 stream.
        when(
          () => mockMuteClient.subscribe(any()),
        ).thenAnswer((_) => muteController.stream);
        await service.syncMuteListsInBackground(mockMuteClient, ourPubkey);
        muteController
          ..add(
            Event(
                ourPubkey,
                10000,
                [
                  ['p', mutedByUs],
                ],
                '',
                createdAt: now,
              )
              ..id = 'own-mute'
              ..sig = 'sig',
          )
          ..add(
            Event(
                mutualMuter,
                10000,
                [
                  ['p', ourPubkey],
                ],
                '',
                createdAt: now,
              )
              ..id = 'mutual-mute'
              ..sig = 'sig',
          );

        // Blocked-by bucket via the kind 30000 d=block stream.
        when(
          () => mockBlockClient.subscribe(any()),
        ).thenAnswer((_) => blockController.stream);
        when(() => mockBlockClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );
        when(() => mockSigner.isAuthenticated).thenReturn(false);
        await service.syncBlockListsInBackground(
          mockBlockClient,
          mockSigner,
          ourPubkey,
        );
        blockController.add(
          Event(
              blockedByOther,
              30000,
              [
                ['d', 'block'],
                ['p', ourPubkey],
              ],
              'Block list',
              createdAt: now,
            )
            ..id = 'blocked-by'
            ..sig = 'sig',
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        final hidden = service.feedHiddenPubkeys;
        expect(
          hidden,
          containsAll(<String>{
            runtimeBlocked,
            mutedByUs,
            mutualMuter,
            blockedByOther,
          }),
        );
        expect(hidden, isNot(contains(stranger)));

        // The set and the predicate must agree for every pubkey, so a future
        // sixth bucket added to one cannot silently diverge from the other.
        for (final pubkey in <String>{
          runtimeBlocked,
          mutedByUs,
          mutualMuter,
          blockedByOther,
          stranger,
        }) {
          expect(
            hidden.contains(pubkey),
            equals(service.shouldFilterFromFeeds(pubkey)),
            reason:
                'feedHiddenPubkeys and shouldFilterFromFeeds '
                'disagree for $pubkey',
          );
        }

        await muteController.close();
        await blockController.close();
      },
    );
  });

  group('ContentBlocklistRepository - Nostr publishing', () {
    late _MockNostrClient mockClient;
    late _MockBlockListSigner mockSigner;
    const ourPubkey =
        '0000000000000000000000000000000000000000000000000000000000000001';

    setUp(() {
      mockClient = _MockNostrClient();
      mockSigner = _MockBlockListSigner();
      when(
        () => mockClient.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockClient.queryEvents(any())).thenAnswer((_) async => []);
    });

    Event buildEvent({
      int kind = 30000,
      List<List<String>> tags = const <List<String>>[],
      String content = 'Block list',
      int? createdAt,
    }) {
      return Event(
          ourPubkey,
          kind,
          tags,
          content,
          createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        )
        ..id = 'test-event-id'
        ..sig = 'signature';
    }

    Event signedEventFromInvocation(Invocation invocation) {
      return buildEvent(
        kind: invocation.namedArguments[#kind] as int,
        content: invocation.namedArguments[#content] as String,
        tags: invocation.namedArguments[#tags] as List<List<String>>,
      );
    }

    test('does not publish when signer is not authenticated', () async {
      when(() => mockSigner.isAuthenticated).thenReturn(false);

      final service = ContentBlocklistRepository();
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      await service.blockUser('pubkey1');

      verifyNever(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );
    });

    test('blocking publishes the kind 10000 mute list with a p tag', () async {
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (invocation) async => signedEventFromInvocation(invocation),
      );
      when(
        () => mockClient.publishEvent(any()),
      ).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );

      final service = ContentBlocklistRepository();
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      await service.blockUser('pubkey1');

      // The interop fix (#4037): the blocked user lands on the standard
      // NIP-51 kind 10000 mute list, with no parameterized-list tags.
      final muteTags =
          verify(
                () => mockSigner.createAndSignEvent(
                  kind: 10000,
                  content: '',
                  tags: captureAny(named: 'tags'),
                ),
              ).captured.last
              as List<List<String>>;
      expect(muteTags, contains(equals(['p', 'pubkey1'])));
      expect(muteTags, isNot(contains(equals(['d', 'block']))));

      // The legacy kind 30000 block list is still kept in sync for older
      // Divine clients.
      final blockTags =
          verify(
                () => mockSigner.createAndSignEvent(
                  kind: 30000,
                  content: 'Block list',
                  tags: captureAny(named: 'tags'),
                ),
              ).captured.last
              as List<List<String>>;
      expect(blockTags, contains(equals(['d', 'block'])));
      expect(blockTags, contains(equals(['p', 'pubkey1'])));

      verify(() => mockClient.publishEvent(any())).called(2);
    });

    test('unblocking republishes the kind 10000 mute list without the '
        'user', () async {
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (invocation) async => signedEventFromInvocation(invocation),
      );
      when(
        () => mockClient.publishEvent(any()),
      ).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );

      final service = ContentBlocklistRepository();
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      await service.blockUser('pubkey1');
      await service.unblockUser('pubkey1');

      final lastMuteTags =
          verify(
                () => mockSigner.createAndSignEvent(
                  kind: 10000,
                  content: '',
                  tags: captureAny(named: 'tags'),
                ),
              ).captured.last
              as List<List<String>>;
      expect(lastMuteTags, isEmpty);
    });

    test('blocking preserves existing NIP-51 public tags and encrypted '
        'content', () async {
      const existingMute =
          '00000000000000000000000000000000000000000000000000000000000000cc';
      const blockedPubkey =
          '00000000000000000000000000000000000000000000000000000000000000dd';
      final existingEvent = buildEvent(
        kind: 10000,
        content: 'encrypted-private-tags',
        tags: const [
          ['p', existingMute, 'wss://relay.example'],
          ['t', 'spoilers'],
          ['word', 'spoiler'],
          ['e', 'event-thread-id'],
        ],
        createdAt: 1000,
      );
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockClient.queryEvents(any()),
      ).thenAnswer((_) async => [existingEvent]);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (invocation) async => signedEventFromInvocation(invocation),
      );
      when(
        () => mockClient.publishEvent(any()),
      ).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );

      final service = ContentBlocklistRepository();
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      await service.blockUser(blockedPubkey);

      final capturedMuteCall = verify(
        () => mockSigner.createAndSignEvent(
          kind: 10000,
          content: captureAny(named: 'content'),
          tags: captureAny(named: 'tags'),
        ),
      ).captured;
      final content = capturedMuteCall[0] as String;
      final tags = capturedMuteCall[1] as List<List<String>>;

      expect(content, 'encrypted-private-tags');
      expect(
        tags,
        contains(equals(['p', existingMute, 'wss://relay.example'])),
      );
      expect(tags, contains(equals(['p', blockedPubkey])));
      expect(tags, contains(equals(['t', 'spoilers'])));
      expect(tags, contains(equals(['word', 'spoiler'])));
      expect(tags, contains(equals(['e', 'event-thread-id'])));
    });

    test('blocking appends hydrated external p mutes before the latest source '
        'event is available', () async {
      const existingMute =
          '00000000000000000000000000000000000000000000000000000000000000cc';
      const blockedPubkey =
          '00000000000000000000000000000000000000000000000000000000000000dd';
      SharedPreferences.setMockInitialValues(<String, Object>{
        'muted_users_list': jsonEncode([existingMute]),
      });
      final prefs = await SharedPreferences.getInstance();
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (invocation) async => signedEventFromInvocation(invocation),
      );
      when(
        () => mockClient.publishEvent(any()),
      ).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );

      final service = ContentBlocklistRepository(prefs: prefs);
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      await service.blockUser(blockedPubkey);

      final tags =
          verify(
                () => mockSigner.createAndSignEvent(
                  kind: 10000,
                  content: any(named: 'content'),
                  tags: captureAny(named: 'tags'),
                ),
              ).captured.last
              as List<List<String>>;
      expect(tags, contains(equals(['p', existingMute])));
      expect(tags, contains(equals(['p', blockedPubkey])));
    });

    test(
      'unblocking preserves non-p mute-list tags and encrypted content',
      () async {
        const blockedPubkey =
            '00000000000000000000000000000000000000000000000000000000000000dd';
        final existingEvent = buildEvent(
          kind: 10000,
          content: 'encrypted-private-tags',
          tags: const [
            ['t', 'spoilers'],
            ['word', 'spoiler'],
            ['e', 'event-thread-id'],
          ],
          createdAt: 1000,
        );
        when(() => mockSigner.isAuthenticated).thenReturn(true);
        when(
          () => mockClient.queryEvents(any()),
        ).thenAnswer((_) async => [existingEvent]);
        when(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (invocation) async => signedEventFromInvocation(invocation),
        );
        when(
          () => mockClient.publishEvent(any()),
        ).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          ),
        );

        final service = ContentBlocklistRepository();
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );

        await service.blockUser(blockedPubkey);
        await service.unblockUser(blockedPubkey);

        final capturedMuteCalls = verify(
          () => mockSigner.createAndSignEvent(
            kind: 10000,
            content: captureAny(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;
        final lastContent =
            capturedMuteCalls[capturedMuteCalls.length - 2] as String;
        final lastTags =
            capturedMuteCalls[capturedMuteCalls.length - 1]
                as List<List<String>>;

        expect(lastContent, 'encrypted-private-tags');
        expect(lastTags, isNot(contains(equals(['p', blockedPubkey]))));
        expect(lastTags, contains(equals(['t', 'spoilers'])));
        expect(lastTags, contains(equals(['word', 'spoiler'])));
        expect(lastTags, contains(equals(['e', 'event-thread-id'])));
      },
    );

    test('tolerates publishEvent returning null', () async {
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => buildEvent());
      when(
        () => mockClient.publishEvent(any()),
      ).thenAnswer((_) async => const PublishFailed());

      final service = ContentBlocklistRepository();
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      // Should not throw even though publish returns null.
      await service.blockUser('pubkey1');

      expect(service.isBlocked('pubkey1'), isTrue);
    });

    test('swallows exceptions raised while signing the event', () async {
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenThrow(Exception('signing failure'));

      final service = ContentBlocklistRepository();
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      // Should not rethrow; blockUser still succeeds locally.
      await service.blockUser('pubkey1');

      expect(service.isBlocked('pubkey1'), isTrue);
    });
  });

  group('ContentBlocklistRepository - legacy block list migration', () {
    const ourPubkey =
        '0000000000000000000000000000000000000000000000000000000000000001';
    const blockA =
        '00000000000000000000000000000000000000000000000000000000000000aa';
    const blockB =
        '00000000000000000000000000000000000000000000000000000000000000bb';
    const muteC =
        '00000000000000000000000000000000000000000000000000000000000000cc';
    const flagKey = 'block_list_migrated_to_mute_list.$ourPubkey';

    late _MockNostrClient mockClient;
    late _MockBlockListSigner mockSigner;
    late SharedPreferences prefs;

    Event ownBlockEvent(List<String> blocked) =>
        Event(
            ourPubkey,
            30000,
            [
              const ['d', 'block'],
              for (final pk in blocked) ['p', pk],
            ],
            'Block list',
            createdAt: 1000,
          )
          ..id = 'own-block-event'
          ..sig = 'signature';

    Event ownMuteEvent(
      List<String> muted, {
      int createdAt = 2000,
      List<List<String>> extraTags = const <List<String>>[],
      String content = '',
    }) =>
        Event(
            ourPubkey,
            10000,
            [
              for (final pk in muted) ['p', pk],
              ...extraTags,
            ],
            content,
            createdAt: createdAt,
          )
          ..id = 'own-mute-event-$createdAt'
          ..sig = 'signature';

    Event signedMuteList({
      List<List<String>> tags = const <List<String>>[],
      String content = '',
    }) => Event(ourPubkey, 10000, tags, content, createdAt: 3000)
      ..id = 'signed-mute-list'
      ..sig = 'signature';

    Event signedMuteListFromInvocation(Invocation invocation) {
      return signedMuteList(
        content: invocation.namedArguments[#content] as String,
        tags: invocation.namedArguments[#tags] as List<List<String>>,
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      mockClient = _MockNostrClient();
      mockSigner = _MockBlockListSigner();
      when(
        () => mockClient.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockSigner.isAuthenticated).thenReturn(true);
    });

    test(
      'appends legacy kind 30000 blocks to the existing kind 10000 mute '
      'list and publishes once',
      () async {
        when(() => mockClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          final kinds = filters.first.kinds ?? const <int>[];
          if (kinds.contains(30000)) {
            return [
              ownBlockEvent([blockA, blockB]),
            ];
          }
          if (kinds.contains(10000)) {
            return [
              ownMuteEvent([muteC]),
            ];
          }
          return <Event>[];
        });

        List<List<String>>? publishedMuteTags;
        when(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final kind = invocation.namedArguments[#kind] as int;
          if (kind == 10000) {
            publishedMuteTags =
                invocation.namedArguments[#tags] as List<List<String>>?;
            return signedMuteListFromInvocation(invocation);
          }
          return signedMuteList();
        });
        when(
          () => mockClient.publishEvent(any()),
        ).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          ),
        );

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // The republished kind 10000 list carries the legacy blocks AND the
        // mute that already lived on the existing kind 10000 list.
        expect(publishedMuteTags, isNotNull);
        final publishedPubkeys = publishedMuteTags!
            .where((tag) => tag.length >= 2 && tag[0] == 'p')
            .map((tag) => tag[1])
            .toSet();
        expect(publishedPubkeys, containsAll(<String>{blockA, blockB, muteC}));

        expect(service.isBlocked(blockA), isTrue);
        expect(service.isBlocked(blockB), isTrue);
        expect(service.isMutedByUs(muteC), isTrue);
        expect(prefs.getBool(flagKey), isTrue);

        service.dispose();
      },
    );

    test(
      'leaves the flag unset without publishing when there is no legacy list',
      () async {
        when(
          () => mockClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verifyNever(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
        expect(prefs.getBool(flagKey), isNull);

        service.dispose();
      },
    );

    test('does not run again once the migration flag is set', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{flagKey: true});
      prefs = await SharedPreferences.getInstance();

      final service = ContentBlocklistRepository(prefs: prefs);
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verifyNever(() => mockClient.queryEvents(any()));

      service.dispose();
    });

    test('keeps the flag unset when the republish is rejected', () async {
      when(() => mockClient.queryEvents(any())).thenAnswer((invocation) async {
        final filters = invocation.positionalArguments[0] as List<Filter>;
        final kinds = filters.first.kinds ?? const <int>[];
        if (kinds.contains(30000)) {
          return [
            ownBlockEvent([blockA]),
          ];
        }
        return <Event>[];
      });
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedMuteList());
      when(
        () => mockClient.publishEvent(any()),
      ).thenAnswer((_) async => const PublishFailed());

      final service = ContentBlocklistRepository(prefs: prefs);
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Migration retries next launch, but the block is real and already
      // applied locally.
      expect(prefs.getBool(flagKey), isNull);
      expect(service.isBlocked(blockA), isTrue);

      service.dispose();
    });

    test(
      'merges the newest kind 10000 event when several exist',
      () async {
        const muteD =
            '00000000000000000000000000000000000000000000000000000000000000dd';
        when(() => mockClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          final kinds = filters.first.kinds ?? const <int>[];
          if (kinds.contains(30000)) {
            return [
              ownBlockEvent([blockA]),
            ];
          }
          if (kinds.contains(10000)) {
            // Older event first, newer second: the newest one wins so only
            // its mutes survive into the republished list.
            return [
              ownMuteEvent([muteC], createdAt: 1500),
              ownMuteEvent([muteD], createdAt: 5000),
            ];
          }
          return <Event>[];
        });

        List<List<String>>? publishedMuteTags;
        when(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final kind = invocation.namedArguments[#kind] as int;
          if (kind == 10000) {
            publishedMuteTags =
                invocation.namedArguments[#tags] as List<List<String>>?;
            return signedMuteListFromInvocation(invocation);
          }
          return signedMuteList();
        });
        when(
          () => mockClient.publishEvent(any()),
        ).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          ),
        );

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final publishedPubkeys = publishedMuteTags!
            .where((tag) => tag.length >= 2 && tag[0] == 'p')
            .map((tag) => tag[1])
            .toSet();
        expect(publishedPubkeys, containsAll(<String>{blockA, muteD}));
        expect(publishedPubkeys, isNot(contains(muteC)));
        expect(service.isMutedByUs(muteD), isTrue);
        expect(service.isMutedByUs(muteC), isFalse);

        service.dispose();
      },
    );

    test(
      'migration preserves existing non-p mute tags and encrypted content',
      () async {
        when(() => mockClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          final kinds = filters.first.kinds ?? const <int>[];
          if (kinds.contains(30000)) {
            return [
              ownBlockEvent([blockA]),
            ];
          }
          if (kinds.contains(10000)) {
            return [
              ownMuteEvent(
                [muteC],
                content: 'encrypted-private-tags',
                extraTags: const [
                  ['t', 'spoilers'],
                  ['word', 'spoiler'],
                  ['e', 'event-thread-id'],
                ],
              ),
            ];
          }
          return <Event>[];
        });

        List<List<String>>? publishedMuteTags;
        String? publishedContent;
        when(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final kind = invocation.namedArguments[#kind] as int;
          if (kind == 10000) {
            publishedContent = invocation.namedArguments[#content] as String;
            publishedMuteTags =
                invocation.namedArguments[#tags] as List<List<String>>?;
            return signedMuteListFromInvocation(invocation);
          }
          return signedMuteList();
        });
        when(
          () => mockClient.publishEvent(any()),
        ).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          ),
        );

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(publishedContent, 'encrypted-private-tags');
        expect(publishedMuteTags, isNotNull);
        expect(publishedMuteTags, contains(equals(['p', blockA])));
        expect(publishedMuteTags, contains(equals(['p', muteC])));
        expect(publishedMuteTags, contains(equals(['t', 'spoilers'])));
        expect(publishedMuteTags, contains(equals(['word', 'spoiler'])));
        expect(publishedMuteTags, contains(equals(['e', 'event-thread-id'])));

        service.dispose();
      },
    );

    test(
      'swallows errors and leaves the flag unset on query failure',
      () async {
        when(
          () => mockClient.queryEvents(any()),
        ).thenThrow(Exception('relay unavailable'));

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // The failure is caught; migration retries on the next launch.
        expect(prefs.getBool(flagKey), isNull);
        verifyNever(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );

        service.dispose();
      },
    );
  });

  group('ContentBlocklistRepository - sync edge cases', () {
    late _MockNostrClient mockClient1;
    late _MockNostrClient mockClient2;
    late _MockBlockListSigner mockSigner;
    const ourPubkey = 'our_pubkey';

    setUp(() {
      mockClient1 = _MockNostrClient();
      mockClient2 = _MockNostrClient();
      mockSigner = _MockBlockListSigner();
      when(
        () => mockClient1.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockClient2.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());
    });

    test(
      'syncMuteListsInBackground re-subscribes when client changes',
      () async {
        final service = ContentBlocklistRepository();

        await service.syncMuteListsInBackground(mockClient1, ourPubkey);
        await service.syncMuteListsInBackground(mockClient2, ourPubkey);

        verify(() => mockClient1.subscribe(any())).called(1);
        verify(() => mockClient2.subscribe(any())).called(1);
      },
    );

    test('syncMuteListsInBackground swallows subscribe errors', () async {
      when(
        () => mockClient1.subscribe(any()),
      ).thenThrow(Exception('connection failed'));

      final service = ContentBlocklistRepository();

      await service.syncMuteListsInBackground(mockClient1, ourPubkey);

      // Sync did not mark itself as started, so a second client is allowed.
      await service.syncMuteListsInBackground(mockClient2, ourPubkey);
      verify(() => mockClient2.subscribe(any())).called(1);
    });

    test('syncBlockListsInBackground skips when already started', () async {
      final service = ContentBlocklistRepository();

      await service.syncBlockListsInBackground(
        mockClient1,
        mockSigner,
        ourPubkey,
      );
      await service.syncBlockListsInBackground(
        mockClient1,
        mockSigner,
        ourPubkey,
      );

      verify(() => mockClient1.subscribe(any())).called(1);
    });

    test(
      'syncBlockListsInBackground re-subscribes when client changes',
      () async {
        final service = ContentBlocklistRepository();

        await service.syncBlockListsInBackground(
          mockClient1,
          mockSigner,
          ourPubkey,
        );
        await service.syncBlockListsInBackground(
          mockClient2,
          mockSigner,
          ourPubkey,
        );

        verify(() => mockClient1.subscribe(any())).called(1);
        verify(() => mockClient2.subscribe(any())).called(1);
      },
    );

    test('syncBlockListsInBackground swallows subscribe errors', () async {
      when(
        () => mockClient1.subscribe(any()),
      ).thenThrow(Exception('connection failed'));

      final service = ContentBlocklistRepository();

      await service.syncBlockListsInBackground(
        mockClient1,
        mockSigner,
        ourPubkey,
      );

      // Sync is not marked as started, so a second client is allowed.
      await service.syncBlockListsInBackground(
        mockClient2,
        mockSigner,
        ourPubkey,
      );
      verify(() => mockClient2.subscribe(any())).called(1);
    });
  });

  group('ContentBlocklistRepository - event handler guards', () {
    test('_handleMuteListEvent ignores non-10000 events', () async {
      final mockClient = _MockNostrClient();
      final controller = StreamController<Event>();
      when(
        () => mockClient.subscribe(any()),
      ).thenAnswer((_) => controller.stream);

      final service = ContentBlocklistRepository();
      await service.syncMuteListsInBackground(mockClient, 'our_pubkey');

      const muterPubkey =
          '0000000000000000000000000000000000000000000000000000000000000002';
      final wrongKind =
          Event(
              muterPubkey,
              1,
              const [],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            )
            ..id = 'wrong-kind-event'
            ..sig = 'signature';

      controller.add(wrongKind);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.hasMutedUs(muterPubkey), isFalse);

      await controller.close();
    });
  });

  group('ContentBlocklistRepository - dispose', () {
    test('dispose resets sync flags so a fresh sync can start', () async {
      final mockClient = _MockNostrClient();
      final mockSigner = _MockBlockListSigner();
      when(
        () => mockClient.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());

      final service = ContentBlocklistRepository();
      await service.syncMuteListsInBackground(mockClient, 'our_pubkey');
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        'our_pubkey',
      );

      service.dispose();

      // After dispose the flags are cleared, so another sync pair
      // subscribes again on the same client.
      await service.syncMuteListsInBackground(mockClient, 'our_pubkey');
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        'our_pubkey',
      );

      verify(() => mockClient.subscribe(any())).called(4);
    });
  });

  group('ContentPolicyState exposure', () {
    test('currentState reflects blocked set after blockUser', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ContentBlocklistRepository(prefs: prefs);

      const me = 'my-hex-pubkey';
      const blockedByUs = 'blocked-hex';
      await repo.blockUser(blockedByUs, ourPubkey: me);

      final state = repo.currentState;
      expect(state.blockedPubkeys, contains(blockedByUs));
      expect(state.mutedPubkeys, isEmpty);
      expect(state.pubkeysBlockingUs, isEmpty);
      expect(state.pubkeysMutingUs, isEmpty);
    });

    test('stateStream emits a new snapshot when blocks change', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ContentBlocklistRepository(prefs: prefs);

      const blocked = 'some-hex';
      final snapshots = <ContentPolicyState>[];
      final sub = repo.stateStream.listen(snapshots.add);

      await repo.blockUser(blocked, ourPubkey: 'me');
      await Future<void>.delayed(Duration.zero);

      expect(snapshots, hasLength(greaterThanOrEqualTo(1)));
      expect(snapshots.last.blockedPubkeys, contains(blocked));

      await sub.cancel();
    });

    test('currentState reflects persisted blocks at construction', () async {
      SharedPreferences.setMockInitialValues({
        'blocked_users_list': '["persisted-hex"]',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = ContentBlocklistRepository(prefs: prefs);

      expect(repo.currentState.blockedPubkeys, contains('persisted-hex'));
    });
  });
}
