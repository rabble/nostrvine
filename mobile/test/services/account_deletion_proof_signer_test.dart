// ABOUTME: Tests for AccountDeletionProofSigner - the 403 retry credential
// ABOUTME: Verifies the proof is pinned to the account whose token is spent

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/account_deletion_proof_signer.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

class _FakeNip98Token extends Fake implements Nip98Token {
  @override
  String get token => 'BASE64EVENT';
}

void main() {
  group(AccountDeletionProofSigner, () {
    final tokenOwner = 'a' * 64;
    final otherAccount = 'b' * 64;
    const url = 'https://login.divine.video/api/user/account';

    late _MockNip98AuthService nip98Auth;
    late int builds;

    setUp(() {
      nip98Auth = _MockNip98AuthService();
      builds = 0;
      registerFallbackValue(HttpMethod.delete);
    });

    /// A signer whose active account is whatever [activePubkey] returns.
    AccountDeletionProofSigner signerFor(String? Function() activePubkey) {
      return AccountDeletionProofSigner(
        buildNip98Auth: () {
          builds++;
          return nip98Auth;
        },
        activePubkey: activePubkey,
      );
    }

    void stubSigning({Nip98Token? returns}) {
      when(
        () => nip98Auth.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
        ),
      ).thenAnswer((_) async => returns);
    }

    test('signs when the account still owns the token', () async {
      stubSigning(returns: _FakeNip98Token());

      final proof = await signerFor(
        () => tokenOwner,
      ).sign(url, tokenOwnerPubkey: tokenOwner);

      expect(proof, 'BASE64EVENT');
    });

    test(
      'refuses, without signing, when the account already differs',
      () async {
        stubSigning(returns: _FakeNip98Token());

        final proof = await signerFor(
          () => otherAccount,
        ).sign(url, tokenOwnerPubkey: tokenOwner);

        expect(proof, isNull);
        verifyNever(
          () => nip98Auth.createAuthToken(
            url: any(named: 'url'),
            method: any(named: 'method'),
          ),
        );
        expect(
          builds,
          isZero,
          reason: 'a refused pin must not build the NIP-98 service',
        );
      },
    );

    // The check that carries the weight. Signing is a remote RPC for a Keycast
    // identity, so the switch can land after the entry check has passed —
    // pairing one account's bearer token with another's proof on a delete that
    // cannot be undone.
    test('discards a proof signed while the account changed', () async {
      var active = tokenOwner;
      when(
        () => nip98Auth.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
        ),
      ).thenAnswer((_) async {
        active = otherAccount;
        return _FakeNip98Token();
      });

      final proof = await signerFor(
        () => active,
      ).sign(url, tokenOwnerPubkey: tokenOwner);

      expect(proof, isNull);
    });

    test('returns null rather than throwing when signing fails', () async {
      when(
        () => nip98Auth.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
        ),
      ).thenThrow(StateError('signer gone'));

      final proof = await signerFor(
        () => tokenOwner,
      ).sign(url, tokenOwnerPubkey: tokenOwner);

      expect(proof, isNull);
    });

    test('signs over the exact URL it is handed', () async {
      stubSigning(returns: _FakeNip98Token());

      await signerFor(() => tokenOwner).sign(url, tokenOwnerPubkey: tokenOwner);

      verify(
        () => nip98Auth.createAuthToken(url: url, method: HttpMethod.delete),
      ).called(1);
    });

    test('disposes the NIP-98 service it built', () async {
      stubSigning(returns: _FakeNip98Token());
      when(() => nip98Auth.dispose()).thenReturn(null);

      final signer = signerFor(() => tokenOwner);
      await signer.sign(url, tokenOwnerPubkey: tokenOwner);
      signer.dispose();

      verify(() => nip98Auth.dispose()).called(1);
    });
  });
}
