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

void main() async {
  print('🚀 Testing nostr_sdk with NIP-42 AUTH handling...\n');
  
  // Test 1: Basic SDK usage (current implementation)
  print('=== TEST 1: Basic SDK Usage (Current Implementation) ===');
  await testBasicSDKUsage();
  
  print('\n');
  
  // Test 2: SDK with sendAfterAuth parameter
  print('=== TEST 2: SDK with sendAfterAuth Parameter ===');
  await testSDKWithSendAfterAuth();
  
  print('\n');
  
  // Test 3: Check relay auth status
  print('=== TEST 3: Relay Authentication Status ===');
  await testRelayAuthStatus();
}

Future<void> testBasicSDKUsage() async {
  print('Testing basic SDK usage (mimics NostrServiceV2)...');
  
  final privateKey = generatePrivateKey();
  final signer = LocalNostrSigner(privateKey);
  final pubKey = await signer.getPublicKey();
  
  print('🔑 Generated keys: ${pubKey!.substring(0, 8)}...');
  
  // Create Nostr client
  final nostr = Nostr(
    signer,
    pubKey,
    <EventFilter>[], // No global filters
    (relayUrl) => RelayBase(relayUrl, RelayStatus(relayUrl)),
    onNotice: (relayUrl, notice) {
      print('📢 Notice from $relayUrl: $notice');
    },
  );
  
  // Add relay
  final relayUrl = 'wss://vine.hol.is';
  print('🔌 Connecting to $relayUrl...');
  
  final relay = RelayBase(relayUrl, RelayStatus(relayUrl));
  final connected = await nostr.addRelay(relay, autoSubscribe: true);
  
  print('✅ Connected: $connected');
  print('  - Status: ${relay.relayStatus.connected}');
  print('  - Authed: ${relay.relayStatus.authed}');
  print('  - Read access: ${relay.relayStatus.readAccess}');
  
  // Wait for potential AUTH
  await Future.delayed(Duration(seconds: 3));
  
  print('📡 Post-delay relay status:');
  print('  - Connected: ${relay.relayStatus.connected}');
  print('  - Authed: ${relay.relayStatus.authed}');
  print('  - Read access: ${relay.relayStatus.readAccess}');
  
  // Create subscription
  final filters = [
    {
      'kinds': [22], // Video events
      'limit': 5,
    }
  ];
  
  print('📡 Creating subscription...');
  
  int eventCount = 0;
  final subscriptionId = nostr.subscribe(
    filters,
    (Event event) {
      eventCount++;
      print('📨 Event received:');
      print('  - Kind: ${event.kind}');
      print('  - ID: ${event.id.substring(0, 8)}...');
    },
  );
  
  print('✅ Subscription created: $subscriptionId');
  
  // Wait for events
  print('⏳ Waiting for events (10 seconds)...');
  await Future.delayed(Duration(seconds: 10));
  
  print('📊 Result: Received $eventCount events');
  
  // Cleanup
  nostr.unsubscribe(subscriptionId);
}

Future<void> testSDKWithSendAfterAuth() async {
  print('Testing SDK with sendAfterAuth parameter...');
  
  final privateKey = generatePrivateKey();
  final signer = LocalNostrSigner(privateKey);
  final pubKey = await signer.getPublicKey();
  
  print('🔑 Generated keys: ${pubKey!.substring(0, 8)}...');
  
  // Create Nostr client
  final nostr = Nostr(
    signer,
    pubKey,
    <EventFilter>[], // No global filters
    (relayUrl) => RelayBase(relayUrl, RelayStatus(relayUrl)),
    onNotice: (relayUrl, notice) {
      print('📢 Notice from $relayUrl: $notice');
      if (notice.toLowerCase().contains('auth')) {
        print('🔐 AUTH-related notice detected!');
      }
    },
  );
  
  // Add relay
  final relayUrl = 'wss://vine.hol.is';
  print('🔌 Connecting to $relayUrl...');
  
  final relay = RelayBase(relayUrl, RelayStatus(relayUrl));
  final connected = await nostr.addRelay(relay, autoSubscribe: true);
  
  print('✅ Connected: $connected');
  
  // Wait longer for AUTH to complete
  print('⏳ Waiting for AUTH to complete (5 seconds)...');
  await Future.delayed(Duration(seconds: 5));
  
  print('📡 Post-AUTH relay status:');
  print('  - Connected: ${relay.relayStatus.connected}');
  print('  - Authed: ${relay.relayStatus.authed}');
  print('  - Read access: ${relay.relayStatus.readAccess}');
  print('  - Write access: ${relay.relayStatus.writeAccess}');
  
  // Create subscription with sendAfterAuth
  final filters = [
    {
      'kinds': [22], // Video events
      'limit': 5,
    }
  ];
  
  print('📡 Creating subscription with sendAfterAuth...');
  
  int eventCount = 0;
  
  // Note: The nostr_sdk subscribe method doesn't expose sendAfterAuth parameter directly
  // This is likely the issue - the SDK may not support it in the subscribe method
  final subscriptionId = nostr.subscribe(
    filters,
    (Event event) {
      eventCount++;
      print('📨 Event received:');
      print('  - Kind: ${event.kind}');
      print('  - ID: ${event.id.substring(0, 8)}...');
    },
    // sendAfterAuth: true, // This parameter doesn't exist in the current SDK!
  );
  
  print('✅ Subscription created: $subscriptionId');
  print('⚠️  Note: sendAfterAuth parameter not available in subscribe method!');
  
  // Wait for events
  print('⏳ Waiting for events (10 seconds)...');
  await Future.delayed(Duration(seconds: 10));
  
  print('📊 Result: Received $eventCount events');
  
  // Cleanup
  nostr.unsubscribe(subscriptionId);
}

Future<void> testRelayAuthStatus() async {
  print('Testing relay authentication status monitoring...');
  
  final privateKey = generatePrivateKey();
  final signer = LocalNostrSigner(privateKey);
  final pubKey = await signer.getPublicKey();
  
  print('🔑 Generated keys: ${pubKey!.substring(0, 8)}...');
  
  // Create Nostr client
  final nostr = Nostr(
    signer,
    pubKey,
    <EventFilter>[], // No global filters
    (relayUrl) => RelayBase(relayUrl, RelayStatus(relayUrl)),
    onNotice: (relayUrl, notice) {
      print('📢 Notice from $relayUrl: $notice');
    },
  );
  
  // Add relay
  final relayUrl = 'wss://vine.hol.is';
  print('🔌 Connecting to $relayUrl...');
  
  final relay = RelayBase(relayUrl, RelayStatus(relayUrl));
  
  // Monitor relay status changes
  print('📊 Monitoring relay status changes...');
  Timer.periodic(Duration(seconds: 1), (timer) {
    print('  Status at ${timer.tick}s: connected=${relay.relayStatus.connected}, authed=${relay.relayStatus.authed}, read=${relay.relayStatus.readAccess}');
    if (timer.tick >= 10) timer.cancel();
  });
  
  final connected = await nostr.addRelay(relay, autoSubscribe: true);
  print('✅ Initial connection: $connected');
  
  // Try to trigger AUTH by sending a subscription immediately
  print('\n📡 Sending immediate subscription to trigger AUTH...');
  final filters = [{'kinds': [22], 'limit': 1}];
  
  final subscriptionId = nostr.subscribe(filters, (event) {
    print('📨 Got event: ${event.id.substring(0, 8)}...');
  });
  
  // Wait and observe
  await Future.delayed(Duration(seconds: 12));
  
  print('\n📊 Final relay status:');
  print('  - Connected: ${relay.relayStatus.connected}');
  print('  - Authed: ${relay.relayStatus.authed}');
  print('  - Read access: ${relay.relayStatus.readAccess}');
  print('  - Write access: ${relay.relayStatus.writeAccess}');
  
  // Check active relays
  final activeRelays = nostr.activeRelays();
  print('\n📡 Active relays: ${activeRelays.length}');
  for (final activeRelay in activeRelays) {
    print('  - ${activeRelay.url}: authed=${activeRelay.relayStatus.authed}');
  }
  
  // Cleanup
  nostr.unsubscribe(subscriptionId);
}