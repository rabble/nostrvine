import 'dart:convert';
import 'dart:io';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

const _supportedKinds = <int>[
  0,
  3,
  4,
  5,
  6,
  7,
  14,
  15,
  1111,
  1984,
  10000,
  10003,
  30000,
  30003,
  30005,
  34235,
  34236,
  22236,
];

Event buildHandlerEvent() {
  final tags = <List<String>>[
    ['d', Nip89ClientTag.handlerDIdentifier],
    ['alt', 'Divine mobile app handler'],
    ['web', 'https://divine.video'],
    ['r', 'https://divine.video'],
    for (final kind in _supportedKinds) ['k', '$kind'],
  ];

  final content = jsonEncode(<String, Object?>{
    'name': Nip89ClientTag.clientName,
    'display_name': Nip89ClientTag.clientName,
    'about': 'Short-form looping video app on Nostr.',
    'website': 'https://divine.video',
  });

  return Event(Nip89ClientTag.handlerPubkey, 31990, tags, content);
}

Future<void> main(List<String> args) async {
  final publish = args.contains('--publish');
  final rawSecret = Platform.environment['NIP89_HANDLER_NSEC'];
  final event = buildHandlerEvent();

  if (rawSecret == null || rawSecret.isEmpty) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(event.toJson()));
    if (publish) {
      stderr.writeln(
        'Set NIP89_HANDLER_NSEC to the handler private key before using '
        '--publish.',
      );
      exitCode = 64;
    }
    return;
  }

  final privateKey = rawSecret.startsWith('nsec1')
      ? Nip19.decode(rawSecret)
      : rawSecret;
  final signer = LocalNostrSigner(privateKey);
  final derivedPubkey = await signer.getPublicKey();
  if (derivedPubkey != Nip89ClientTag.handlerPubkey) {
    stderr.writeln(
      'NIP89_HANDLER_NSEC does not match '
      '${Nip89ClientTag.handlerPubkey}.',
    );
    exitCode = 64;
    return;
  }

  final signed = await signer.signEvent(event);
  if (signed == null) {
    stderr.writeln('Failed to sign handler event.');
    exitCode = 1;
    return;
  }

  stdout.writeln(const JsonEncoder.withIndent('  ').convert(signed.toJson()));

  if (!publish) {
    return;
  }

  final nostr = Nostr(
    signer,
    const [],
    (url) => RelayBase(url, RelayStatus(url)),
  );
  await nostr.refreshPublicKey();

  final sent = await nostr.sendEvent(
    signed,
    tempRelays: const [Nip89ClientTag.relayHint],
    targetRelays: const [Nip89ClientTag.relayHint],
  );
  if (sent == null) {
    stderr.writeln('Publish failed.');
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Published kind 31990 event ${sent.id} to ${Nip89ClientTag.relayHint}.',
  );
}
