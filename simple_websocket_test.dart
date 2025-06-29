// ABOUTME: Simple WebSocket test to verify SSL handling works
// ABOUTME: Tests direct connection to vine.hol.is relay

import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';

void main() async {
  print('=== Testing WebSocket SSL Connection ===\n');
  
  try {
    // Create HTTP client with SSL bypass (like Python)
    final httpClient = HttpClient();
    httpClient.badCertificateCallback = (cert, host, port) => true;
    
    final wsUrl = Uri.parse('wss://vine.hol.is');
    print('1. Connecting to $wsUrl with SSL bypass...');
    
    final channel = IOWebSocketChannel.connect(
      wsUrl,
      customClient: httpClient,
    );
    
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
    await Future.delayed(Duration(seconds: 2));
    
    // Send a simple REQ
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
    await Future.delayed(Duration(seconds: 3));
    
    // Close
    print('\n3. Closing connection...');
    await channel.sink.close();
    
    print('\n✅ SSL bypass WebSocket test completed successfully!');
    
  } catch (e) {
    print('❌ Error: $e');
  }
  
  exit(0);
}