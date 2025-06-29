// ABOUTME: Debug script to test direct WebSocket connection to vine.hol.is
// ABOUTME: Shows raw messages to understand NIP-42 AUTH flow

import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() async {
  Log.debug('=== Direct WebSocket Test for vine.hol.is ===\n');
  
  try {
    // Connect to the relay
    final wsUrl = Uri.parse('wss://vine.hol.is');
    final channel = IOWebSocketChannel.connect(wsUrl);
    
    Log.debug('1. Connecting to ${wsUrl}...');
    
    // Listen for messages
    channel.stream.listen(
      (message) {
        Log.debug('\n📨 Received: $message');
        final data = jsonDecode(message);
        
        if (data is List && data.isNotEmpty) {
          final messageType = data[0];
          Log.debug('   Type: $messageType');
          
          if (messageType == 'AUTH') {
            Log.debug('   🔐 AUTH CHALLENGE RECEIVED!');
            Log.debug('   Challenge: ${data[1]}');
          } else if (messageType == 'NOTICE') {
            Log.debug('   📢 NOTICE: ${data[1]}');
          } else if (messageType == 'OK') {
            Log.debug('   ✅ OK: Event accepted');
          } else if (messageType == 'EVENT') {
            Log.debug('   📄 EVENT received');
          }
        }
      },
      onError: (error) {
        Log.debug('❌ WebSocket error: $error');
      },
      onDone: () {
        Log.debug('🔌 WebSocket connection closed');
      },
    );
    
    // Wait for connection
    await Future.delayed(Duration(seconds: 1));
    
    // Send a REQ to request video events
    Log.debug('\n2. Sending REQ for video events...');
    final req = jsonEncode([
      'REQ',
      'test-sub-1',
      {
        'kinds': [22],
        'limit': 1
      }
    ]);
    
    Log.debug('   Sending: $req');
    channel.sink.add(req);
    
    // Wait for response
    await Future.delayed(Duration(seconds: 5));
    
    // Close subscription
    Log.debug('\n3. Closing subscription...');
    final close = jsonEncode(['CLOSE', 'test-sub-1']);
    channel.sink.add(close);
    
    await Future.delayed(Duration(seconds: 1));
    
    // Close connection
    await channel.sink.close();
    
  } catch (e) {
    Log.debug('Error: $e');
  }
  
  exit(0);
}
