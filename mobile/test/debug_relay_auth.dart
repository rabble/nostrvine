// ABOUTME: Debug script to test direct WebSocket connection to vine.hol.is
// ABOUTME: Shows raw messages to understand NIP-42 AUTH flow

import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';

void main() async {
  print('=== Direct WebSocket Test for vine.hol.is ===\n');
  
  try {
    // Connect to the relay
    final wsUrl = Uri.parse('wss://vine.hol.is');
    final channel = IOWebSocketChannel.connect(wsUrl);
    
    print('1. Connecting to ${wsUrl}...');
    
    // Listen for messages
    channel.stream.listen(
      (message) {
        print('\n📨 Received: $message');
        final data = jsonDecode(message);
        
        if (data is List && data.isNotEmpty) {
          final messageType = data[0];
          print('   Type: $messageType');
          
          if (messageType == 'AUTH') {
            print('   🔐 AUTH CHALLENGE RECEIVED!');
            print('   Challenge: ${data[1]}');
          } else if (messageType == 'NOTICE') {
            print('   📢 NOTICE: ${data[1]}');
          } else if (messageType == 'OK') {
            print('   ✅ OK: Event accepted');
          } else if (messageType == 'EVENT') {
            print('   📄 EVENT received');
          }
        }
      },
      onError: (error) {
        print('❌ WebSocket error: $error');
      },
      onDone: () {
        print('🔌 WebSocket connection closed');
      },
    );
    
    // Wait for connection
    await Future.delayed(Duration(seconds: 1));
    
    // Send a REQ to request video events
    print('\n2. Sending REQ for video events...');
    final req = jsonEncode([
      'REQ',
      'test-sub-1',
      {
        'kinds': [22],
        'limit': 1
      }
    ]);
    
    print('   Sending: $req');
    channel.sink.add(req);
    
    // Wait for response
    await Future.delayed(Duration(seconds: 5));
    
    // Close subscription
    print('\n3. Closing subscription...');
    final close = jsonEncode(['CLOSE', 'test-sub-1']);
    channel.sink.add(close);
    
    await Future.delayed(Duration(seconds: 1));
    
    // Close connection
    await channel.sink.close();
    
  } catch (e) {
    print('Error: $e');
  }
  
  exit(0);
}