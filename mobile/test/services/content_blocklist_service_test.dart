import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/content_blocklist_service.dart';

void main() {
  group('ContentBlocklistService', () {
    late ContentBlocklistService service;

    setUp(() {
      service = ContentBlocklistService();
    });

    test('should initialize with blocked accounts', () {
      expect(service.totalBlockedCount, greaterThan(0));
    });

    test('should block specified npubs', () {
      // The service should have blocked the specified users (3 npubs)
      expect(service.totalBlockedCount, equals(3));
      
      // Verify the specific hex keys are blocked (correct values from bech32 decoding)
      const expectedHex1 = '7444faae22d4d4939c815819dca3c4822c209758bf86afc66365db5f79f67ddb';
      const expectedHex2 = '2df7fab5ab8eb77572b1a64221b68056cefbccd16fa370d33a5fbeade3debe5f';
      const expectedHex3 = '5943c88f3c60cd9edb125a668e2911ad419fc04e94549ed96a721901dd958372';
      
      expect(service.isBlocked(expectedHex1), isTrue);
      expect(service.isBlocked(expectedHex2), isTrue);
      expect(service.isBlocked(expectedHex3), isTrue);
    });

    test('should filter blocked content from feeds', () {
      const blockedPubkey = '7444faae22d4d4939c815819dca3c4822c209758bf86afc66365db5f79f67ddb';
      const allowedPubkey = 'allowed_user_pubkey';
      
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
      final testItems = [
        {'pubkey': '7444faae22d4d4939c815819dca3c4822c209758bf86afc66365db5f79f67ddb', 'content': 'blocked'},
        {'pubkey': 'allowed_user', 'content': 'allowed'},
        {'pubkey': '2df7fab5ab8eb77572b1a64221b68056cefbccd16fa370d33a5fbeade3debe5f', 'content': 'blocked2'},
      ];

      final filtered = service.filterContent(testItems, (item) => item['pubkey'] as String);
      
      expect(filtered.length, equals(1));
      expect(filtered.first['content'], equals('allowed'));
    });

    test('should provide blocking stats', () {
      final stats = service.blockingStats;
      
      expect(stats['total_blocks'], isA<int>());
      expect(stats['runtime_blocks'], isA<int>());
      expect(stats['internal_blocks'], isA<int>());
    });
  });
}