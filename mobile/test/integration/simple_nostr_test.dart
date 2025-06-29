// ABOUTME: Simple integration test to verify NostrService consolidated properly
// ABOUTME: Tests basic functionality without platform dependencies

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';

void main() {
  group('NostrService Consolidation Test', () {
    test('should create NostrService instance', () {
      // Create a mock key manager
      final keyManager = NostrKeyManager();
      
      // Create the service
      final service = NostrService(keyManager);
      
      // Basic checks
      expect(service, isNotNull);
      expect(service.isInitialized, false);
      expect(service.isDisposed, false);
      expect(service.hasKeys, false);
      expect(service.publicKey, isNull);
      expect(service.relayCount, 0);
      expect(service.connectedRelayCount, 0);
      
      // Check relay management methods exist
      expect(service.relays, isEmpty);
      expect(service.relayStatuses, isEmpty);
      
      // Dispose
      service.dispose();
      expect(service.isDisposed, true);
    });
    
    test('NostrServiceException should work correctly', () {
      final exception = NostrServiceException('Test error');
      expect(exception.message, 'Test error');
      expect(exception.toString(), 'NostrServiceException: Test error');
    });
  });
}