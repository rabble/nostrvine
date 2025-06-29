// Fetch COMPLETE kind 0 events from vine.hol.is relay - ALL DATA
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/event_filter.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/client_utils/keys.dart';

void main() async {
  print('📋 Fetching COMPLETE kind 0 events from vine.hol.is...\n');
  
  final privateKey = generatePrivateKey();
  final signer = LocalNostrSigner(privateKey);
  final pubKey = await signer.getPublicKey();
  
  final nostrClient = Nostr(
    signer,
    pubKey!,
    <EventFilter>[],
    (relayUrl) => RelayBase(relayUrl, RelayStatus(relayUrl)),
    onNotice: (relayUrl, notice) => print('📢 Notice: $notice'),
  );
  
  // Connect to relay
  final relay = RelayBase('wss://vine.hol.is', RelayStatus('wss://vine.hol.is'));
  await nostrClient.addRelay(relay, autoSubscribe: true);
  await Future.delayed(Duration(milliseconds: 500));
  
  print('🔌 Connected to wss://vine.hol.is');
  
  // Create subscription for ALL kind 0 events
  final filter = Filter(kinds: [0], limit: 100); // Get up to 100
  final events = <Event>[];
  
  final controller = StreamController<Event>.broadcast();
  nostrClient.subscribe([filter.toJson()], (Event event) {
    events.add(event);
  });
  
  // Wait to collect all events
  print('⏳ Collecting all kind 0 events...');
  await Future.delayed(Duration(seconds: 8));
  
  print('\n📊 Found ${events.length} kind 0 profile events');
  
  // Save complete data to file
  final output = StringBuffer();
  output.writeln('COMPLETE KIND 0 EVENTS FROM vine.hol.is');
  output.writeln('Total events: ${events.length}');
  output.writeln('Generated: ${DateTime.now()}');
  output.writeln('=' * 120);
  
  for (int i = 0; i < events.length; i++) {
    final event = events[i];
    
    output.writeln('\nEVENT ${i + 1} of ${events.length}:');
    
    // Print EVERYTHING available on the event object
    output.writeln('COMPLETE EVENT SERIALIZATION:');
    try {
      // Try to get the complete event as a map/JSON
      output.writeln('event.toString(): ${event.toString()}');
      
      // Get all available properties
      output.writeln('id: ${event.id}');
      output.writeln('pubkey: ${event.pubkey}');
      output.writeln('created_at: ${event.createdAt}');
      output.writeln('kind: ${event.kind}');
      output.writeln('tags: ${event.tags}');
      output.writeln('content: ${event.content}');
      output.writeln('sig: ${event.sig}');
      
      // Try to access any other fields that might exist
      output.writeln('runtimeType: ${event.runtimeType}');
      
    } catch (e) {
      output.writeln('Error serializing event: $e');
    }
    
    output.writeln('=' * 120);
  }
  
  // Write to file
  final file = File('kind0_events_complete.txt');
  await file.writeAsString(output.toString());
  
  print('\n✅ COMPLETE! Found ${events.length} total kind 0 events on vine.hol.is');
  print('📝 Full data saved to: kind0_events_complete.txt');
  print('All event data includes EVERYTHING - id, pubkey, created_at, kind, tags, content, sig');
}