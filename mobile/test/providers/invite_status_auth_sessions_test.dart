// ABOUTME: Tests the invite status bridge onto the Nostr readiness contract.
// ABOUTME: Pins that a late signer still reaches the invite status cubit.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/providers/invite_status_auth_sessions.dart';
import 'package:openvine/providers/nostr_client_provider.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this._initialReadiness);

  final NostrSessionReadiness _initialReadiness;

  @override
  NostrSessionReadiness build() => _initialReadiness;

  void setReadiness(NostrSessionReadiness readiness) {
    state = readiness;
  }
}

void main() {
  // A Keycast identity with no local key: the pubkey is known well before the
  // remote signer is usable.
  const keycastPubkey =
      'fc7031a810ce4b02b6195a7e477cfe3d08c0386038bd45b4431f82d9b3f5ffb0';

  late _MockNostrClient nostrClient;

  setUp(() {
    nostrClient = _MockNostrClient();
    when(() => nostrClient.hasKeys).thenReturn(true);
    when(() => nostrClient.publicKey).thenReturn(keycastPubkey);
  });

  NostrSessionReadiness readySession() => NostrSessionReadiness.nostrReady(
    pubkey: keycastPubkey,
    client: nostrClient,
  );

  group('inviteStatusAuthSessionOf', () {
    test('reports no signer while only the identity is known', () {
      final session = inviteStatusAuthSessionOf(
        const NostrSessionReadiness.identityKnown(pubkey: keycastPubkey),
      );

      expect(session.accountId, equals(keycastPubkey));
      expect(session.isSignerReady, isFalse);
    });

    test('reports a signer once the session is nostr ready', () {
      final session = inviteStatusAuthSessionOf(readySession());

      expect(session.accountId, equals(keycastPubkey));
      expect(session.isSignerReady, isTrue);
    });

    test('reports no account while signed out', () {
      final session = inviteStatusAuthSessionOf(
        const NostrSessionReadiness.signedOut(),
      );

      expect(session.accountId, isNull);
      expect(session.isSignerReady, isFalse);
    });
  });

  group('inviteStatusAuthSessionsProvider', () {
    // Reading auth state instead of readiness makes this await forever rather
    // than fail, so the await is bounded (#6977).
    const awaitBound = Duration(seconds: 5);

    test(
      'emits a ready session when the signer arrives after the identity',
      () async {
        final nostrSession = _TestNostrSession(
          const NostrSessionReadiness.identityKnown(pubkey: keycastPubkey),
        );
        final container = ProviderContainer(
          overrides: [nostrSessionProvider.overrideWith(() => nostrSession)],
        );
        addTearDown(container.dispose);

        final sessions = container.read(inviteStatusAuthSessionsProvider);
        final firstSession = sessions.first.timeout(awaitBound);

        nostrSession.setReadiness(readySession());

        expect(
          await firstSession,
          equals(
            const InviteStatusAuthSession(
              accountId: keycastPubkey,
              isSignerReady: true,
            ),
          ),
        );
      },
    );
  });
}
