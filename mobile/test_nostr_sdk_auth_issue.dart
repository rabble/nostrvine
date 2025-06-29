// ABOUTME: Test to verify nostr_sdk authentication and event reception issue
// ABOUTME: Run with: dart test_nostr_sdk_auth_issue.dart

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

void main() async {
  Log.debug('🚀 Testing nostr_sdk with NIP-42 AUTH handling...\n');
  
  // Test 1: Basic SDK usage (current implementation)
  Log.debug('=== TEST 1: Basic SDK Usage (Current Implementation) ===');
  await testBasicSDKUsage();
  
  Log.debug('\n');
  
  // Test 2: SDK with sendAfterAuth parameter
  Log.debug('=== TEST 2: SDK with sendAfterAuth Parameter ===');
  await testSDKWithSendAfterAuth();
  
  Log.debug('\n');
  
  // Test 3: Check relay auth status
  Log.debug('=== TEST 3: Relay Authentication Status ===');
  await testRelayAuthStatus();
}

Future<void> testBasicSDKUsage() async {
  Log.debug('Testing basic SDK usage (mimics NostrServiceV2)...');
  
  final privateKey = generatePrivateKey();
  final signer = LocalNostrSigner(privateKey);
  final pubKey = await signer.getPublicKey();
  
  Log.debug('🔑 Generated keys: ${pubKey!.substring(0, 8)}...');
  
  // Create Nostr client
  final nostr = Nostr(
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
  Log.debug('🔌 Connecting to $relayUrl...');
  
  final relay = RelayBase(relayUrl, RelayStatus(relayUrl));
  final connected = await nostr.addRelay(relay, autoSubscribe: true);
  
  Log.debug('✅ Connected: $connected');
  Log.debug('  - Status: ${relay.relayStatus.connected}');
  Log.debug('  - Authed: ${relay.relayStatus.authed}');
  Log.debug('  - Read access: ${relay.relayStatus.readAccess}');
  
  // Wait for potential AUTH
  await Future.delayed(Duration(seconds: 3));
  
  Log.debug('📡 Post-delay relay status:');
  Log.debug('  - Connected: ${relay.relayStatus.connected}');
  Log.debug('  - Authed: ${relay.relayStatus.authed}');
  Log.debug('  - Read access: ${relay.relayStatus.readAccess}');
  
  // Create subscription
  final filters = [
    {
      'kinds': [22], // Video events
      'limit': 5,
    }
  ];
  
  Log.debug('📡 Creating subscription...');
  
  int eventCount = 0;
  final subscriptionId = nostr.subscribe(
    filters,
    (Event event) {
      eventCount++;
      Log.debug('📨 Event received:');
      Log.debug('  - Kind: ${event.kind}');
      Log.debug('  - ID: ${event.id.substring(0, 8)}...');
    },
  );
  
  Log.debug('✅ Subscription created: $subscriptionId');
  
  // Wait for events
  Log.debug('⏳ Waiting for events (10 seconds)...');
  await Future.delayed(Duration(seconds: 10));
  
  Log.debug('📊 Result: Received $eventCount events');
  
  // Cleanup
  nostr.unsubscribe(subscriptionId);
}

Future<void> testSDKWithSendAfterAuth() async {
  Log.debug('Testing SDK with sendAfterAuth parameter...');
  
  final privateKey = generatePrivateKey();
  final signer = LocalNostrSigner(privateKey);
  final pubKey = await signer.getPublicKey();
  
  Log.debug('🔑 Generated keys: ${pubKey!.substring(0, 8)}...');
  
  // Create Nostr client
  final nostr = Nostr(
    signer,
    pubKey,
    <EventFilter>[], // No global filters
    (relayUrl) => RelayBase(relayUrl, RelayStatus(relayUrl)),
    onNotice: (relayUrl, notice) {
      Log.debug('📢 Notice from $relayUrl: $notice');
      if (notice.toLowerCase().contains('auth')) {
        Log.debug('🔐 AUTH-related notice detected!');
      }
    },
  );
  
  // Add relay
  final relayUrl = 'wss://vine.hol.is';
  Log.debug('🔌 Connecting to $relayUrl...');
  
  final relay = RelayBase(relayUrl, RelayStatus(relayUrl));
  final connected = await nostr.addRelay(relay, autoSubscribe: true);
  
  Log.debug('✅ Connected: $connected');
  
  // Wait longer for AUTH to complete
  Log.debug('⏳ Waiting for AUTH to complete (5 seconds)...');
  await Future.delayed(Duration(seconds: 5));
  
  Log.debug('📡 Post-AUTH relay status:');
  Log.debug('  - Connected: ${relay.relayStatus.connected}');
  Log.debug('  - Authed: ${relay.relayStatus.authed}');
  Log.debug('  - Read access: ${relay.relayStatus.readAccess}');
  Log.debug('  - Write access: ${relay.relayStatus.writeAccess}');
  
  // Create subscription with sendAfterAuth
  final filters = [
    {
      'kinds': [22], // Video events
      'limit': 5,
    }
  ];
  
  Log.debug('📡 Creating subscription with sendAfterAuth...');
  
  int eventCount = 0;
  
  // Note: The nostr_sdk subscribe method doesn't expose sendAfterAuth parameter directly
  // This is likely the issue - the SDK may not support it in the subscribe method
  final subscriptionId = nostr.subscribe(
    filters,
    (Event event) {
      eventCount++;
      Log.debug('📨 Event received:');
      Log.debug('  - Kind: ${event.kind}');
      Log.debug('  - ID: ${event.id.substring(0, 8)}...');
    },
    // sendAfterAuth: true, // This parameter doesn't exist in the current SDK!
  );
  
  Log.debug('✅ Subscription created: $subscriptionId');
  Log.debug('⚠️  Note: sendAfterAuth parameter not available in subscribe method!');
  
  // Wait for events
  Log.debug('⏳ Waiting for events (10 seconds)...');
  await Future.delayed(Duration(seconds: 10));
  
  Log.debug('📊 Result: Received $eventCount events');
  
  // Cleanup
  nostr.unsubscribe(subscriptionId);
}

Future<void> testRelayAuthStatus() async {
  Log.debug('Testing relay authentication status monitoring...');
  
  final privateKey = generatePrivateKey();
  final signer = LocalNostrSigner(privateKey);
  final pubKey = await signer.getPublicKey();
  
  Log.debug('🔑 Generated keys: ${pubKey!.substring(0, 8)}...');
  
  // Create Nostr client
  final nostr = Nostr(
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
  Log.debug('🔌 Connecting to $relayUrl...');
  
  final relay = RelayBase(relayUrl, RelayStatus(relayUrl));
  
  // Monitor relay status changes
  Log.debug('📊 Monitoring relay status changes...');
  Timer.periodic(Duration(seconds: 1), (timer) {
    Log.debug('  Status at ${timer.tick}s: connected=${relay.relayStatus.connected}, authed=${relay.relayStatus.authed}, read=${relay.relayStatus.readAccess}');
    if (timer.tick >= 10) timer.cancel();
  });
  
  final connected = await nostr.addRelay(relay, autoSubscribe: true);
  Log.debug('✅ Initial connection: $connected');
  
  // Try to trigger AUTH by sending a subscription immediately
  Log.debug('\n📡 Sending immediate subscription to trigger AUTH...');
  final filters = [{'kinds': [22], 'limit': 1}];
  
  final subscriptionId = nostr.subscribe(filters, (event) {
    Log.debug('📨 Got event: ${event.id.substring(0, 8)}...');
  });
  
  // Wait and observe
  await Future.delayed(Duration(seconds: 12));
  
  Log.debug('\n📊 Final relay status:');
  Log.debug('  - Connected: ${relay.relayStatus.connected}');
  Log.debug('  - Authed: ${relay.relayStatus.authed}');
  Log.debug('  - Read access: ${relay.relayStatus.readAccess}');
  Log.debug('  - Write access: ${relay.relayStatus.writeAccess}');
  
  // Check active relays
  final activeRelays = nostr.activeRelays();
  Log.debug('\n📡 Active relays: ${activeRelays.length}');
  for (final activeRelay in activeRelays) {
    Log.debug('  - ${activeRelay.url}: authed=${activeRelay.relayStatus.authed}');
  }
  
  // Cleanup
  nostr.unsubscribe(subscriptionId);
}
