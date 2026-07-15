// ABOUTME: Tests the NIP-05 lookup hardening in Nip05Validor.
// ABOUTME: NIP-05 "Security Constraints" require fetchers to ignore redirects.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip05/nip05_validor.dart';

/// Captures the [RequestOptions] Dio hands the transport, and replies with a
/// canned response instead of reaching the network.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._respond);

  final ResponseBody Function() _respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _respond();
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, int status) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  group(Nip05Validor, () {
    const pubkey =
        'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef';

    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = Nip05Validor.dio.httpClientAdapter;
    });

    tearDown(() {
      Nip05Validor.dio.httpClientAdapter = originalAdapter;
    });

    _RecordingAdapter install(ResponseBody Function() respond) {
      final adapter = _RecordingAdapter(respond);
      Nip05Validor.dio.httpClientAdapter = adapter;
      return adapter;
    }

    group('getPubkey', () {
      test('returns the mapped pubkey for a well-formed nostr.json', () async {
        install(() => _json('{"names":{"bob":"$pubkey"}}', 200));

        expect(await Nip05Validor.getPubkey('bob@example.com'), pubkey);
      });

      test('queries the name as a query string, per NIP-05', () async {
        final adapter = install(
          () => _json('{"names":{"bob":"$pubkey"}}', 200),
        );

        await Nip05Validor.getPubkey('bob@example.com');

        expect(
          adapter.requests.single.uri.toString(),
          'https://example.com/.well-known/nostr.json?name=bob',
        );
      });

      test('treats a bare domain as the root `_` identifier', () async {
        final adapter = install(() => _json('{"names":{"_":"$pubkey"}}', 200));

        expect(await Nip05Validor.getPubkey('example.com'), pubkey);
        expect(
          adapter.requests.single.uri.toString(),
          'https://example.com/.well-known/nostr.json?name=_',
        );
      });

      // The assertion that actually enforces the spec constraint. A real
      // adapter follows a 30x when these flags say to; a fake never does, so
      // asserting on the outcome alone would pass even with redirects enabled.
      test('disables redirects, per NIP-05 Security Constraints', () async {
        final adapter = install(
          () => _json('{"names":{"bob":"$pubkey"}}', 200),
        );

        await Nip05Validor.getPubkey('bob@example.com');

        expect(adapter.requests.single.followRedirects, isFalse);
        expect(adapter.requests.single.maxRedirects, 0);
      });

      test('bounds the lookup with connect and receive timeouts', () async {
        final adapter = install(
          () => _json('{"names":{"bob":"$pubkey"}}', 200),
        );

        await Nip05Validor.getPubkey('bob@example.com');

        expect(
          adapter.requests.single.connectTimeout,
          const Duration(seconds: 5),
        );
        expect(
          adapter.requests.single.receiveTimeout,
          const Duration(seconds: 5),
        );
      });

      test('yields null when the endpoint answers with a redirect', () async {
        install(() => _json('', 302));

        expect(await Nip05Validor.getPubkey('bob@example.com'), isNull);
      });

      test('yields null when the name is absent from the directory', () async {
        install(() => _json('{"names":{}}', 200));

        expect(await Nip05Validor.getPubkey('bob@example.com'), isNull);
      });

      test('yields null when the origin errors', () async {
        install(() => _json('nope', 500));

        expect(await Nip05Validor.getPubkey('bob@example.com'), isNull);
      });
    });

    group('valid', () {
      test('is true when the directory maps the name to the pubkey', () async {
        install(() => _json('{"names":{"bob":"$pubkey"}}', 200));

        expect(await Nip05Validor.valid('bob@example.com', pubkey), isTrue);
      });

      test('is false when the directory maps a different key', () async {
        install(() => _json('{"names":{"bob":"${'a' * 64}"}}', 200));

        expect(await Nip05Validor.valid('bob@example.com', pubkey), isFalse);
      });
    });
  });
}
