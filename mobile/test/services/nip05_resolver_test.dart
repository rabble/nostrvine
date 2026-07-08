// ABOUTME: Tests for the discriminated NIP-05 resolver (#176) that separates
// ABOUTME: matched / differentKey / absent / networkError for graded revocation.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/nip05_resolver.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late Nip05Resolver resolver;

  const hqHex =
      'c4a39f1291291d452405cd8ddd798c4a29a3858c52cd0d843f1f6852cf17682e';
  const otherHex =
      '0000000000000000000000000000000000000000000000000000000000000000';

  setUp(() {
    dio = _MockDio();
    resolver = Nip05Resolver(dio: dio);
  });

  Response<dynamic> jsonResponse(Object? body, {int status = 200}) => Response(
    statusCode: status,
    data: body,
    requestOptions: RequestOptions(),
  );

  test('matched: name maps to the expected pubkey', () async {
    when(() => dio.get(any())).thenAnswer(
      (_) async => jsonResponse({
        'names': {'_': hqHex},
      }),
    );

    final result = await resolver.resolve('_@divinehq.divine.video', hqHex);

    expect(result.kind, Nip05ResolutionKind.matched);
    expect(result.resolvedPubkey, hqHex);
  });

  test(
    'differentKey: name maps to a different pubkey (revoke/compromise)',
    () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => jsonResponse({
          'names': {'_': otherHex},
        }),
      );

      final result = await resolver.resolve('_@divinehq.divine.video', hqHex);

      expect(result.kind, Nip05ResolutionKind.differentKey);
      expect(result.resolvedPubkey, otherHex);
    },
  );

  // NIP-05 §05: the .well-known endpoint MUST NOT redirect and fetchers MUST
  // ignore redirects. A followed/interpreted 3xx is a spurious-APPROVE vector: a
  // MITM or misconfigured origin could 30x-bounce the lookup to an attacker host
  // whose body returns the expected key for a burner. A redirect must carry no
  // signal, whichever way Dio surfaces it.
  test(
    'redirect (3xx) that Dio throws as badResponse -> networkError, never '
    'approves (the real production path with the default 2xx validateStatus)',
    () async {
      for (final code in [301, 302, 307, 308]) {
        when(() => dio.get(any())).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              statusCode: code,
              // A hostile redirect could even carry a matching body; it must
              // still never resolve to matched.
              data: {
                'names': {'_': hqHex},
              },
              requestOptions: RequestOptions(),
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        final result = await resolver.resolve('_@divinehq.divine.video', hqHex);

        expect(
          result.kind,
          Nip05ResolutionKind.networkError,
          reason: '$code must be no-signal, not matched',
        );
      }
    },
  );

  test(
    'defense-in-depth: even if a 3xx surfaces as a Response (widened '
    'validateStatus), a redirect body is not interpreted',
    () async {
      // Guards the belt-and-suspenders branch in _fetchRaw: unreachable with the
      // default 2xx validateStatus (the case above covers production), but if
      // validateStatus is ever widened to accept 3xx, a redirect body still
      // must not resolve to matched.
      when(() => dio.get(any())).thenAnswer(
        (_) async => jsonResponse({
          'names': {'_': hqHex},
        }, status: 302),
      );

      final result = await resolver.resolve('_@divinehq.divine.video', hqHex);

      expect(result.kind, Nip05ResolutionKind.networkError);
    },
  );

  test('absent: well-formed names map that lacks the name', () async {
    when(() => dio.get(any())).thenAnswer(
      (_) async => jsonResponse({
        'names': {'somebodyelse': otherHex},
      }),
    );

    final result = await resolver.resolve('_@divinehq.divine.video', hqHex);

    expect(result.kind, Nip05ResolutionKind.absent);
    expect(result.resolvedPubkey, isNull);
  });

  test('absent: 404 from the name server', () async {
    when(() => dio.get(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        response: Response(
          statusCode: 404,
          requestOptions: RequestOptions(),
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    final result = await resolver.resolve('_@divinehq.divine.video', hqHex);

    expect(result.kind, Nip05ResolutionKind.absent);
  });

  test('networkError: connection timeout keeps no signal', () async {
    when(() => dio.get(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionTimeout,
      ),
    );

    final result = await resolver.resolve('_@divinehq.divine.video', hqHex);

    expect(result.kind, Nip05ResolutionKind.networkError);
  });

  test('networkError: 5xx from the name server', () async {
    when(() => dio.get(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        response: Response(
          statusCode: 503,
          requestOptions: RequestOptions(),
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    final result = await resolver.resolve('_@divinehq.divine.video', hqHex);

    expect(result.kind, Nip05ResolutionKind.networkError);
  });

  test('networkError: malformed body (not a nostr.json shape)', () async {
    when(
      () => dio.get(any()),
    ).thenAnswer((_) async => jsonResponse('<html>nope</html>'));

    final result = await resolver.resolve('_@divinehq.divine.video', hqHex);

    expect(result.kind, Nip05ResolutionKind.networkError);
  });

  test('networkError: 2xx JSON object without a names map', () async {
    when(
      () => dio.get(any()),
    ).thenAnswer((_) async => jsonResponse({'relays': {}}));

    final result = await resolver.resolve('_@divinehq.divine.video', hqHex);

    expect(result.kind, Nip05ResolutionKind.networkError);
  });

  test(
    'case-normalized compare: checksummed nostr.json is not a differentKey',
    () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => jsonResponse({
          'names': {'_': hqHex.toUpperCase()},
        }),
      );

      final result = await resolver.resolve('_@divinehq.divine.video', hqHex);

      expect(result.kind, Nip05ResolutionKind.matched);
    },
  );

  test(
    'whitespace-normalized compare: padded server value still matches',
    () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => jsonResponse({
          'names': {'_': '  $hqHex\n'},
        }),
      );

      final result = await resolver.resolve('_@divinehq.divine.video', hqHex);

      expect(result.kind, Nip05ResolutionKind.matched);
    },
  );

  test(
    'concurrency: one in-flight fetch serves callers with different expected keys',
    () async {
      var calls = 0;
      final completer = Completer<Response<dynamic>>();
      when(() => dio.get(any())).thenAnswer((_) {
        calls++;
        return completer.future;
      });

      final fMatch = resolver.resolve('_@divinehq.divine.video', hqHex);
      final fDiff = resolver.resolve('_@divinehq.divine.video', otherHex);
      completer.complete(
        jsonResponse({
          'names': {'_': hqHex},
        }),
      );

      expect((await fMatch).kind, Nip05ResolutionKind.matched);
      expect((await fDiff).kind, Nip05ResolutionKind.differentKey);
      expect(calls, 1);
    },
  );

  test(
    'networkError: an oversized advertised body is rejected before parsing (parse-guard, not a memory bound)',
    () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          data: {
            'names': {'_': hqHex},
          },
          headers: Headers.fromMap({
            'content-length': ['5000000'],
          }),
          requestOptions: RequestOptions(),
        ),
      );

      final result = await resolver.resolve('_@divinehq.divine.video', hqHex);

      expect(result.kind, Nip05ResolutionKind.networkError);
    },
  );

  test(
    'concurrency: in-flight entry is cleared so a later call re-fetches',
    () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => jsonResponse({
          'names': {'_': hqHex},
        }),
      );

      await resolver.resolve('_@divinehq.divine.video', hqHex);
      await resolver.resolve('_@divinehq.divine.video', hqHex);

      verify(() => dio.get(any())).called(2);
    },
  );
}
