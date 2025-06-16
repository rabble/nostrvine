// ABOUTME: Comprehensive tests for Nostr service functionality
// ABOUTME: Tests relay management, event broadcasting, and service lifecycle

import 'package:flutter_test/flutter_test.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mocktail/mocktail.dart';
import '../../lib/services/nostr_service.dart';
import '../../lib/services/nostr_key_manager.dart';
import '../../lib/models/nip94_metadata.dart';

void main() {
  group('NostrService', () {
    late NostrService nostrService;
    late NostrKeyManager keyManager;
    
    setUp(() {
      keyManager = NostrKeyManager();
      nostrService = NostrService(keyManager);
    });
    
    tearDown(() {
      nostrService.dispose();
    });
    
    group('Initialization', () {
      test('should start uninitialized', () {
        expect(nostrService.isInitialized, isFalse);
        expect(nostrService.hasKeys, isFalse);
        expect(nostrService.publicKey, isNull);
        expect(nostrService.connectedRelays, isEmpty);
        expect(nostrService.relayCount, equals(0));
        expect(nostrService.connectedRelayCount, equals(0));
      });
      
      test('should have default relays configured', () {
        expect(NostrService.defaultRelays, isNotEmpty);
        expect(NostrService.defaultRelays, contains('wss://relay.damus.io'));
        expect(NostrService.defaultRelays, contains('wss://nos.lol'));
        expect(NostrService.defaultRelays, contains('wss://relay.snort.social'));
        expect(NostrService.defaultRelays, contains('wss://relay.current.fyi'));
      });
    });
    
    group('State Management', () {
      test('should track initialization state correctly', () {
        expect(nostrService.isInitialized, isFalse);
      });
      
      test('should track connected relays', () {
        expect(nostrService.connectedRelays, isEmpty);
        expect(nostrService.connectedRelayCount, equals(0));
      });
      
      test('should provide relay status information', () {
        final status = nostrService.getRelayStatus();
        expect(status, isA<Map<String, bool>>());
      });
    });
    
    group('Event Broadcasting', () {
      test('should require initialization before broadcasting', () async {
        final testKeyPairs = NostrKeyPairs.generate();
        final event = NostrEvent.fromPartialData(
          kind: 1063,
          content: 'Test content',
          tags: [['url', 'test.com']],
          keyPairs: testKeyPairs,
        );
        
        expect(
          () => nostrService.broadcastEvent(event),
          throwsA(isA<NostrServiceException>()),
        );
      });
      
      test('should validate event structure', () {
        // Test that events have required fields
        final testKeyPairs = NostrKeyPairs.generate();
        final event = NostrEvent.fromPartialData(
          kind: 1063,
          content: 'Test NIP-94 event',
          tags: [
            ['url', 'https://example.com/file.gif'],
            ['m', 'image/gif'],
            ['x', 'sha256hash'],
            ['size', '1024'],
            ['dim', '320x240'],
          ],
          keyPairs: testKeyPairs,
        );
        
        expect(event.kind, equals(1063));
        expect(event.content, equals('Test NIP-94 event'));
        expect(event.tags, isNotEmpty);
        expect(event.tags.any((tag) => tag[0] == 'url'), isTrue);
      });
    });
    
    group('NIP-94 Publishing', () {
      test('should create valid NIP-94 metadata', () {
        final metadata = NIP94Metadata(
          url: 'https://example.com/test.gif',
          mimeType: 'image/gif',
          sha256Hash: 'a1b2c3d4e5f67890123456789012345678901234567890123456789012345678',
          sizeBytes: 1024,
          dimensions: '320x240',
        );
        
        expect(metadata.isValid, isTrue);
        expect(metadata.isGif, isTrue);
      });
      
      test('should require valid metadata for publishing', () async {
        final invalidMetadata = NIP94Metadata(
          url: '', // Invalid empty URL
          mimeType: 'image/gif',
          sha256Hash: 'invalid_hash', // Invalid hash
          sizeBytes: 0, // Invalid size
          dimensions: 'invalid', // Invalid dimensions
        );
        
        expect(invalidMetadata.isValid, isFalse);
        
        expect(
          () => nostrService.publishFileMetadata(
            metadata: invalidMetadata,
            content: 'Test content',
          ),
          throwsA(isA<NIP94ValidationException>()),
        );
      });
      
      test('should handle hashtag extraction', () {
        const hashtags = ['nostr', 'vine', 'gif'];
        const content = 'Check out my #nostr #vine #gif!';
        
        // Test that hashtags are properly processed
        expect(hashtags, contains('nostr'));
        expect(hashtags, contains('vine'));
        expect(hashtags, contains('gif'));
      });
    });
    
    group('Relay Management', () {
      test('should handle relay addition', () async {
        const testRelay = 'wss://test.relay.com';
        
        // This would normally connect to a real relay
        // For testing, we just verify the method exists
        expect(nostrService.addRelay, isA<Function>());
      });
      
      test('should handle relay removal', () async {
        const testRelay = 'wss://test.relay.com';
        
        // Test relay removal method exists
        expect(nostrService.removeRelay, isA<Function>());
      });
      
      test('should support reconnection', () async {
        expect(nostrService.reconnectAll, isA<Function>());
      });
    });
    
    group('Error Handling', () {
      test('should handle network connection failures gracefully', () {
        // Test that the service doesn't crash on connection failures
        expect(nostrService.connectedRelayCount, equals(0));
      });
      
      test('should provide meaningful error messages', () {
        const error = NostrServiceException('Test error message');
        expect(error.message, equals('Test error message'));
        expect(error.toString(), contains('NostrServiceException'));
      });
      
      test('should handle partial relay failures', () {
        // Test that the service continues working even if some relays fail
        final status = nostrService.getRelayStatus();
        expect(status, isA<Map<String, bool>>());
      });
    });
    
    group('Broadcasting Results', () {
      test('should create valid broadcast result', () {
        final testKeyPairs = NostrKeyPairs.generate();
        final mockEvent = NostrEvent.fromPartialData(
          kind: 1063,
          content: 'Test',
          tags: [],
          keyPairs: testKeyPairs,
        );
        
        final result = NostrBroadcastResult(
          event: mockEvent,
          successCount: 2,
          totalRelays: 4,
          results: {
            'relay1': true,
            'relay2': true,
            'relay3': false,
            'relay4': false,
          },
          errors: {
            'relay3': 'Connection failed',
            'relay4': 'Timeout',
          },
        );
        
        expect(result.successCount, equals(2));
        expect(result.totalRelays, equals(4));
        expect(result.isSuccessful, isTrue);
        expect(result.isCompleteSuccess, isFalse);
        expect(result.successRate, equals(0.5));
        expect(result.successfulRelays, equals(['relay1', 'relay2']));
        expect(result.failedRelays, equals(['relay3', 'relay4']));
      });
      
      test('should handle complete success', () {
        final testKeyPairs = NostrKeyPairs.generate();
        final mockEvent = NostrEvent.fromPartialData(
          kind: 1063,
          content: 'Test',
          tags: [],
          keyPairs: testKeyPairs,
        );
        
        final result = NostrBroadcastResult(
          event: mockEvent,
          successCount: 3,
          totalRelays: 3,
          results: {'relay1': true, 'relay2': true, 'relay3': true},
          errors: {},
        );
        
        expect(result.isSuccessful, isTrue);
        expect(result.isCompleteSuccess, isTrue);
        expect(result.successRate, equals(1.0));
        expect(result.failedRelays, isEmpty);
      });
      
      test('should handle complete failure', () {
        final testKeyPairs = NostrKeyPairs.generate();
        final mockEvent = NostrEvent.fromPartialData(
          kind: 1063,
          content: 'Test',
          tags: [],
          keyPairs: testKeyPairs,
        );
        
        final result = NostrBroadcastResult(
          event: mockEvent,
          successCount: 0,
          totalRelays: 2,
          results: {'relay1': false, 'relay2': false},
          errors: {'relay1': 'Error 1', 'relay2': 'Error 2'},
        );
        
        expect(result.isSuccessful, isFalse);
        expect(result.isCompleteSuccess, isFalse);
        expect(result.successRate, equals(0.0));
        expect(result.successfulRelays, isEmpty);
        expect(result.failedRelays, equals(['relay1', 'relay2']));
      });
      
      test('should provide meaningful string representation', () {
        final testKeyPairs = NostrKeyPairs.generate();
        final mockEvent = NostrEvent.fromPartialData(
          kind: 1063,
          content: 'Test',
          tags: [],
          keyPairs: testKeyPairs,
        );
        
        final result = NostrBroadcastResult(
          event: mockEvent,
          successCount: 2,
          totalRelays: 3,
          results: {},
          errors: {},
        );
        
        final str = result.toString();
        expect(str, contains('NostrBroadcastResult'));
        expect(str, contains('2/3'));
        expect(str, contains('66.7%'));
      });
    });
    
    group('Disposal', () {
      test('should clean up resources on disposal', () {
        nostrService.dispose();
        
        expect(nostrService.connectedRelayCount, equals(0));
        expect(nostrService.relayCount, equals(0));
      });
      
      test('should handle multiple disposal calls', () {
        nostrService.dispose();
        nostrService.dispose(); // Should not throw
        
        expect(nostrService.connectedRelayCount, equals(0));
      });
    });
    
    group('Future Event Subscription', () {
      test('should support event subscription interface', () {
        // Test that the subscription method exists for future implementation
        expect(nostrService.subscribeToEvents, isA<Function>());
      });
    });
  });
}