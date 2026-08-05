// ABOUTME: Tests for the relay-URL admission policy shared across packages.
// ABOUTME: Covers the self-supplied rule, the remote-supplied host filter,
// ABOUTME: and the cap applied to untrusted relay lists (#6585).

import 'package:nostr_sdk/utils/relay_url_policy.dart';
import 'package:test/test.dart';

void main() {
  group('isRelayUrlAllowed', () {
    test('accepts wss:// for any host', () {
      expect(isRelayUrlAllowed('wss://relay.divine.video'), isTrue);
      expect(isRelayUrlAllowed('wss://relay.example.com:4848'), isTrue);
    });

    test('accepts ws:// only for local-stack loopback hosts', () {
      expect(isRelayUrlAllowed('ws://localhost:7777'), isTrue);
      expect(isRelayUrlAllowed('ws://127.0.0.1:7777'), isTrue);
      expect(isRelayUrlAllowed('ws://10.0.2.2:7777'), isTrue);
      expect(isRelayUrlAllowed('ws://relay.example.com'), isFalse);
    });

    test('rejects non-WebSocket schemes', () {
      for (final url in [
        'https://relay.example.com',
        'http://localhost',
        'ftp://relay.example.com',
        'relay.example.com',
      ]) {
        expect(isRelayUrlAllowed(url), isFalse, reason: url);
      }
    });

    test('rejects malformed and mis-nested URLs', () {
      expect(isRelayUrlAllowed(''), isFalse);
      expect(isRelayUrlAllowed('wss://'), isFalse);
      expect(isRelayUrlAllowed('wss://http://evil.example'), isFalse);
    });
  });

  group('isRemoteSuppliedRelayUrlAllowed', () {
    test('accepts an ordinary public wss relay', () {
      expect(isRemoteSuppliedRelayUrlAllowed('wss://inbox.nostr.wine'), isTrue);
      expect(
        isRemoteSuppliedRelayUrlAllowed('wss://relay.example.com:4848/path'),
        isTrue,
      );
    });

    test('refuses loopback even over wss, unlike the self-supplied rule', () {
      for (final url in [
        'wss://localhost',
        'wss://127.0.0.1',
        'wss://10.0.2.2',
        'wss://[::1]',
      ]) {
        expect(isRelayUrlAllowed(url), isTrue, reason: '$url self-supplied');
        expect(
          isRemoteSuppliedRelayUrlAllowed(url),
          isFalse,
          reason: '$url remote-supplied',
        );
      }
    });

    test('refuses RFC1918, CGNAT, link-local and multicast targets', () {
      for (final url in [
        'wss://10.1.2.3',
        'wss://172.16.5.5',
        'wss://172.31.255.254',
        'wss://192.168.1.1',
        'wss://169.254.169.254', // cloud metadata
        'wss://100.64.0.1', // CGNAT / Tailscale range
        'wss://0.0.0.0',
        'wss://239.1.1.1', // multicast
      ]) {
        expect(isRemoteSuppliedRelayUrlAllowed(url), isFalse, reason: url);
      }
    });

    test('refuses IPv6 private, link-local and mapped-IPv4 forms', () {
      for (final url in [
        'wss://[fe80::1]',
        'wss://[fc00::1]',
        'wss://[fd12:3456::1]',
        'wss://[::ffff:192.168.0.1]',
        'wss://[::ffff:127.0.0.1]',
        'wss://[ff02::1]',
      ]) {
        expect(isRemoteSuppliedRelayUrlAllowed(url), isFalse, reason: url);
      }
    });

    test('refuses alternate IPv4 literal encodings of private space', () {
      for (final url in [
        'wss://2130706433', // 127.0.0.1 as a single integer
        'wss://0x7f.0.0.1', // hex first octet
        'wss://127.1', // inet_aton short form
        'wss://0300.0250.0.1', // octal 192.168.0.1
      ]) {
        expect(isRemoteSuppliedRelayUrlAllowed(url), isFalse, reason: url);
      }
    });

    test('refuses private-network hostname suffixes', () {
      for (final url in [
        'wss://printer.local',
        'wss://db.internal',
        'wss://router.home.arpa',
      ]) {
        expect(isRemoteSuppliedRelayUrlAllowed(url), isFalse, reason: url);
      }
    });

    test('refuses ws:// outright — cleartext is never remote-legitimate', () {
      expect(isRemoteSuppliedRelayUrlAllowed('ws://localhost'), isFalse);
      expect(
        isRemoteSuppliedRelayUrlAllowed('ws://relay.example.com'),
        isFalse,
      );
    });

    test(
      'does not refuse ordinary public addresses that merely look close',
      () {
        for (final url in [
          'wss://11.0.0.1', // adjacent to 10/8
          'wss://172.15.0.1', // just below 172.16/12
          'wss://172.32.0.1', // just above 172.16/12
          'wss://192.169.0.1', // adjacent to 192.168/16
          'wss://100.63.0.1', // just below CGNAT
          'wss://8.8.8.8',
        ]) {
          expect(isRemoteSuppliedRelayUrlAllowed(url), isTrue, reason: url);
        }
      },
    );
  });

  group('admitRemoteSuppliedRelays', () {
    test('caps the list and reports the truncation', () {
      final urls = [for (var i = 0; i < 50; i++) 'wss://relay-$i.example'];
      int? keptReported;
      int? totalReported;

      final admitted = admitRemoteSuppliedRelays(
        urls,
        cap: RelayListCaps.dmInbox,
        onTruncated: (kept, total) {
          keptReported = kept;
          totalReported = total;
        },
      );

      expect(admitted, hasLength(RelayListCaps.dmInbox));
      expect(admitted.first, equals('wss://relay-0.example'));
      expect(keptReported, equals(RelayListCaps.dmInbox));
      expect(totalReported, equals(50));
    });

    test('does not report truncation when the list fits', () {
      var truncated = false;
      final admitted = admitRemoteSuppliedRelays(
        ['wss://a.example', 'wss://b.example'],
        cap: RelayListCaps.dmInbox,
        onTruncated: (_, _) => truncated = true,
      );

      expect(admitted, hasLength(2));
      expect(truncated, isFalse);
    });

    test('drops disallowed entries and reports each one', () {
      final rejected = <String>[];
      final admitted = admitRemoteSuppliedRelays(
        [
          'wss://good.example',
          'wss://192.168.1.1',
          'ws://localhost',
          'wss://also-good.example',
        ],
        cap: RelayListCaps.dmInbox,
        onRejected: rejected.add,
      );

      expect(
        admitted,
        equals(['wss://good.example', 'wss://also-good.example']),
      );
      expect(rejected, equals(['wss://192.168.1.1', 'ws://localhost']));
    });

    test('collapses duplicates before applying the cap', () {
      final admitted = admitRemoteSuppliedRelays(
        List<String>.filled(20, 'wss://same.example'),
        cap: RelayListCaps.dmInbox,
      );

      expect(admitted, equals(['wss://same.example']));
    });
  });

  group('RelayListCaps', () {
    test('sits above the sizing the NIPs recommend', () {
      // NIP-17 recommends 1-3 kind-10050 relays; NIP-65 recommends 2-4 of
      // each category. The caps bound abuse without truncating real users.
      expect(RelayListCaps.dmInbox, greaterThan(3));
      expect(RelayListCaps.nip65, greaterThan(8));
    });
  });
}
