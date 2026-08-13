// ABOUTME: Tests for Nip07Service, the Dart-facing wrapper around a NIP-07
// ABOUTME: browser extension. Covers the optional getRelays handshake.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/nip07_service.dart';
import 'package:openvine/services/nip07_types.dart';

const _testPubkey =
    'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

class _FakeExtension extends NostrExtension {
  _FakeExtension({this.relays, this.relaysFail = false});

  /// Relay map to return, or null to model an extension without `getRelays`.
  Map<String, dynamic>? relays;

  /// When true, `getRelays` rejects instead of resolving.
  bool relaysFail;

  @override
  Future<String> getPublicKey() async => _testPubkey;

  @override
  Future<Map<String, dynamic>>? getRelays() {
    if (relaysFail) {
      return Future.error(const Nip07Exception('boom', code: 'UNKNOWN_ERROR'));
    }
    final value = relays;
    if (value == null) return null;
    return Future.value(value);
  }
}

void main() {
  group(Nip07Service, () {
    group('connect', () {
      test('reads the relay list the extension advertises', () async {
        final extension = _FakeExtension(
          relays: {
            'wss://relay.example.com': {'read': true, 'write': true},
            'wss://read.example.com': {'read': true, 'write': false},
          },
        );
        final service = Nip07Service.withExtension(extension);

        final result = await service.connect();

        expect(result.success, isTrue);
        expect(service.userRelays, hasLength(2));
        expect(
          service.userRelays!['wss://read.example.com'],
          equals({'read': true, 'write': false}),
        );
      });

      test(
        'succeeds without relays when the extension omits getRelays',
        () async {
          final service = Nip07Service.withExtension(_FakeExtension());

          final result = await service.connect();

          expect(result.success, isTrue);
          expect(service.userRelays, isNull);
        },
      );

      test('succeeds without relays when getRelays fails', () async {
        final service = Nip07Service.withExtension(
          _FakeExtension(relaysFail: true),
        );

        final result = await service.connect();

        expect(result.success, isTrue);
        expect(service.publicKey, equals(_testPubkey));
        expect(service.userRelays, isNull);
      });

      test(
        'drops relays from a previous connect when the reread fails',
        () async {
          final extension = _FakeExtension(
            relays: {
              'wss://relay.example.com': {'read': true, 'write': true},
            },
          );
          final service = Nip07Service.withExtension(extension);
          await service.connect();
          expect(service.userRelays, isNotNull);

          extension.relaysFail = true;
          await service.connect();

          expect(service.userRelays, isNull);
        },
      );
    });
  });
}
