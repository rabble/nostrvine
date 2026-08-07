// ABOUTME: Tests for VaultKeyService generate/wrap/unwrap lifecycle.
// ABOUTME: Pins the never-fork invariant when the relay is unreachable.

import 'dart:convert';

import 'package:creator_sync/creator_sync.dart';
import 'package:cryptography/cryptography.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:test/test.dart';

class _MockSigner extends Mock implements NostrSigner {}

class _MockClient extends Mock implements NostrClient {}

class _FakeCache implements VaultKeyCache {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String pubkeyHex) async => _store[pubkeyHex];

  @override
  Future<void> write(String pubkeyHex, String base64Key) async {
    _store[pubkeyHex] = base64Key;
  }
}

void main() {
  group(VaultKeyService, () {
    const pubkey =
        'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

    late _MockSigner signer;
    late _MockClient client;
    late _FakeCache cache;
    late VaultKeyService service;

    setUpAll(() {
      registerFallbackValue(Event(pubkey, 30078, const [], ''));
      registerFallbackValue(<Filter>[]);
    });

    setUp(() {
      signer = _MockSigner();
      client = _MockClient();
      cache = _FakeCache();
      service = VaultKeyService(
        signer: signer,
        client: client,
        cache: cache,
      );
      when(signer.getPublicKey).thenAnswer((_) async => pubkey);
    });

    test('returns the cached key without touching the signer', () async {
      final key = await AesGcm.with256bits().newSecretKey();
      final raw = base64Encode(await key.extractBytes());
      await cache.write(pubkey, raw);

      final obtained = await service.obtain();

      expect(base64Encode(await obtained.extractBytes()), equals(raw));
      verifyNever(() => signer.nip44Decrypt(any(), any()));
      verifyNever(() => client.queryEvents(any()));
    });

    test('unwraps the remote key and caches it', () async {
      final key = await AesGcm.with256bits().newSecretKey();
      final raw = base64Encode(await key.extractBytes());
      when(() => client.queryEvents(any())).thenAnswer(
        (_) async => [
          Event(
            pubkey,
            30078,
            const [
              ['d', vaultKeyDTag],
            ],
            'wrapped-ciphertext',
          ),
        ],
      );
      when(
        () => signer.nip44Decrypt(pubkey, 'wrapped-ciphertext'),
      ).thenAnswer((_) async => raw);

      final obtained = await service.obtain();

      expect(base64Encode(await obtained.extractBytes()), equals(raw));
      expect(await cache.read(pubkey), equals(raw));
    });

    test('generates and publishes a key when none exists remotely', () async {
      when(() => client.queryEvents(any())).thenAnswer((_) async => []);
      when(
        () => signer.nip44Encrypt(pubkey, any()),
      ).thenAnswer((_) async => 'freshly-wrapped');
      when(() => signer.signEvent(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.first as Event,
      );
      when(() => client.publishEvent(any())).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );

      final obtained = await service.obtain();

      expect((await obtained.extractBytes()).length, equals(32));
      expect(await cache.read(pubkey), isNotNull);
      verify(() => client.publishEvent(any())).called(1);
    });

    test(
      'throws rather than forking when the relay lookup fails',
      () async {
        when(
          () => client.queryEvents(any()),
        ).thenThrow(StateError('relay unreachable'));

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verifyNever(() => client.publishEvent(any()));
      },
    );

    test('throws when the signer cannot unwrap the remote key', () async {
      when(() => client.queryEvents(any())).thenAnswer(
        (_) async => [
          Event(
            pubkey,
            30078,
            const [
              ['d', vaultKeyDTag],
            ],
            'wrapped-ciphertext',
          ),
        ],
      );
      when(
        () => signer.nip44Decrypt(pubkey, any()),
      ).thenAnswer((_) async => null);

      await expectLater(
        service.obtain(),
        throwsA(isA<VaultKeyUnavailableException>()),
      );
      verifyNever(() => client.publishEvent(any()));
    });

    test('throws when signed out', () async {
      when(signer.getPublicKey).thenAnswer((_) async => null);

      await expectLater(
        service.obtain(),
        throwsA(isA<VaultKeyUnavailableException>()),
      );
    });

    test(
      'throws rather than forking when the signer errors unwrapping the '
      'remote key',
      () async {
        when(() => client.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              pubkey,
              30078,
              const [
                ['d', vaultKeyDTag],
              ],
              'wrapped-ciphertext',
            ),
          ],
        );
        when(
          () => signer.nip44Decrypt(pubkey, any()),
        ).thenThrow(StateError('signer unreachable'));

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verifyNever(() => client.publishEvent(any()));
      },
    );

    test(
      'throws rather than forking when the signer errors wrapping a fresh '
      'key',
      () async {
        when(() => client.queryEvents(any())).thenAnswer((_) async => []);
        when(
          () => signer.nip44Encrypt(pubkey, any()),
        ).thenThrow(StateError('signer unreachable'));

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verifyNever(() => client.publishEvent(any()));
        expect(await cache.read(pubkey), isNull);
      },
    );

    test(
      'throws rather than forking when the signer returns an empty wrap',
      () async {
        when(() => client.queryEvents(any())).thenAnswer((_) async => []);
        when(
          () => signer.nip44Encrypt(pubkey, any()),
        ).thenAnswer((_) async => '');

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verifyNever(() => client.publishEvent(any()));
        expect(await cache.read(pubkey), isNull);
      },
    );

    test(
      'throws rather than forking when the signer refuses to sign the '
      'vault key event',
      () async {
        when(() => client.queryEvents(any())).thenAnswer((_) async => []);
        when(
          () => signer.nip44Encrypt(pubkey, any()),
        ).thenAnswer((_) async => 'freshly-wrapped');
        when(() => signer.signEvent(any())).thenAnswer((_) async => null);

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verifyNever(() => client.publishEvent(any()));
        expect(await cache.read(pubkey), isNull);
      },
    );

    test(
      'throws rather than forking when no relay accepts the vault key '
      'event',
      () async {
        when(() => client.queryEvents(any())).thenAnswer((_) async => []);
        when(
          () => signer.nip44Encrypt(pubkey, any()),
        ).thenAnswer((_) async => 'freshly-wrapped');
        when(() => signer.signEvent(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments.first as Event,
        );
        when(
          () => client.publishEvent(any()),
        ).thenAnswer((_) async => const PublishNoRelays());

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        expect(await cache.read(pubkey), isNull);
      },
    );
  });
}
