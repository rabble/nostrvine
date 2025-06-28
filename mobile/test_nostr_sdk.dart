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

void main() async {
  print('🚀 Testing nostr_sdk event reception...');
  
  // Generate keys
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
  final connected = await nostr.addRelay(relay);
  
  print('✅ Connected: $connected');
  print('  - Status: ${relay.relayStatus.connected}');
  print('  - Read access: ${relay.relayStatus.readAccess}');
  
  // Create subscription
  final filters = [
    {
      'kinds': [22], // Video events
      'limit': 10,
    }
  ];
  
  print('📡 Creating subscription...');
  
  int eventCount = 0;
  final subscriptionId = nostr.subscribe(
    filters,
    (Event event) {
      eventCount++;
      print('📨 Event #$eventCount received:');
      print('  - Kind: ${event.kind}');
      print('  - ID: ${event.id.substring(0, 8)}...');
      print('  - Author: ${event.pubkey.substring(0, 8)}...');
      print('  - Content: ${event.content.substring(0, 50)}${event.content.length > 50 ? "..." : ""}');
    },
  );
  
  print('✅ Subscription created: $subscriptionId');
  
  // Wait for events
  print('⏳ Waiting for events (30 seconds)...');
  await Future.delayed(Duration(seconds: 30));
  
  print('🏁 Test complete. Received $eventCount events.');
  
  // Cleanup
  nostr.unsubscribe(subscriptionId);
  await Future.delayed(Duration(seconds: 1));
}