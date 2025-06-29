// ABOUTME: Manual test to fetch the published profile from relay
// ABOUTME: Tests if the profile event we just published is actually retrievable

import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';

void main() async {
  print('=== Testing Profile Fetch from vine.hol.is ===\n');
  
  // The public key from the logs
  final publicKey = '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';
  final eventId = '29609a582e97981d74cfb9981be2da6c2802afe8ebb90af3122cbd7cc6a09eb3';
  
  print('Looking for:');
  print('  Public Key: $publicKey');
  print('  Event ID: $eventId');
  print('  Published at: 1751191804 (2025-06-29T10:10:04.000Z UTC)');
  
  try {
    // Create HTTP client with SSL bypass (like we fixed in Flutter)
    final httpClient = HttpClient();
    httpClient.badCertificateCallback = (cert, host, port) => true;
    
    final wsUrl = Uri.parse('wss://vine.hol.is');
    print('\n1. Connecting to $wsUrl...');
    
    final channel = IOWebSocketChannel.connect(
      wsUrl,
      customClient: httpClient,
    );
    
    bool foundProfile = false;
    String? profileContent;
    
    // Listen for messages
    channel.stream.listen(
      (message) {
        final data = jsonDecode(message);
        
        if (data is List && data.isNotEmpty) {
          final messageType = data[0];
          
          if (messageType == 'EVENT') {
            final event = data[2];
            print('\n📄 Received EVENT:');
            print('   ID: ${event['id']}');
            print('   Kind: ${event['kind']}');
            print('   Pubkey: ${event['pubkey']}');
            print('   Created: ${event['created_at']}');
            print('   Content: ${event['content']}');
            
            if (event['id'] == eventId) {
              print('   🎯 FOUND OUR PUBLISHED PROFILE!');
              foundProfile = true;
              profileContent = event['content'];
            }
          } else if (messageType == 'EOSE') {
            print('\n⏹️ End of stored events (EOSE)');
            if (foundProfile) {
              print('✅ SUCCESS: Profile was found and is retrievable!');
              print('📄 Profile content: $profileContent');
            } else {
              print('❌ PROBLEM: Profile was not found in relay storage');
              print('   This means the relay either:');
              print('   - Rejected the event (but logs showed success)');
              print('   - Has a delay in indexing');
              print('   - Has storage/filtering issues');
            }
          } else if (messageType == 'AUTH') {
            final challenge = data[1];
            print('\n🔐 AUTH challenge: $challenge');
            // For this test, we'll skip AUTH and see if we can read without it
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
    
    // Query for the specific profile by author
    print('\n2. Requesting profile for author: $publicKey');
    final req = jsonEncode([
      'REQ',
      'profile-test',
      {
        'authors': [publicKey],
        'kinds': [0],
        'limit': 5
      }
    ]);
    
    print('   Sending: $req');
    channel.sink.add(req);
    
    // Wait for response
    await Future.delayed(Duration(seconds: 5));
    
    // Also try querying by event ID
    print('\n3. Requesting specific event by ID: $eventId');
    final eventReq = jsonEncode([
      'REQ',
      'event-test',
      {
        'ids': [eventId]
      }
    ]);
    
    print('   Sending: $eventReq');
    channel.sink.add(eventReq);
    
    // Wait for response
    await Future.delayed(Duration(seconds: 5));
    
    await channel.sink.close();
    
  } catch (e) {
    print('❌ Error: $e');
  }
}