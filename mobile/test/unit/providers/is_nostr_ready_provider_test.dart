import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this.readiness);

  final NostrSessionReadiness readiness;

  @override
  NostrSessionReadiness build() => readiness;
}

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  ProviderContainer createContainer(NostrSessionReadiness readiness) {
    return ProviderContainer(
      overrides: [
        nostrSessionProvider.overrideWith(() => _TestNostrSession(readiness)),
      ],
    );
  }

  test('is false until the Nostr session has a matching ready client', () {
    final client = _MockNostrClient();
    when(() => client.hasKeys).thenReturn(true);
    when(() => client.publicKey).thenReturn(pubkey);

    final signedOut = createContainer(const NostrSessionReadiness.signedOut());
    addTearDown(signedOut.dispose);

    expect(signedOut.read(isNostrReadyProvider), isFalse);

    final identityKnown = createContainer(
      const NostrSessionReadiness.identityKnown(pubkey: pubkey),
    );
    addTearDown(identityKnown.dispose);

    expect(identityKnown.read(isNostrReadyProvider), isFalse);

    final ready = createContainer(
      NostrSessionReadiness.nostrReady(pubkey: pubkey, client: client),
    );
    addTearDown(ready.dispose);

    expect(ready.read(isNostrReadyProvider), isTrue);
  });
}
