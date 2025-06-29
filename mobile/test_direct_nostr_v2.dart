// ABOUTME: Direct test of NostrServiceV2 without Flutter dependencies
// ABOUTME: Run with: dart test_direct_nostr_v2.dart

import 'dart:async';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/event_filter.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:openvine/utils/unified_logger.dart';

// Simplified NostrServiceV2 for testing
class TestNostrServiceV2 {
  final String privateKey;
  Nostr? _nostrClient;
  final List<String> _connectedRelays = [];
  
  TestNostrServiceV2(this.privateKey);
  
  Future<void> initialize() async {
    Log.debug('🔧 Initializing TestNostrServiceV2...');
    
    final signer = LocalNostrSigner(privateKey);
    final pubKey = await signer.getPublicKey();
    
    if (pubKey == null) {
      throw Exception('Failed to get public key');
    }
    
    Log.debug('🔑 Public key: ${pubKey.substring(0, 8)}...');
    
    // Initialize Nostr client
    _nostrClient = Nostr(
      signer,
      pubKey,
      <EventFilter>[], // No global filters
      (relayUrl) => RelayBase(relayUrl, RelayStatus(relayUrl)),
      onNotice: (relayUrl, notice) {
        Log.debug('📢 Notice from $relayUrl: $notice');
      },
    );
    
    // Add relay
    final relayUrl = 'wss://vine.hol.is';
    final relay = RelayBase(relayUrl, RelayStatus(relayUrl));
    
    Log.debug('🔌 Connecting to $relayUrl...');
    final success = await _nostrClient!.addRelay(relay, autoSubscribe: true);
    
    if (success) {
      _connectedRelays.add(relayUrl);
      Log.debug('✅ Connected to relay: $relayUrl');
      Log.debug('  - Status: ${relay.relayStatus.connected}');
      Log.debug('  - Read access: ${relay.relayStatus.readAccess}');
      Log.debug('  - Write access: ${relay.relayStatus.writeAccess}');
    } else {
      throw Exception('Failed to connect to relay');
    }
    
    // Give relay time to fully establish connection
    await Future.delayed(const Duration(milliseconds: 500));
  }
  
  Stream<Event> subscribeToEvents({required List<Filter> filters}) {
    if (_nostrClient == null) {
      throw Exception('Not initialized');
    }
    
    // Convert our Filter objects to SDK filter format
    final sdkFilters = filters.map((filter) => filter.toJson()).toList();
    
    // Create stream controller for this subscription
    final controller = StreamController<Event>.broadcast();
    
    // Generate unique subscription ID
    final subscriptionId = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
    
    Log.debug('📡 Creating subscription with filters:');
    for (final filter in sdkFilters) {
      Log.debug('  - Filter: $filter');
    }
    
    // Create subscription using SDK
    final sdkSubId = _nostrClient!.subscribe(
      sdkFilters,
      (Event event) {
        Log.debug('📨 Received event: kind=${event.kind}, id=${event.id.substring(0, 8)}...');
        controller.add(event);
      },
      id: subscriptionId,
    );
    
    Log.debug('✅ Created subscription $subscriptionId (SDK ID: $sdkSubId) with ${filters.length} filters');
    
    // Check relay pool state
    Log.debug('🔍 Checking relay pool state...');
    final relays = _nostrClient!.activeRelays();
    for (final relay in relays) {
      Log.debug('  - Relay ${relay.url}: connected=${relay.relayStatus.connected}, authed=${relay.relayStatus.authed}');
    }
    
    return controller.stream;
  }
  
  void dispose() {
    _nostrClient = null;
    _connectedRelays.clear();
  }
}

void main() async {
  Log.debug('🚀 Testing NostrServiceV2 implementation...');
  
  // Generate keys
  final privateKey = generatePrivateKey();
  
  // Create service
  final service = TestNostrServiceV2(privateKey);
  
  try {
    // Initialize
    await service.initialize();
    
    // Create subscription
    final filter = Filter(
      kinds: [22], // Video events
      limit: 5,
    );
    
    final eventStream = service.subscribeToEvents(filters: [filter]);
    
    int eventCount = 0;
    final subscription = eventStream.listen((event) {
      eventCount++;
      Log.debug('✅ Event #$eventCount:');
      Log.debug('  - Kind: ${event.kind}');
      Log.debug('  - ID: ${event.id.substring(0, 8)}...');
      Log.debug('  - Author: ${event.pubkey.substring(0, 8)}...');
      Log.debug('  - Content: ${event.content.substring(0, 50)}${event.content.length > 50 ? "..." : ""}');
    });
    
    // Wait for events
    Log.debug('⏳ Waiting for events (20 seconds)...');
    await Future.delayed(Duration(seconds: 20));
    
    Log.debug('🏁 Test complete. Received $eventCount events.');
    
    // Cleanup
    await subscription.cancel();
    
  } finally {
    service.dispose();
  }
}
