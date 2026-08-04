// ABOUTME: Shared mocktail stubs for the publish paths CuratedListService uses.
// ABOUTME: Covers relay publishing plus the NIP-44 sealing of private lists.

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/services/auth_service.dart';

class MockNostrSigner extends Mock implements NostrSigner {}

/// Registered here rather than in each caller's `setUpAll`, so stubbing a
/// publish path is one call regardless of which matchers it needs.
void _registerEventFallback() {
  registerFallbackValue(
    Event(
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      1,
      <List<String>>[],
      '',
    ),
  );
}

/// Stand-in for NIP-44 that a test can reverse.
///
/// The real cipher needs a key pair the service never sees, and asserting on
/// what a list sealed matters more here than asserting how it sealed it.
String sealForTest(String plaintext) => 'sealed:$plaintext';

/// The inverse of [sealForTest]; `null` when [ciphertext] was never sealed,
/// which is how a public list's plain description reads.
String? unsealForTest(String ciphertext) =>
    ciphertext.startsWith('sealed:') ? ciphertext.substring(7) : null;

/// An outcome one relay accepted — what [PublishOutcome.acceptedByAny] gates on.
PublishOutcome acceptedOutcome(Event event) => PublishOutcome(
  eventId: event.id,
  eventKind: event.kind,
  acceptedBy: const ['wss://relay.test'],
  rejectedBy: const {},
  noResponseFrom: const [],
);

/// An outcome no relay accepted, so the caller may roll local state back.
PublishOutcome rejectedOutcome(Event event) => PublishOutcome(
  eventId: event.id,
  eventKind: event.kind,
  acceptedBy: const [],
  rejectedBy: const {'wss://relay.test': 'blocked'},
  noResponseFrom: const [],
);

/// Stubs [client]'s signer so private lists can be sealed and unsealed.
///
/// Every owned list publishes now, so a service test that creates any list at
/// all reaches the signer; without this the mock returns null for
/// `NostrClient.signer` and the publish dies on a type error rather than
/// whatever the test is about.
MockNostrSigner stubListSigner(NostrClient client) {
  _registerEventFallback();
  final signer = MockNostrSigner();
  when(() => client.signer).thenReturn(signer);
  when(
    () => signer.nip44Encrypt(any(), any()),
  ).thenAnswer((i) async => sealForTest(i.positionalArguments[1] as String));
  when(
    () => signer.nip44Decrypt(any(), any()),
  ).thenAnswer((i) async => unsealForTest(i.positionalArguments[1] as String));
  return signer;
}

/// Stubs signing and relay acceptance so `createList` reaches a list object.
///
/// For a test that is about something else — ownership, persistence, queries —
/// and only needs list creation to get that far.
void stubListPublishing({
  required NostrClient client,
  required AuthService auth,
  required String pubkey,
}) {
  stubListSigner(client);
  when(
    () => auth.createAndSignEvent(
      kind: any(named: 'kind'),
      content: any(named: 'content'),
      tags: any(named: 'tags'),
    ),
  ).thenAnswer(
    (i) async => Event(
      pubkey,
      i.namedArguments[#kind] as int,
      i.namedArguments[#tags] as List<List<String>>,
      i.namedArguments[#content] as String,
    ),
  );
  when(
    () => client.publishEventAwaitOk(any()),
  ).thenAnswer((i) async => acceptedOutcome(i.positionalArguments[0] as Event));
  when(() => client.publishEvent(any())).thenAnswer(
    (i) async => PublishSuccess(event: i.positionalArguments[0] as Event),
  );
}
