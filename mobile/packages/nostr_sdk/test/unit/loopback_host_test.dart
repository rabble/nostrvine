// ABOUTME: Tests for the loopback-host TLS allowance predicate.
// ABOUTME: Pins that bad certificates are only tolerated for local-stack hosts.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/utils/loopback_host.dart';

void main() {
  group('isLoopbackHost', () {
    test('returns true for localhost', () {
      expect(isLoopbackHost('localhost'), isTrue);
    });

    test('returns true for 127.0.0.1', () {
      expect(isLoopbackHost('127.0.0.1'), isTrue);
    });

    test('returns true for IPv6 loopback ::1', () {
      expect(isLoopbackHost('::1'), isTrue);
    });

    test('returns true for the Android emulator host alias 10.0.2.2', () {
      expect(isLoopbackHost('10.0.2.2'), isTrue);
    });

    test('is case-insensitive for localhost', () {
      expect(isLoopbackHost('LOCALHOST'), isTrue);
    });

    test('returns false for the divine relay host', () {
      expect(isLoopbackHost('relay.divine.video'), isFalse);
    });

    test('returns false for the funnelcake API host', () {
      expect(isLoopbackHost('api.divine.video'), isFalse);
    });

    test('returns false for a host that merely contains localhost', () {
      expect(isLoopbackHost('localhost.attacker.example'), isFalse);
      expect(isLoopbackHost('evil-localhost'), isFalse);
    });

    test('returns false for a spoofed loopback-prefixed IP', () {
      expect(isLoopbackHost('127.0.0.1.attacker.example'), isFalse);
    });

    test('returns false for an arbitrary LAN address', () {
      expect(isLoopbackHost('192.168.1.10'), isFalse);
    });
  });
}
