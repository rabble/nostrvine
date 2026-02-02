// ABOUTME: Tests for search filtering of blocked users
// ABOUTME: Verifies that blocked users' content doesn't appear in search results

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/content_blocklist_service.dart';

class MockContentBlocklistService extends Mock
    implements ContentBlocklistService {}

void main() {
  group('Search Blocklist Filtering', () {
    late ContentBlocklistService blocklistService;

    setUp(() {
      blocklistService = ContentBlocklistService();
    });

    test('shouldFilterFromFeeds returns true for blocked users', () {
      const blockedPubkey = 'blocked_user_pubkey_hex';

      // Block the user
      blocklistService.blockUser(blockedPubkey);

      // Verify they should be filtered
      expect(
        blocklistService.shouldFilterFromFeeds(blockedPubkey),
        isTrue,
        reason: 'Blocked users should be filtered from feeds and search',
      );
    });

    test('shouldFilterFromFeeds returns false for non-blocked users', () {
      const normalPubkey = 'normal_user_pubkey_hex';

      // Verify non-blocked users are not filtered
      expect(
        blocklistService.shouldFilterFromFeeds(normalPubkey),
        isFalse,
        reason: 'Non-blocked users should not be filtered',
      );
    });

    test('filterContent removes blocked users content', () {
      const blockedPubkey = 'blocked_user_pubkey';
      const normalPubkey1 = 'normal_user_1_pubkey';
      const normalPubkey2 = 'normal_user_2_pubkey';

      // Block one user
      blocklistService.blockUser(blockedPubkey);

      // Create mock content items
      final contentItems = [
        {'id': '1', 'pubkey': normalPubkey1},
        {'id': '2', 'pubkey': blockedPubkey},
        {'id': '3', 'pubkey': normalPubkey2},
        {'id': '4', 'pubkey': blockedPubkey},
      ];

      // Filter content
      final filteredContent = blocklistService.filterContent(
        contentItems,
        (item) => item['pubkey']!,
      );

      // Verify only non-blocked content remains
      expect(filteredContent.length, equals(2));
      expect(
        filteredContent.every((item) => item['pubkey'] != blockedPubkey),
        isTrue,
        reason: 'Filtered content should not contain blocked user items',
      );
    });

    test('runtimeBlockedUsers returns set of blocked pubkeys', () {
      const pubkey1 = 'blocked_pubkey_1';
      const pubkey2 = 'blocked_pubkey_2';

      blocklistService.blockUser(pubkey1);
      blocklistService.blockUser(pubkey2);

      final blockedUsers = blocklistService.runtimeBlockedUsers;

      expect(blockedUsers.contains(pubkey1), isTrue);
      expect(blockedUsers.contains(pubkey2), isTrue);
    });

    test('unblockUser removes user from runtimeBlockedUsers', () {
      const pubkey = 'user_to_unblock';

      // Block then unblock
      blocklistService.blockUser(pubkey);
      expect(blocklistService.runtimeBlockedUsers.contains(pubkey), isTrue);

      blocklistService.unblockUser(pubkey);
      expect(blocklistService.runtimeBlockedUsers.contains(pubkey), isFalse);

      // Should no longer be filtered
      expect(blocklistService.shouldFilterFromFeeds(pubkey), isFalse);
    });
  });
}
