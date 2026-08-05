// ABOUTME: Tests for the loopback-host TLS allowance predicate.
// ABOUTME: Pins that bad certificates are only tolerated for local-stack hosts.

import 'dart:io';

import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/relay_base_io.dart';
import 'package:nostr_sdk/utils/dio_util.dart';

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

  group('isPrivateOrLinkLocalHost', () {
    test('covers every loopback host the local stack uses', () {
      for (final host in ['localhost', '127.0.0.1', '10.0.2.2', '::1']) {
        expect(isPrivateOrLinkLocalHost(host), isTrue, reason: host);
      }
    });

    test('treats an empty or unparseable host as private', () {
      expect(isPrivateOrLinkLocalHost(''), isTrue);
      expect(isPrivateOrLinkLocalHost('   '), isTrue);
    });

    test('strips brackets from an IPv6 literal read off a URI', () {
      expect(isPrivateOrLinkLocalHost('[fe80::1]'), isTrue);
      expect(isPrivateOrLinkLocalHost('[2606:4700::1111]'), isFalse);
    });

    test('is case-insensitive', () {
      expect(isPrivateOrLinkLocalHost('LOCALHOST'), isTrue);
      expect(isPrivateOrLinkLocalHost('Printer.LOCAL'), isTrue);
    });

    test('leaves ordinary public hosts alone', () {
      for (final host in [
        'relay.divine.video',
        'inbox.nostr.wine',
        '8.8.8.8',
        '2606:4700:4700::1111',
      ]) {
        expect(isPrivateOrLinkLocalHost(host), isFalse, reason: host);
      }
    });
  });

  group('allowsLocalBadCertificateHost', () {
    test('allows loopback hosts only in debug builds', () {
      expect(allowsLocalBadCertificateHost('localhost'), kDebugMode);
      expect(allowsLocalBadCertificateHost('10.0.2.2'), kDebugMode);
    });

    test('always rejects remote hosts', () {
      expect(allowsLocalBadCertificateHost('relay.divine.video'), isFalse);
      expect(allowsLocalBadCertificateHost('api.divine.video'), isFalse);
    });
  });

  group('call-site certificate callbacks', () {
    late _FakeCertificate cert;

    setUp(() {
      cert = _FakeCertificate();
    });

    test('relay websocket HttpClient rejects bad remote certificates', () {
      final client = _RecordingHttpClient();

      HttpOverrides.runZoned(
        createSecureWebSocketHttpClient,
        createHttpClient: (_) => client,
      );

      final callback = client.recordedBadCertificateCallback;
      expect(callback, isNotNull);
      expect(callback!(cert, 'relay.divine.video', 443), isFalse);
      expect(callback(cert, 'localhost', 443), kDebugMode);
    });

    test('DioUtil wires the same bad certificate policy into Dio', () {
      DioUtil.resetForTesting();
      addTearDown(DioUtil.resetForTesting);
      final client = _RecordingHttpClient();

      HttpOverrides.runZoned(() {
        final dio = DioUtil.getDio();
        final adapter = dio.httpClientAdapter;

        expect(adapter, isA<IOHttpClientAdapter>());
        final createHttpClient =
            (adapter as IOHttpClientAdapter).createHttpClient;
        expect(createHttpClient, isNotNull);
        expect(createHttpClient!(), same(client));
      }, createHttpClient: (_) => client);

      final callback = client.recordedBadCertificateCallback;
      expect(callback, isNotNull);
      expect(callback!(cert, 'api.divine.video', 443), isFalse);
      expect(callback(cert, '10.0.2.2', 443), kDebugMode);
    });

    test('loopback predicate is exported from the package barrel', () {
      expect(isLoopbackHost('127.0.0.1'), isTrue);
      expect(allowsLocalBadCertificateHost('relay.divine.video'), isFalse);
    });
  });
}

class _FakeCertificate implements X509Certificate {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingHttpClient implements HttpClient {
  bool Function(X509Certificate cert, String host, int port)?
  recordedBadCertificateCallback;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) {
    recordedBadCertificateCallback = callback;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
