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
          BlocklistOp.blockedUs,
        ];
        const removals = [
          BlocklistOp.unblocked,
          BlocklistOp.unmuted,
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
      'syncMuteListsInBackground subscribes to kind 10000 with our pubkey',
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
        expect(capturedFilters!.length, equals(1));

        final filter = capturedFilters![0] as Filter;
        expect(filter.kinds, contains(10000));
        expect(filter.p, contains(ourPubkey));
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
    });

    Event buildEvent() {
      return Event(
          ourPubkey,
          30000,
          const <List<String>>[],
          'Block list',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        )
        ..id = 'test-event-id'
        ..sig = 'signature';
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

    test('publishes block list with p tag for each blocked user', () async {
      final event = buildEvent();
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => event);
      when(() => mockClient.publishEvent(any())).thenAnswer((_) async => event);

      final service = ContentBlocklistRepository();
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      await service.blockUser('pubkey1');

      final tagsList =
          verify(
                () => mockSigner.createAndSignEvent(
                  kind: 30000,
                  content: 'Block list',
                  tags: captureAny(named: 'tags'),
                ),
              ).captured.last
              as List<List<String>>;

      expect(tagsList, contains(equals(['d', 'block'])));
      expect(tagsList, contains(equals(['p', 'pubkey1'])));
      verify(() => mockClient.publishEvent(event)).called(1);
    });

    test('tolerates publishEvent returning null', () async {
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => buildEvent());
      when(() => mockClient.publishEvent(any())).thenAnswer((_) async => null);

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
