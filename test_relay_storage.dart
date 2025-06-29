// ABOUTME: Test if vine.hol.is relay is storing ANY Kind 0 events at all
// ABOUTME: Query for recent Kind 0 events to see if storage is working

import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';

void main() async {
  print('=== Testing if vine.hol.is stores ANY Kind 0 events ===\n');
  
  try {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback = (cert, host, port) => true;
    
    final wsUrl = Uri.parse('wss://vine.hol.is');
    print('1. Connecting to $wsUrl...');
    
    final channel = IOWebSocketChannel.connect(
      wsUrl,
      customClient: httpClient,
    );
    
    int eventCount = 0;
    
    // Listen for messages
    channel.stream.listen(
      (message) {
        final data = jsonDecode(message);
        
        if (data is List && data.isNotEmpty) {
          final messageType = data[0];
          
          if (messageType == 'EVENT') {
            eventCount++;
            final event = data[2];
            print('\n📄 Found Kind 0 event #$eventCount:');
            print('   ID: ${event['id']}');
            print('   Pubkey: ${event['pubkey']}');
            print('   Created: ${event['created_at']} (${DateTime.fromMillisecondsSinceEpoch((event['created_at'] as int) * 1000).toUtc()})');
            print('   Content preview: ${event['content'].toString().substring(0, 50)}...');
          } else if (messageType == 'EOSE') {
            print('\n⏹️ End of stored events');
            if (eventCount == 0) {
              print('❌ CRITICAL: Relay has ZERO Kind 0 events stored!');
              print('   This means the relay is not storing profile events at all.');
              print('   Either:');
              print('   - Relay storage is broken');
              print('   - Relay is configured to not store Kind 0');
              print('   - All Kind 0 events are being rejected/filtered');
            } else {
              print('✅ Relay HAS $eventCount Kind 0 events stored');
              print('   This means storage works, but our specific events are being rejected');
            }
          } else if (messageType == 'AUTH') {
            print('\n🔐 AUTH challenge received (will ignore)');
          } else if (messageType == 'NOTICE') {
            print('\n📢 NOTICE: ${data[1]}');
          }
        }
      },
      onError: (error) {
        print('❌ WebSocket error: $error');
      },
      onDone: () {
        print('\n🔌 Connection closed');
        exit(0);
      },
    );
    
    // Wait for connection
    await Future.delayed(Duration(seconds: 1));
    
    // Query for recent Kind 0 events from ANY author
    print('\n2. Requesting recent Kind 0 (profile) events from ALL authors...');
    final req = jsonEncode([
      'REQ',
      'kind0-test',
      {
        'kinds': [0],
        'limit': 10  // Get up to 10 recent profile events
      }
    ]);
    
    print('   Sending: $req');
    channel.sink.add(req);
    
    // Wait for response
    await Future.delayed(Duration(seconds: 5));
    
    await channel.sink.close();
    
  } catch (e) {
    print('❌ Error: $e');
  }
}