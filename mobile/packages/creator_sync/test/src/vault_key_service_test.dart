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

/// Shapes a `queryEventsDetailed` answer with a live (non-failed) relay
/// pool returning [events].
({List<Event> events, bool timedOut, bool noRelays}) _confirmed(
  List<Event> events,
) => (events: events, timedOut: false, noRelays: false);

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
      verifyNever(
        () => client.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
        ),
      );
    });

    test('unwraps the remote key and caches it', () async {
      final key = await AesGcm.with256bits().newSecretKey();
      final raw = base64Encode(await key.extractBytes());
      when(
        () => client.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer(
        (_) async => _confirmed([
          Event(
            pubkey,
            30078,
            const [
              ['d', vaultKeyDTag],
            ],
            'wrapped-ciphertext',
          ),
        ]),
      );
      when(
        () => signer.nip44Decrypt(pubkey, 'wrapped-ciphertext'),
      ).thenAnswer((_) async => raw);

      final obtained = await service.obtain();

      expect(base64Encode(await obtained.extractBytes()), equals(raw));
      expect(await cache.read(pubkey), equals(raw));
      verifyNever(() => client.publishEvent(any()));
    });

    test(
      'ignores non-matching events returned by an untrustworthy relay',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer(
          (_) async => _confirmed([
            // Wrong kind: a relay handing back an unrelated event for the
            // same author must not be mistaken for the vault key.
            Event(pubkey, 1, const [], 'unrelated note'),
            // Right kind, wrong d tag: a different app-data document.
            Event(
              pubkey,
              30078,
              const [
                ['d', 'divine:sync:something-else'],
              ],
              'not the vault key',
            ),
          ]),
        );
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
        verify(() => client.publishEvent(any())).called(1);
      },
    );

    test('generates and publishes a key when none exists remotely', () async {
      when(
        () => client.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => _confirmed(const []));
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
      'resolves once for two concurrent calls that both miss the cache',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => _confirmed(const []));
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

        final results = await Future.wait([
          service.obtain(),
          service.obtain(),
        ]);

        final rawKeys = await Future.wait(
          results.map((key) async => base64Encode(await key.extractBytes())),
        );
        expect(rawKeys[0], equals(rawKeys[1]));
        verify(() => client.publishEvent(any())).called(1);
      },
    );

    test(
      'clears the in-flight future on failure so a later call re-queries '
      'and can succeed',
      () async {
        var queryCount = 0;
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async {
          queryCount++;
          if (queryCount == 1) {
            return (events: <Event>[], timedOut: true, noRelays: false);
          }
          return _confirmed(const []);
        });
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

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );

        // If the failed future's in-flight entry were never cleared, this
        // second call would return the same already-rejected future
        // instead of re-querying — asserted below via queryCount rather
        // than just "does this resolve", since a stuck future would also
        // (wrongly) throw here, which could be mistaken for "still
        // guarding against forking" instead of "broken re-query".
        final obtained = await service.obtain();

        expect((await obtained.extractBytes()).length, equals(32));
        expect(queryCount, equals(2));
      },
    );

    test(
      'throws rather than forking when the relay lookup throws',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenThrow(StateError('relay unreachable'));

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verifyNever(() => client.publishEvent(any()));
      },
    );

    test(
      'throws rather than forking when no relays are connected',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer(
          (_) async => (events: <Event>[], timedOut: false, noRelays: true),
        );

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verifyNever(() => client.publishEvent(any()));
        // The dangerous failure mode is not "did it publish" but "did it
        // ever decide to generate a key at all" — deleting the noRelays
        // guard makes execution fall through to _generateAndPublish,
        // which calls nip44Encrypt before signEvent/publishEvent. Without
        // this assertion the earlier two still pass (mocktail's
        // MissingStubError on the unstubbed nip44Encrypt gets caught by
        // the generic catch and rethrown as VaultKeyUnavailableException),
        // so this is the one assertion that actually pins the invariant.
        verifyNever(() => signer.nip44Encrypt(any(), any()));
        expect(await cache.read(pubkey), isNull);
      },
    );

    test(
      'throws rather than forking when the relay query times out',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer(
          (_) async => (events: <Event>[], timedOut: true, noRelays: false),
        );

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        verifyNever(() => client.publishEvent(any()));
        // See the noRelays test above: this is the assertion that
        // actually proves generation was never reached, not just that
        // publish wasn't reached.
        verifyNever(() => signer.nip44Encrypt(any(), any()));
        expect(await cache.read(pubkey), isNull);
      },
    );

    test('throws when the signer cannot unwrap the remote key', () async {
      when(
        () => client.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer(
        (_) async => _confirmed([
          Event(
            pubkey,
            30078,
            const [
              ['d', vaultKeyDTag],
            ],
            'wrapped-ciphertext',
          ),
        ]),
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
      verifyNever(
        () => client.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
        ),
      );
    });

    test(
      'does not leak the key material when the cached value fails to '
      'decode',
      () async {
        const badKey = '@@@@this-looks-like-a-leaked-vault-key@@@@';
        await cache.write(pubkey, badKey);

        await expectLater(
          service.obtain(),
          throwsA(
            isA<VaultKeyUnavailableException>().having(
              (e) => e.message,
              'message',
              isNot(contains(badKey)),
            ),
          ),
        );
      },
    );

    test(
      'throws rather than forking when the cached key is not valid base64',
      () async {
        await cache.write(pubkey, '@@@@not-base64@@@@');

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
      },
    );

    test(
      'throws rather than forking when the cached key is the wrong length',
      () async {
        await cache.write(pubkey, base64Encode(List<int>.filled(16, 0)));

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
      },
    );

    test(
      'throws and does not poison the cache when the unwrapped key is '
      'not valid base64',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer(
          (_) async => _confirmed([
            Event(
              pubkey,
              30078,
              const [
                ['d', vaultKeyDTag],
              ],
              'wrapped-ciphertext',
            ),
          ]),
        );
        when(
          () => signer.nip44Decrypt(pubkey, any()),
        ).thenAnswer((_) async => '@@@@not-base64@@@@');

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        expect(await cache.read(pubkey), isNull);
      },
    );

    test(
      'throws and does not poison the cache when the unwrapped key is '
      'the wrong length',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer(
          (_) async => _confirmed([
            Event(
              pubkey,
              30078,
              const [
                ['d', vaultKeyDTag],
              ],
              'wrapped-ciphertext',
            ),
          ]),
        );
        when(() => signer.nip44Decrypt(pubkey, any())).thenAnswer(
          (_) async => base64Encode(List<int>.filled(16, 0)),
        );

        await expectLater(
          service.obtain(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        expect(await cache.read(pubkey), isNull);
      },
    );

    test(
      'throws rather than forking when the signer errors unwrapping the '
      'remote key',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer(
          (_) async => _confirmed([
            Event(
              pubkey,
              30078,
              const [
                ['d', vaultKeyDTag],
              ],
              'wrapped-ciphertext',
            ),
          ]),
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
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => _confirmed(const []));
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
      'does not leak the vault key material when the signer echoes '
      'request params in its wrap-refusal error',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => _confirmed(const []));
        when(() => signer.nip44Encrypt(pubkey, any())).thenAnswer((
          invocation,
        ) async {
          final plaintext = invocation.positionalArguments[1] as String;
          throw StateError('bunker rejected request for $plaintext');
        });

        await expectLater(
          service.obtain(),
          throwsA(
            isA<VaultKeyUnavailableException>().having(
              (e) => e.message,
              'message',
              isNot(contains('bunker rejected')),
            ),
          ),
        );
      },
    );

    test(
      'throws rather than forking when the signer returns an empty wrap',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => _confirmed(const []));
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
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => _confirmed(const []));
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
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => _confirmed(const []));
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
