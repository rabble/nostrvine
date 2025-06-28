// ABOUTME: Test script to debug subscription ID mismatch issue
// ABOUTME: Connects to relay and tracks subscription IDs

import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';

void main() async {
  print('=== Relay Subscription Test ===\n');
  
  // Track subscriptions we create
  final ourSubscriptions = <String>{};
  
  try {
    final wsUrl = Uri.parse('wss://vine.hol.is');
    final channel = IOWebSocketChannel.connect(wsUrl);
    
    print('1. Connecting to ${wsUrl}...');
    
    // Listen for messages
    channel.stream.listen(
      (message) {
        final data = jsonDecode(message);
        
        if (data is List && data.isNotEmpty) {
          final messageType = data[0];
          
          if (messageType == 'AUTH') {
            print('\n🔐 AUTH challenge: ${data[1]}');
            // For this test, we won't authenticate
          } else if (messageType == 'EVENT' && data.length >= 3) {
            final subId = data[1];
            print('\n📨 EVENT for subscription: $subId');
            if (ourSubscriptions.contains(subId)) {
              print('   ✅ This is OUR subscription!');
            } else {
              print('   ⚠️ Unknown subscription ID');
            }
          } else if (messageType == 'EOSE' && data.length >= 2) {
            final subId = data[1];
            print('\n📭 EOSE for subscription: $subId');
          } else if (messageType == 'NOTICE') {
            print('\n📢 NOTICE: ${data[1]}');
          }
        }
      },
      onError: (error) => print('❌ Error: $error'),
      onDone: () => print('🔌 Connection closed'),
    );
    
    // Wait for AUTH challenges
    await Future.delayed(Duration(seconds: 2));
    
    // Create a subscription
    final subId = 'test_${DateTime.now().millisecondsSinceEpoch}';
    ourSubscriptions.add(subId);
    
    print('\n2. Creating subscription with ID: $subId');
    
    final req = jsonEncode([
      'REQ',
      subId,
      {
        'kinds': [22],
        'limit': 5
      }
    ]);
    
    print('   Sending: $req');
    channel.sink.add(req);
    
    // Wait for events
    await Future.delayed(Duration(seconds: 5));
    
    // Close subscription
    print('\n3. Closing subscription...');
    channel.sink.add(jsonEncode(['CLOSE', subId]));
    
    await Future.delayed(Duration(seconds: 1));
    await channel.sink.close();
    
  } catch (e) {
    print('Error: $e');
  }
  
  exit(0);
}