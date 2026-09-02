// ABOUTME: Proves against the real funnelcake relay that the NIP-04 dual-send
// ABOUTME: leg's old publish path scored a relay refusal as a delivered message.
//
// Requires the local Docker stack (port 47777).
// Run: flutter test test/manual/nip04_dual_send_publish_ok_acceptance_test.dart
// Start stack: mise run local_up (from repo root)
//
// #8262. `_sendNip04Message` published the legacy kind-4 twin with
// `publishEvent`, which resolves on a WebSocket frame write rather than a
// NIP-20 `OK`. A relay that refuses the event — rate limit, kind policy, spam
// filter — therefore came back as success, and because the leg is fired
// `unawaited` nobody looked at the result anyway. The fix publishes with
// `publishEventAwaitOk` and branches on the OK boolean.
//
// A mocked relay cannot prove this: the whole claim is about what a real relay
// does to a real frame, and about the gap between "the socket took it" and
// "the relay stored it". So this test uses a real NostrClient against the
// local funnelcake, and uses kind 1 as the refusal vehicle because that relay
// answers it with `blocked: kind 1 not in allowed list` while accepting kind 4.

// Permanent: a manual, Docker-dependent real-network acceptance test. File-level
// @Tags are dropped inside the merged VGV bundle, so 'integration' alone cannot
// keep this file out of CI (#5340, #5738); the skip tag runs it as a separate
// suite, which --exclude-tags integration then skips.
@Tags(['skip_very_good_optimization', 'integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

const _localHost = 'localhost';
const _localRelayPort = 47777;
const _wsUrl = 'ws://$_localHost:$_localRelayPort';
const _localStackUnavailableMessage =
    'Local stack is not running. Start with `mise run local_up`, then rerun '
    '`flutter test test/manual/nip04_dual_send_publish_ok_acceptance_test.dart`.';

/// The kind the local funnelcake refuses. Kind 4 — the one the dual-send leg
/// actually publishes — is accepted, so it serves as the control.
const _refusedKind = 1;
const _directMessageKind = 4;
const _testTimeout = Timeout(Duration(seconds: 90));

Future<bool> _isPortOpen(String host, int port) async {
  try {
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 3),
    );
    socket.destroy();
    return true;
  } on Object {
    return false;
  }
}

Future<NostrClient> _connectedClient(String privateKeyHex) async {
  final client = NostrClient(
    config: NostrClientConfig(signer: LocalNostrSigner(privateKeyHex)),
    relayManagerConfig: const RelayManagerConfig(defaultRelayUrl: _wsUrl),
  );
  // addRelay must be awaited BEFORE initialize().
  await client.addRelay(_wsUrl);
  await client.initialize();
  return client;
}

void main() {
  late bool stackAvailable;

  setUpAll(() async {
    stackAvailable = await _isPortOpen(_localHost, _localRelayPort);
  });

  group('NIP-04 dual-send leg: publish confirmation (#8262)', () {
    test(
      'control: the relay accepts a kind 4, and publishEventAwaitOk says so',
      () async {
        if (!stackAvailable) {
          fail(_localStackUnavailableMessage);
        }
        final sk = generatePrivateKey();
        final client = await _connectedClient(sk);
        addTearDown(client.dispose);

        final event = Event(
          getPublicKey(sk),
          _directMessageKind,
          [
            ['p', getPublicKey(generatePrivateKey())],
          ],
          'S+vJHha3hKlIVGDAcPMcuQ==?iv=u0N6sga+ySQOoojAX/C7dA==',
        );

        final outcome = await client.publishEventAwaitOk(event);

        expect(
          outcome.acceptedByAny,
          isTrue,
          reason: 'the relay accepts kind 4; ${outcome.summary}',
        );
        expect(outcome.rejectedBy, isEmpty);
      },
      timeout: _testTimeout,
    );

    test(
      'publishEvent reports SUCCESS for an event the relay REFUSED — the '
      'false delivery the old NIP-04 leg shipped',
      () async {
        if (!stackAvailable) {
          fail(_localStackUnavailableMessage);
        }
        final sk = generatePrivateKey();
        final client = await _connectedClient(sk);
        addTearDown(client.dispose);

        final refused = Event(
          getPublicKey(sk),
          _refusedKind,
          const <List<String>>[],
          'the relay will refuse this',
        );

        final result = await client.publishEvent(refused);

        // This is the defect, not the desired behaviour: the frame was
        // written, so the old path called it delivered.
        expect(
          result.isSuccess,
          isTrue,
          reason:
              'publishEvent resolves on the frame write, so a refusal still '
              'looks like success — this is what #8262 mode 5 describes',
        );
        expect(
          result.failureReason,
          isNull,
          reason: 'and it carries no reason for the caller to inspect',
        );
      },
      timeout: _testTimeout,
    );

    test(
      'publishEventAwaitOk reports the SAME event as refused, with the '
      "relay's reason — what the fixed leg now sees",
      () async {
        if (!stackAvailable) {
          fail(_localStackUnavailableMessage);
        }
        final sk = generatePrivateKey();
        final client = await _connectedClient(sk);
        addTearDown(client.dispose);

        final refused = Event(
          getPublicKey(sk),
          _refusedKind,
          const <List<String>>[],
          'the relay will refuse this',
        );

        final outcome = await client.publishEventAwaitOk(refused);

        expect(
          outcome.acceptedByAny,
          isFalse,
          reason: 'no relay returned OK true; ${outcome.summary}',
        );
        expect(outcome.rejectedBy, isNotEmpty);
        // Recorded rather than asserted verbatim: the wording is the relay's,
        // and pinning it would make this test a change-detector for funnelcake
        // copy. What matters is that a reason reached the client at all.
        expect(
          outcome.rejectedBy.values.single,
          contains('blocked'),
          reason: 'reason from relay: ${outcome.rejectedBy}',
        );
      },
      timeout: _testTimeout,
    );
  });
}
