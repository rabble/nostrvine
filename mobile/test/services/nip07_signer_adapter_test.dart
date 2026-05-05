// ABOUTME: Tests for Nip07SignerAdapter, which adapts Nip07Service to NostrSigner.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/nip07_service.dart';
import 'package:openvine/services/nip07_signer_adapter.dart';

class _MockNip07Service extends Mock implements Nip07Service {}

void main() {
  const testPubkey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group(Nip07SignerAdapter, () {
    late _MockNip07Service mockService;

    setUp(() {
      mockService = _MockNip07Service();
    });

    test(
      'signEvent forwards the event map and returns a signed Event',
      () async {
        final unsigned = Event(testPubkey, EventKind.textNote, [], 'hi');
        when(() => mockService.signEvent(any())).thenAnswer(
          (_) async => Nip07SignResult.success({
            'id': 'a' * 64,
            'pubkey': testPubkey,
            'created_at': unsigned.createdAt,
            'kind': EventKind.textNote,
            'tags': <List<String>>[],
            'content': 'hi',
            'sig': 'b' * 128,
          }),
        );

        final adapter = Nip07SignerAdapter(mockService);

        final signed = await adapter.signEvent(unsigned);

        expect(signed, isNotNull);
        expect(signed!.id, equals('a' * 64));
        expect(signed.sig, equals('b' * 128));
        expect(signed.pubkey, equals(testPubkey));
      },
    );

    test('signEvent returns null when the service reports failure', () async {
      final unsigned = Event(testPubkey, EventKind.textNote, [], 'hi');
      when(() => mockService.signEvent(any())).thenAnswer(
        (_) async =>
            Nip07SignResult.failure('user rejected', code: 'USER_REJECTED'),
      );

      final adapter = Nip07SignerAdapter(mockService);

      final signed = await adapter.signEvent(unsigned);

      expect(signed, isNull);
    });

    test('encrypt delegates to encryptMessage', () async {
      when(
        () => mockService.encryptMessage(any(), any()),
      ).thenAnswer((_) async => 'cipher');

      final adapter = Nip07SignerAdapter(mockService);

      final result = await adapter.encrypt(testPubkey, 'hello');

      expect(result, equals('cipher'));
      verify(() => mockService.encryptMessage(testPubkey, 'hello')).called(1);
    });

    test('decrypt delegates to decryptMessage', () async {
      when(
        () => mockService.decryptMessage(any(), any()),
      ).thenAnswer((_) async => 'plaintext');

      final adapter = Nip07SignerAdapter(mockService);

      final result = await adapter.decrypt(testPubkey, 'cipher');

      expect(result, equals('plaintext'));
    });

    test('nip44Encrypt delegates to nip44EncryptMessage', () async {
      when(
        () => mockService.nip44EncryptMessage(any(), any()),
      ).thenAnswer((_) async => 'nip44-cipher');

      final adapter = Nip07SignerAdapter(mockService);

      final result = await adapter.nip44Encrypt(testPubkey, 'hello');

      expect(result, equals('nip44-cipher'));
    });

    test('nip44Decrypt delegates to nip44DecryptMessage', () async {
      when(
        () => mockService.nip44DecryptMessage(any(), any()),
      ).thenAnswer((_) async => 'plaintext');

      final adapter = Nip07SignerAdapter(mockService);

      final result = await adapter.nip44Decrypt(testPubkey, 'cipher');

      expect(result, equals('plaintext'));
    });

    test('getPublicKey returns the cached service publicKey', () async {
      when(() => mockService.publicKey).thenReturn(testPubkey);

      final adapter = Nip07SignerAdapter(mockService);

      expect(await adapter.getPublicKey(), equals(testPubkey));
    });

    test(
      'getRelays returns null when the extension does not expose relays',
      () async {
        when(() => mockService.userRelays).thenReturn(null);

        final adapter = Nip07SignerAdapter(mockService);

        expect(await adapter.getRelays(), isNull);
      },
    );

    test('close() is a no-op', () {
      final adapter = Nip07SignerAdapter(mockService);

      expect(adapter.close, returnsNormally);
    });
  });
}
