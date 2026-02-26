// ABOUTME: Tests for NIP-50 full-text search functionality
// ABOUTME: Tests search queries using mock relays that simulate NIP-50 responses

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// A test pubkey (valid 64-char hex).
const _testPubkey =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

/// Creates a fake event JSON map with a deterministic id.
Map<String, dynamic> _fakeEventJson({
  required String content,
  int kind = 1,
  int? createdAt,
}) {
  final created = createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final tags = <List<String>>[];
  final serialized = json.encode([
    0,
    _testPubkey,
    created,
    kind,
    tags,
    content,
  ]);
  final id = sha256.convert(utf8.encode(serialized)).toString();
  return {
    'id': id,
    'pubkey': _testPubkey,
    'created_at': created,
    'kind': kind,
    'tags': tags,
    'content': content,
    'sig': '',
  };
}

/// Mock relay that captures sent messages and can simulate EVENT responses.
class _MockRelay extends RelayBase {
  _MockRelay(String url) : super(url, RelayStatus(url));

  final List<List<dynamic>> sentMessages = [];

  /// Events to return when a REQ is received.
  List<Map<String, dynamic>> eventsToReturn = [];

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool? forceSend,
    bool queueIfFailed = true,
  }) async {
    sentMessages.add(message);

    // When a REQ is received, simulate EVENT responses
    if (message[0] == 'REQ' && eventsToReturn.isNotEmpty) {
      final subId = message[1] as String;
      Future.microtask(() async {
        for (final eventJson in eventsToReturn) {
          onMessage?.call(this, ['EVENT', subId, eventJson]);
        }
        // Send EOSE after all events
        onMessage?.call(this, ['EOSE', subId]);
      });
    }

    return true;
  }
}

void main() {
  group('NIP-50 Search Tests', () {
    late Nostr nostr;
    late LocalNostrSigner signer;
    late _MockRelay mockRelay;

    const testPrivateKey =
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

    setUp(() async {
      signer = LocalNostrSigner(testPrivateKey);
      nostr = Nostr(signer, [], (url) => _MockRelay(url));
      await nostr.refreshPublicKey();

      mockRelay = _MockRelay('wss://search.test.relay');
    });

    test('Should search for text content in events', () async {
      // Configure mock relay to return events containing 'bitcoin'
      mockRelay.eventsToReturn = [
        _fakeEventJson(content: 'I love bitcoin and crypto'),
        _fakeEventJson(content: 'bitcoin is the future'),
      ];
      await nostr.relayPool.add(mockRelay);

      final filter = Filter(kinds: [1], limit: 10, search: 'bitcoin');

      final events = <Event>[];
      final subscriptionId = nostr.relayPool.subscribe([filter.toJson()], (
        event,
      ) {
        events.add(event);
      });

      // Allow microtasks to complete
      await Future<void>.delayed(Duration(milliseconds: 50));
      nostr.relayPool.unsubscribe(subscriptionId);

      expect(
        events.isNotEmpty,
        isTrue,
        reason: 'Should receive events matching search query',
      );
      expect(events, hasLength(2));

      for (final event in events) {
        expect(
          event.content.toLowerCase().contains('bitcoin'),
          isTrue,
          reason: 'Event content should contain search term',
        );
      }

      // Verify the REQ included the search filter
      final reqMessage = mockRelay.sentMessages.firstWhere(
        (m) => m[0] == 'REQ',
      );
      final sentFilter = reqMessage[2] as Map<String, dynamic>;
      expect(sentFilter['search'], equals('bitcoin'));
    });

    test('Should combine search with other filters', () async {
      final sinceTimestamp =
          DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch ~/
          1000;

      mockRelay.eventsToReturn = [
        _fakeEventJson(
          content: 'The nostr protocol is amazing',
          createdAt: sinceTimestamp + 3600,
        ),
        _fakeEventJson(
          content: 'Building on nostr protocol today',
          createdAt: sinceTimestamp + 7200,
        ),
      ];
      await nostr.relayPool.add(mockRelay);

      final filter = Filter(
        kinds: [1],
        since: sinceTimestamp,
        limit: 5,
        search: 'nostr protocol',
      );

      final events = <Event>[];
      final subscriptionId = nostr.relayPool.subscribe([filter.toJson()], (
        event,
      ) {
        events.add(event);
      });

      await Future<void>.delayed(Duration(milliseconds: 50));
      nostr.relayPool.unsubscribe(subscriptionId);

      expect(events.isNotEmpty, isTrue);

      for (final event in events) {
        expect(event.kind, equals(1));
        final containsSearch =
            event.content.toLowerCase().contains('nostr') ||
            event.content.toLowerCase().contains('protocol');
        expect(
          containsSearch,
          isTrue,
          reason: 'Event should contain search terms',
        );
      }

      // Verify filter included both search and since
      final reqMessage = mockRelay.sentMessages.firstWhere(
        (m) => m[0] == 'REQ',
      );
      final sentFilter = reqMessage[2] as Map<String, dynamic>;
      expect(sentFilter['search'], equals('nostr protocol'));
      expect(sentFilter['since'], equals(sinceTimestamp));
      expect(sentFilter['kinds'], equals([1]));
    });

    test('Should handle relays that do not support search', () async {
      // A relay that returns no events (simulating no NIP-50 support)
      final nonSearchRelay = _MockRelay('wss://no-search.relay');
      // eventsToReturn is empty by default — relay just ignores search
      await nostr.relayPool.add(nonSearchRelay);

      final filter = Filter(kinds: [1], limit: 5, search: 'test query');

      final events = <Event>[];
      final subscriptionId = nostr.relayPool.subscribe([filter.toJson()], (
        event,
      ) {
        events.add(event);
      });

      await Future<void>.delayed(Duration(milliseconds: 50));
      nostr.relayPool.unsubscribe(subscriptionId);

      // Non-supporting relays return no events — no crash
      expect(events, isEmpty);
    });

    test('Search API should provide convenient method', () async {
      mockRelay.eventsToReturn = [
        _fakeEventJson(content: 'bitcoin price is rising'),
        _fakeEventJson(content: 'bitcoin fundamentals are strong'),
      ];
      await nostr.relayPool.add(mockRelay);

      final results = await nostr.relayPool.searchEvents(
        'bitcoin',
        kinds: [1],
        limit: 10,
        timeout: Duration(milliseconds: 200),
      );

      expect(
        results.isNotEmpty,
        isTrue,
        reason: 'Should receive search results from convenience method',
      );

      for (final event in results) {
        expect(
          event.content.toLowerCase().contains('bitcoin'),
          isTrue,
          reason: 'Search results should contain the search term',
        );
      }

      // Verify deduplication works
      final eventIds = results.map((e) => e.id).toSet();
      expect(
        eventIds.length,
        equals(results.length),
        reason: 'Results should be deduplicated by event ID',
      );
    });
  });
}
