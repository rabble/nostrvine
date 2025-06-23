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
      // The service should have blocked the specified users (2 npubs)
      expect(service.totalBlockedCount, equals(2));
      
      // Verify the specific hex keys are blocked (from mapping table)
      const expectedHex1 = 'e6e7a2c0e18b0a0c2b1a5f5e9b0c8d5a6f1e8c7b4d9a2f5e8c7b6d3a0e1f4c9b5';
      const expectedHex2 = '2bfdb6eb6bd4debd24ad568fe9e8e835e76de1b5f73e7b6d5fc85fa373d0a029';
      
      expect(service.isBlocked(expectedHex1), isTrue);
      expect(service.isBlocked(expectedHex2), isTrue);
    });

    test('should filter blocked content from feeds', () {
      const blockedPubkey = 'e6e7a2c0e18b0a0c2b1a5f5e9b0c8d5a6f1e8c7b4d9a2f5e8c7b6d3a0e1f4c9b5';
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
        {'pubkey': 'e6e7a2c0e18b0a0c2b1a5f5e9b0c8d5a6f1e8c7b4d9a2f5e8c7b6d3a0e1f4c9b5', 'content': 'blocked'},
        {'pubkey': 'allowed_user', 'content': 'allowed'},
        {'pubkey': '2bfdb6eb6bd4debd24ad568fe9e8e835e76de1b5f73e7b6d5fc85fa373d0a029', 'content': 'blocked2'},
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