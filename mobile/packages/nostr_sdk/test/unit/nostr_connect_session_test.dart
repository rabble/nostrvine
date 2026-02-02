// ABOUTME: Unit tests for NostrConnectSession class
// ABOUTME: Tests state machine transitions and URL generation

import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('NostrRemoteSignerInfo nostrconnect:// support', () {
    test('isNostrConnectUrl returns true for nostrconnect:// URLs', () {
      expect(
        NostrRemoteSignerInfo.isNostrConnectUrl('nostrconnect://abc123'),
        isTrue,
      );
      expect(
        NostrRemoteSignerInfo.isNostrConnectUrl(
          'nostrconnect://abc?relay=wss://relay.example.com',
        ),
        isTrue,
      );
    });

    test('isNostrConnectUrl returns false for bunker:// URLs', () {
      expect(
        NostrRemoteSignerInfo.isNostrConnectUrl('bunker://abc123'),
        isFalse,
      );
    });

    test('isNostrConnectUrl returns false for null', () {
      expect(NostrRemoteSignerInfo.isNostrConnectUrl(null), isFalse);
    });

    test('isNostrConnectUrl returns false for empty string', () {
      expect(NostrRemoteSignerInfo.isNostrConnectUrl(''), isFalse);
    });

    test(
      'generateNostrConnectUrl creates valid info with ephemeral keypair',
      () {
        final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
          relays: ['wss://relay.example.com'],
          appName: 'TestApp',
          appUrl: 'https://test.com',
        );

        // Should have client pubkey (64 hex chars)
        expect(info.clientPubkey, isNotNull);
        expect(info.clientPubkey!.length, equals(64));
        expect(
          RegExp(r'^[0-9a-f]+$').hasMatch(info.clientPubkey!),
          isTrue,
          reason: 'clientPubkey should be hex',
        );

        // Should have nsec
        expect(info.nsec, isNotNull);
        expect(info.nsec!.startsWith('nsec1'), isTrue);

        // Should have secret (16 hex chars = 8 bytes)
        expect(info.optionalSecret, isNotNull);
        expect(info.optionalSecret!.length, equals(16));

        // Should be marked as client-initiated
        expect(info.isClientInitiated, isTrue);

        // Should have relays
        expect(info.relays, equals(['wss://relay.example.com']));

        // Should have app info
        expect(info.appName, equals('TestApp'));
        expect(info.appUrl, equals('https://test.com'));

        // remoteSignerPubkey should be empty (unknown until bunker responds)
        expect(info.remoteSignerPubkey, isEmpty);
      },
    );

    test('generateNostrConnectUrl creates unique keypairs each time', () {
      final info1 = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );
      final info2 = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );

      expect(info1.clientPubkey, isNot(equals(info2.clientPubkey)));
      expect(info1.nsec, isNot(equals(info2.nsec)));
      expect(info1.optionalSecret, isNot(equals(info2.optionalSecret)));
    });

    test('toNostrConnectUrl generates valid URL', () {
      final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com', 'wss://relay2.example.com'],
        appName: 'TestApp',
        appUrl: 'https://test.com',
      );

      final url = info.toNostrConnectUrl();

      // Should start with nostrconnect://
      expect(url.startsWith('nostrconnect://'), isTrue);

      // Should contain client pubkey as host
      expect(url.contains(info.clientPubkey!), isTrue);

      // Should contain relays
      expect(url.contains('relay='), isTrue);
      expect(
        url.contains(Uri.encodeComponent('wss://relay.example.com')),
        isTrue,
      );
      expect(
        url.contains(Uri.encodeComponent('wss://relay2.example.com')),
        isTrue,
      );

      // Should contain secret
      expect(url.contains('secret='), isTrue);
      expect(url.contains(info.optionalSecret!), isTrue);

      // Should contain app name and url as separate params (per NIP-46)
      expect(url.contains('name='), isTrue);
      expect(url.contains('TestApp'), isTrue);
      expect(url.contains('url='), isTrue);

      // Should contain perms
      expect(url.contains('perms='), isTrue);
      expect(url.contains('sign_event'), isTrue);
    });

    test('toNostrConnectUrl throws if clientPubkey is missing', () {
      final info = NostrRemoteSignerInfo(
        remoteSignerPubkey: 'abc',
        relays: ['wss://relay.example.com'],
        optionalSecret: 'secret123',
        // clientPubkey is null
      );

      expect(() => info.toNostrConnectUrl(), throwsA(isA<StateError>()));
    });

    test('toNostrConnectUrl throws if secret is missing', () {
      final info = NostrRemoteSignerInfo(
        remoteSignerPubkey: '',
        relays: ['wss://relay.example.com'],
        clientPubkey: 'abc123',
        // optionalSecret is null
      );

      expect(() => info.toNostrConnectUrl(), throwsA(isA<StateError>()));
    });

    test('toNostrConnectUrl with custom permissions', () {
      final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );

      final url = info.toNostrConnectUrl(permissions: 'sign_event:0');

      expect(url.contains('perms=sign_event%3A0'), isTrue);
    });
  });

  group('NostrConnectSession', () {
    test('initial state is idle', () {
      final session = NostrConnectSession(relays: ['wss://relay.example.com']);

      expect(session.state, equals(NostrConnectState.idle));
      expect(session.connectUrl, isNull);
      expect(session.info, isNull);

      session.dispose();
    });

    test('cancel from idle state transitions to cancelled', () {
      final session = NostrConnectSession(relays: ['wss://relay.example.com']);

      session.cancel();

      expect(session.state, equals(NostrConnectState.cancelled));

      session.dispose();
    });

    test('state stream emits state changes', () async {
      final session = NostrConnectSession(relays: ['wss://relay.example.com']);

      final states = <NostrConnectState>[];
      final subscription = session.stateStream.listen(states.add);

      session.cancel();

      // Give time for stream to emit
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(states, contains(NostrConnectState.cancelled));

      await subscription.cancel();
      session.dispose();
    });

    test('waitForConnection throws if not in listening state', () {
      final session = NostrConnectSession(relays: ['wss://relay.example.com']);

      expect(() => session.waitForConnection(), throwsA(isA<StateError>()));

      session.dispose();
    });

    test('start throws if already started', () {
      // Test that start() can only be called from idle state
      // We use cancel() to transition out of idle state without any network calls
      final session = NostrConnectSession(relays: ['wss://relay.example.com']);

      // Verify initial state
      expect(session.state, equals(NostrConnectState.idle));

      // Cancel transitions from idle to cancelled
      session.cancel();
      expect(session.state, equals(NostrConnectState.cancelled));

      // Now start() should throw because we're not in idle state
      expect(
        () => session.start(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('already started'),
          ),
        ),
      );

      session.dispose();
    });
  });

  group('NostrConnectState enum', () {
    test('all states are defined', () {
      expect(NostrConnectState.values, hasLength(7));
      expect(NostrConnectState.values, contains(NostrConnectState.idle));
      expect(NostrConnectState.values, contains(NostrConnectState.generating));
      expect(NostrConnectState.values, contains(NostrConnectState.listening));
      expect(NostrConnectState.values, contains(NostrConnectState.connected));
      expect(NostrConnectState.values, contains(NostrConnectState.timeout));
      expect(NostrConnectState.values, contains(NostrConnectState.cancelled));
      expect(NostrConnectState.values, contains(NostrConnectState.error));
    });
  });

  group('NostrConnectResult', () {
    test('stores all required fields', () {
      final info = NostrRemoteSignerInfo(
        remoteSignerPubkey: 'bunker123',
        relays: ['wss://relay.example.com'],
        isClientInitiated: true,
      );

      final result = NostrConnectResult(
        remoteSignerPubkey: 'bunker123',
        userPubkey: 'user456',
        info: info,
      );

      expect(result.remoteSignerPubkey, equals('bunker123'));
      expect(result.userPubkey, equals('user456'));
      expect(result.info, equals(info));
    });

    test('userPubkey can be null', () {
      final info = NostrRemoteSignerInfo(
        remoteSignerPubkey: 'bunker123',
        relays: ['wss://relay.example.com'],
      );

      final result = NostrConnectResult(
        remoteSignerPubkey: 'bunker123',
        userPubkey: null,
        info: info,
      );

      expect(result.userPubkey, isNull);
    });
  });
}
