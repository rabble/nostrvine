import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:nostr_client/nostr_client.dart';

import 'content_blocklist_service_test.mocks.dart';

@GenerateMocks([NostrClient])
void main() {
  group('ContentBlocklistService', () {
    late ContentBlocklistService service;

    setUp(() {
      service = ContentBlocklistService();
    });

    test('should initialize with no hardcoded blocked accounts', () {
      // Moderation should happen at relay level, not hardcoded in app
      expect(service.totalBlockedCount, equals(0));
    });

    test('should block users at runtime', () {
      const testPubkey1 = 'pubkey_to_block_1';
      const testPubkey2 = 'pubkey_to_block_2';

      // Initially no blocks
      expect(service.totalBlockedCount, equals(0));
      expect(service.isBlocked(testPubkey1), isFalse);
      expect(service.isBlocked(testPubkey2), isFalse);

      // Block users at runtime
      service.blockUser(testPubkey1);
      service.blockUser(testPubkey2);

      expect(service.totalBlockedCount, equals(2));
      expect(service.isBlocked(testPubkey1), isTrue);
      expect(service.isBlocked(testPubkey2), isTrue);
    });

    test('should filter blocked content from feeds', () {
      const blockedPubkey = 'blocked_user_pubkey';
      const allowedPubkey = 'allowed_user_pubkey';

      // Block a user first
      service.blockUser(blockedPubkey);

      expect(service.shouldFilterFromFeeds(blockedPubkey), isTrue);
      expect(service.shouldFilterFromFeeds(allowedPubkey), isFalse);
    });

    test('should allow runtime blocking and unblocking', () {
      const testPubkey = 'test_pubkey_for_runtime_blocking';

      // Initially not blocked
      expect(service.isBlocked(testPubkey), isFalse);

      // Block user
      service.blockUser(testPubkey);
      expect(service.isBlocked(testPubkey), isTrue);

      // Unblock user
      service.unblockUser(testPubkey);
      expect(service.isBlocked(testPubkey), isFalse);
    });

    test('should filter content list correctly', () {
      const blockedPubkey1 = 'blocked_pubkey_1';
      const blockedPubkey2 = 'blocked_pubkey_2';

      // Block users first
      service.blockUser(blockedPubkey1);
      service.blockUser(blockedPubkey2);

      final testItems = [
        {'pubkey': blockedPubkey1, 'content': 'blocked'},
        {'pubkey': 'allowed_user', 'content': 'allowed'},
        {'pubkey': blockedPubkey2, 'content': 'blocked2'},
      ];

      final filtered = service.filterContent(
        testItems,
        (item) => item['pubkey'] as String,
      );

      expect(filtered.length, equals(1));
      expect(filtered.first['content'], equals('allowed'));
    });

    test('should provide blocking stats', () {
      final stats = service.blockingStats;

      expect(stats['total_blocks'], isA<int>());
      expect(stats['runtime_blocks'], isA<int>());
      expect(stats['internal_blocks'], isA<int>());
    });

    group('self-block prevention', () {
      test('blockUser() ignores when pubkey matches ourPubkey parameter', () {
        const ourPubkey = 'test_our_pubkey';

        service.blockUser(ourPubkey, ourPubkey: ourPubkey);

        expect(service.isBlocked(ourPubkey), isFalse);
        expect(service.totalBlockedCount, equals(0));
      });

      test('blockUser() allows blocking other users', () {
        const ourPubkey = 'our_pubkey';
        const otherPubkey = 'other_pubkey';

        service.blockUser(otherPubkey, ourPubkey: ourPubkey);

        expect(service.isBlocked(otherPubkey), isTrue);
        expect(service.totalBlockedCount, equals(1));
      });

      test('blockUser() allows blocking when ourPubkey is null', () {
        const otherPubkey = 'other_pubkey';

        // No ourPubkey provided - should allow blocking
        service.blockUser(otherPubkey);

        expect(service.isBlocked(otherPubkey), isTrue);
        expect(service.totalBlockedCount, equals(1));
      });
    });
  });

  group('ContentBlocklistService - Mutual Mute Sync', () {
    late ContentBlocklistService service;
    late MockNostrClient mockNostrService;

    setUp(() {
      service = ContentBlocklistService();
      mockNostrService = MockNostrClient();
    });

    test(
      'syncMuteListsInBackground subscribes to kind 10000 with our pubkey',
      () async {
        const ourPubkey = 'test_our_pubkey_hex';

        List<dynamic>? capturedFilters;
        when(mockNostrService.subscribe(argThat(anything))).thenAnswer((
          invocation,
        ) {
          capturedFilters = invocation.positionalArguments[0] as List;
          return Stream.empty();
        });

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        // Verify subscribeToEvents was called
        verify(mockNostrService.subscribe(argThat(anything))).called(1);

        expect(capturedFilters, isNotNull);
        expect(capturedFilters!.length, equals(1));

        final filter = capturedFilters![0];
        expect(filter.kinds, contains(10000));
        expect(filter.p, contains(ourPubkey));
      },
    );

    test('syncMuteListsInBackground only subscribes once', () async {
      const ourPubkey = 'test_our_pubkey_hex';

      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => Stream.empty());

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

      // Should only subscribe once
      verify(mockNostrService.subscribe(argThat(anything))).called(1);
    });

    test(
      'handleMuteListEvent adds muter to blocklist when our pubkey is in tags',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const muterPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';

        // Create a kind 10000 event with our pubkey in the 'p' tags
        final event = Event(
          muterPubkey,
          10000,
          [
            ['p', ourPubkey],
            ['p', 'some_other_pubkey'],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        event.id = 'event-id';
        event.sig = 'signature';

        when(
          mockNostrService.subscribe(argThat(anything)),
        ).thenAnswer((_) => Stream.fromIterable([event]));

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        // Give the stream time to emit
        await Future.delayed(const Duration(milliseconds: 100));

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
        final muteEvent = Event(
          muterPubkey,
          10000,
          [
            ['p', ourPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        muteEvent.id = 'event-id-1';
        muteEvent.sig = 'signature';

        // Second event: muter removes us from their list (replaceable event)
        final unmuteEvent = Event(
          muterPubkey,
          10000,
          [
            ['p', 'some_other_pubkey'], // Our pubkey is gone
          ],
          '',
          createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 60,
        );
        unmuteEvent.id = 'event-id-2';
        unmuteEvent.sig = 'signature';

        // Create a stream controller to manually emit events
        final controller = StreamController<Event>();

        when(
          mockNostrService.subscribe(argThat(anything)),
        ).thenAnswer((_) => controller.stream);

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        // First event - adds to blocklist
        controller.add(muteEvent);
        await Future.delayed(const Duration(milliseconds: 50));
        expect(service.shouldFilterFromFeeds(muterPubkey), isTrue);

        // Second event - removes from blocklist
        controller.add(unmuteEvent);
        await Future.delayed(const Duration(milliseconds: 50));
        expect(service.shouldFilterFromFeeds(muterPubkey), isFalse);

        controller.close();
      },
    );

    test('shouldFilterFromFeeds checks mutual mute blocklist', () async {
      const ourPubkey =
          '0000000000000000000000000000000000000000000000000000000000000001';
      const muterPubkey =
          '0000000000000000000000000000000000000000000000000000000000000002';
      const randomPubkey =
          '0000000000000000000000000000000000000000000000000000000000000003';

      final event = Event(
        muterPubkey,
        10000,
        [
          ['p', ourPubkey],
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event.id = 'event-id';
      event.sig = 'signature';

      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => Stream.fromIterable([event]));

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

      // Give the stream time to emit
      await Future.delayed(const Duration(milliseconds: 100));

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

        final event = Event(
          muterPubkey,
          10000,
          [
            ['p', ourPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        event.id = 'event-id';
        event.sig = 'signature';

        when(
          mockNostrService.subscribe(argThat(anything)),
        ).thenAnswer((_) => Stream.fromIterable([event]));

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        // Give the stream time to emit
        await Future.delayed(const Duration(milliseconds: 100));

        // Block a user ourselves
        service.blockUser(blockedByUsPubkey);

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
}
