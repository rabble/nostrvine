// ABOUTME: Simple test script to debug nostr_sdk event reception
// ABOUTME: Run with: dart test_nostr_sdk.dart

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
  Log.debug('🚀 Testing nostr_sdk event reception...');
  
  // Generate keys
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
  final connected = await nostr.addRelay(relay);
  
  Log.debug('✅ Connected: $connected');
  Log.debug('  - Status: ${relay.relayStatus.connected}');
  Log.debug('  - Read access: ${relay.relayStatus.readAccess}');
  
  // Create subscription
  final filters = [
    {
      'kinds': [22], // Video events
      'limit': 10,
    }
  ];
  
  Log.debug('📡 Creating subscription...');
  
  int eventCount = 0;
  final subscriptionId = nostr.subscribe(
    filters,
    (Event event) {
      eventCount++;
      Log.debug('📨 Event #$eventCount received:');
      Log.debug('  - Kind: ${event.kind}');
      Log.debug('  - ID: ${event.id.substring(0, 8)}...');
      Log.debug('  - Author: ${event.pubkey.substring(0, 8)}...');
      Log.debug('  - Content: ${event.content.substring(0, 50)}${event.content.length > 50 ? "..." : ""}');
    },
  );
  
  Log.debug('✅ Subscription created: $subscriptionId');
  
  // Wait for events
  Log.debug('⏳ Waiting for events (30 seconds)...');
  await Future.delayed(Duration(seconds: 30));
  
  Log.debug('🏁 Test complete. Received $eventCount events.');
  
  // Cleanup
  nostr.unsubscribe(subscriptionId);
  await Future.delayed(Duration(seconds: 1));
}
