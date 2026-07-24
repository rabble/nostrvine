// ABOUTME: Tests for the AccountScope / AccountSession account-boundary model.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/services/auth/account_scope.dart';
import 'package:openvine/services/auth/nostr_identity.dart';

class _MockSecureKeyContainer extends Mock implements SecureKeyContainer {}

NostrIdentity _identityFor(String pubkey) {
  final container = _MockSecureKeyContainer();
  when(() => container.publicKeyHex).thenReturn(pubkey);
  return LocalNostrIdentity(keyContainer: container);
}

void main() {
  const pubkeyA =
      'aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111';
  const pubkeyB =
      'bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222';

  late NostrIdentity identity;

  setUp(() {
    identity = _identityFor(pubkeyA);
  });

  AccountSession sessionFor(String pubkey) => AccountSession(
    pubkeyHex: pubkey,
    identity: identity,
    source: AuthenticationSource.automatic,
  );

  group(AccountScope, () {
    test('SignedOut exposes a null active pubkey', () {
      expect(const SignedOut().activePubkeyHex, isNull);
    });

    test('SignedIn exposes its session pubkey', () {
      final scope = SignedIn(sessionFor(pubkeyA));
      expect(scope.activePubkeyHex, equals(pubkeyA));
    });

    test('an exhaustive switch routes each case', () {
      String describe(AccountScope scope) => switch (scope) {
        SignedOut() => 'out',
        SignedIn(:final session) => 'in:${session.pubkeyHex}',
      };

      expect(describe(const SignedOut()), equals('out'));
      expect(describe(SignedIn(sessionFor(pubkeyB))), equals('in:$pubkeyB'));
    });

    test('all SignedOut instances are equal', () {
      expect(const SignedOut(), equals(const SignedOut()));
      expect(const SignedOut(), isNot(equals(SignedIn(sessionFor(pubkeyA)))));
    });

    test('SignedIn equality tracks the wrapped session', () {
      expect(
        SignedIn(sessionFor(pubkeyA)),
        equals(SignedIn(sessionFor(pubkeyA))),
      );
      expect(
        SignedIn(sessionFor(pubkeyA)),
        isNot(equals(SignedIn(sessionFor(pubkeyB)))),
      );
    });
  });

  group(AccountSession, () {
    test('is equal by value for the same fields', () {
      expect(sessionFor(pubkeyA), equals(sessionFor(pubkeyA)));
    });

    test('differs when the pubkey differs', () {
      expect(sessionFor(pubkeyA), isNot(equals(sessionFor(pubkeyB))));
    });

    test('differs when the identity differs', () {
      final other = AccountSession(
        pubkeyHex: pubkeyA,
        identity: _identityFor(pubkeyA),
        source: AuthenticationSource.automatic,
      );
      expect(sessionFor(pubkeyA), isNot(equals(other)));
    });

    test('differs when the auth source differs', () {
      final bunker = AccountSession(
        pubkeyHex: pubkeyA,
        identity: identity,
        source: AuthenticationSource.bunker,
      );
      expect(sessionFor(pubkeyA), isNot(equals(bunker)));
    });
  });
}
