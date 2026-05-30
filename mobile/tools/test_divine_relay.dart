// ABOUTME: Direct test of relay.divine.video divine extensions support
// ABOUTME: Sends REQ with sort and int# filters to verify relay behavior

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

void main() async {
  debugPrint('🧪 Testing relay.divine.video divine extensions...\n');

  // Connect to relay
  final ws = await WebSocket.connect('wss://relay.divine.video');
  debugPrint('✅ Connected to relay.divine.video\n');

  // Listen for responses
  ws.listen(
    (message) {
      final decoded = json.decode(message as String);
      final type = decoded[0];

      if (type == 'EVENT') {
        final event = decoded[2];
        debugPrint('📥 EVENT: ${event['id'].substring(0, 8)}');
        debugPrint('   Kind: ${event['kind']}');
        debugPrint(
          '   Created: ${DateTime.fromMillisecondsSinceEpoch((event['created_at'] as int) * 1000)}',
        );

        // Check for loop count in tags
        final tags = event['tags'] as List;
        for (final tag in tags) {
          if (tag is List && tag.length >= 2) {
            if (tag[0] == 'loop_count') {
              debugPrint('   ⭐ Loop Count: ${tag[1]}');
            }
            if (tag[0] == 'likes') {
              debugPrint('   ❤️  Likes: ${tag[1]}');
            }
          }
        }
        debugPrint('');
      } else if (type == 'EOSE') {
        debugPrint('✅ EOSE received for subscription ${decoded[1]}\n');
      } else if (type == 'CLOSED') {
        debugPrint('❌ CLOSED: ${decoded[1]} - ${decoded[2]}\n');
      } else if (type == 'NOTICE') {
        debugPrint('📢 NOTICE: ${decoded[1]}\n');
      } else {
        debugPrint('📨 $type: $decoded\n');
      }
    },
    onError: (error) => debugPrint('❌ WebSocket error: $error'),
    onDone: () => debugPrint('🔌 Connection closed'),
  );

  // Wait for connection to stabilize
  await Future.delayed(const Duration(milliseconds: 500));

  // Test 1: Basic REQ without divine extensions (baseline)
  debugPrint('━━━ TEST 1: Standard REQ (no divine extensions) ━━━');
  final standardReq = json.encode([
    'REQ',
    'test_standard',
    {
      'kinds': [34236, 22, 21],
      'limit': 5,
    },
  ]);
  debugPrint('📤 Sending: $standardReq\n');
  ws.add(standardReq);

  await Future.delayed(const Duration(seconds: 3));

  // Close standard subscription
  ws.add(json.encode(['CLOSE', 'test_standard']));
  await Future.delayed(const Duration(milliseconds: 500));

  // Test 2: REQ with divine extensions (sort by loop_count)
  debugPrint('\n━━━ TEST 2: Divine Extensions REQ (sort by loop_count) ━━━');
  final divineReq = json.encode([
    'REQ',
    'test_divine',
    {
      'kinds': [34236, 22, 21],
      'limit': 5,
      'sort': {'field': 'loop_count', 'dir': 'desc'},
    },
  ]);
  debugPrint('📤 Sending: $divineReq\n');
  ws.add(divineReq);

  await Future.delayed(const Duration(seconds: 3));

  // Close divine subscription
  ws.add(json.encode(['CLOSE', 'test_divine']));
  await Future.delayed(const Duration(milliseconds: 500));

  // Test 3: REQ with int# filter
  debugPrint('\n━━━ TEST 3: Divine Extensions with int# filter ━━━');
  final intFilterReq = json.encode([
    'REQ',
    'test_int_filter',
    {
      'kinds': [34236, 22, 21],
      'limit': 5,
      'sort': {'field': 'loop_count', 'dir': 'desc'},
      'int#loop_count': {
        'gte': 100, // Only videos with 100+ loops
      },
    },
  ]);
  debugPrint('📤 Sending: $intFilterReq\n');
  ws.add(intFilterReq);

  await Future.delayed(const Duration(seconds: 3));

  // Close int filter subscription
  ws.add(json.encode(['CLOSE', 'test_int_filter']));
  await Future.delayed(const Duration(milliseconds: 500));

  // Cleanup
  debugPrint('\n🧹 Closing connection...');
  await ws.close();

  exit(0);
}
