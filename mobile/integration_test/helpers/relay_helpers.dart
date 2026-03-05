// ABOUTME: Relay helpers for E2E integration tests
// ABOUTME: Publish test Nostr events directly to the local FunnelCake relay

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'constants.dart';

/// Result of publishing a test video event.
typedef PublishedVideo = ({String eventId, String pubkey, String privateKey});

/// Result of publishing a test profile event.
typedef PublishedProfile = ({String pubkey, String privateKey});

/// Publish a kind 34236 video event to the local relay.
///
/// Creates a new keypair (or uses [privateKey] if provided), builds a minimal
/// video event with [title], signs it, and sends it via WebSocket.
///
/// Returns the event ID, author pubkey, and private key so callers can
/// follow the author or publish more events from the same identity.
///
/// Throws if the relay rejects the event or connection fails.
Future<PublishedVideo> publishTestVideoEvent({
  required String title,
  String? privateKey,
}) async {
  final privKey = privateKey ?? generatePrivateKey();
  final pubKey = getPublicKey(privKey);
  final dTag = 'e2e-${DateTime.now().millisecondsSinceEpoch}';

  // Dummy blossom-style URL -- relay validates imeta has url + image fields
  // but doesn't check if the file actually exists.
  const blossomBase = 'http://$emulatorHost:$blossomPort';
  const dummyHash =
      '0000000000000000000000000000000000000000000000000000000000000000';

  final event = Event(
    pubKey,
    34236,
    [
      ['d', dTag],
      ['title', title],
      [
        'imeta',
        'url $blossomBase/$dummyHash.mp4',
        'm video/mp4',
        'image $blossomBase/$dummyHash.jpg',
      ],
      ['duration', '6'],
      ['alt', 'E2E test video: $title'],
      ['client', 'diVine-e2e'],
    ],
    '',
  );
  event.sign(privKey);

  final eventId = await _publishEvent(event);
  debugPrint('Published test video event: $eventId (author: $pubKey)');
  return (eventId: eventId, pubkey: pubKey, privateKey: privKey);
}

/// Publish a kind 0 profile event to the local relay.
///
/// Creates a new keypair (or uses [privateKey] if provided), builds a
/// profile metadata event, signs it, and sends it via WebSocket.
///
/// Returns the pubkey and private key so callers can reuse the identity.
///
/// Throws if the relay rejects the event or connection fails.
Future<PublishedProfile> publishTestProfileEvent({
  required String name,
  String? displayName,
  String? about,
  String? privateKey,
}) async {
  final privKey = privateKey ?? generatePrivateKey();
  final pubKey = getPublicKey(privKey);

  final content = jsonEncode({
    'name': name,
    'display_name': displayName ?? name,
    if (about != null) 'about': about,
  });

  final event = Event(pubKey, 0, [], content);
  event.sign(privKey);

  final eventId = await _publishEvent(event);
  debugPrint('Published test profile event: $eventId (pubkey: $pubKey)');
  return (pubkey: pubKey, privateKey: privKey);
}

/// Send an event to the local relay and wait for OK confirmation.
Future<String> _publishEvent(Event event) async {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://$emulatorHost:$relayPort'),
  );

  final completer = Completer<String>();
  final subscription = channel.stream.listen((message) {
    final decoded = jsonDecode(message as String) as List<dynamic>;
    if (decoded[0] == 'OK' && decoded[1] == event.id) {
      if (decoded[2] == true) {
        completer.complete(event.id);
      } else {
        completer.completeError(
          Exception('Relay rejected event: ${decoded[3]}'),
        );
      }
    }
  });

  channel.sink.add(jsonEncode(['EVENT', event.toJson()]));

  try {
    return await completer.future.timeout(const Duration(seconds: 10));
  } finally {
    await subscription.cancel();
    await channel.sink.close();
  }
}
