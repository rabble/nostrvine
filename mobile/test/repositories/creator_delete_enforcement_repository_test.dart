// ABOUTME: Tests creator-delete sync, polling, and honest fallback mapping.
// ABOUTME: Covers every response class in the mobile/backend contract.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/repositories/creator_delete_enforcement_repository.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

class _MockNip98Token extends Mock implements Nip98Token {}

void main() {
  setUpAll(() => registerFallbackValue(HttpMethod.get));

  group(CreatorDeleteEnforcementRepository, () {
    late _MockNip98AuthService auth;
    late _MockNip98Token token;
    late List<Object> reports;

    setUp(() {
      auth = _MockNip98AuthService();
      token = _MockNip98Token();
      reports = [];
      when(() => token.authorizationHeader).thenReturn('Nostr signed');
      when(
        () => auth.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => token);
    });

    CreatorDeleteEnforcementRepository build(
      FutureOr<http.Response> Function(http.Request) handler,
    ) => CreatorDeleteEnforcementRepository(
      baseUrl: 'https://moderation.example',
      httpClient: MockClient((request) async => handler(request)),
      nip98AuthService: auth,
      pollTimeout: const Duration(seconds: 1),
      delay: (_) async {},
      reportError: (error, _) => reports.add(error),
    );

    test('maps synchronous success to confirmed', () async {
      final result = await build(
        (_) => http.Response('{"status":"success"}', 200),
      ).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.confirmed);
    });

    test('disabled enforcement does not contact the production API', () async {
      var calls = 0;
      final repository = CreatorDeleteEnforcementRepository(
        baseUrl: 'https://moderation.example',
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
        nip98AuthService: auth,
        enabled: false,
      );

      final result = await repository.enforce('local-kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.delayed);
      expect(calls, 0);
    });

    test('maps synchronous terminal failure to permanent failure', () async {
      final result = await build(
        (_) => http.Response('{"status":"failed"}', 200),
      ).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.failed);
    });

    test('polls after 202 and confirms all targets', () async {
      var calls = 0;
      final result = await build((request) {
        calls++;
        return calls == 1
            ? http.Response('{"status":"in_progress"}', 202)
            : http.Response(
                '{"targets":[{"status":"success"}]}',
                200,
              );
      }).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.confirmed);
      expect(calls, 2);
    });

    test('returns delayed immediately after POST 404', () async {
      var calls = 0;
      final result = await build((request) {
        calls++;
        return calls == 1
            ? http.Response('', 404)
            : http.Response(
                '{"targets":[{"status":"success"}]}',
                200,
              );
      }).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.delayed);
      expect(calls, 1);
    });

    test('returns delayed immediately after 5xx', () async {
      final result = await build(
        (_) => http.Response('', 503),
      ).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.delayed);
    });

    test('returns delayed immediately after network failure', () async {
      final result = await build(
        (_) => throw http.ClientException('offline'),
      ).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.delayed);
    });

    test('returns delayed immediately after 429', () async {
      var calls = 0;
      final result = await build((_) {
        calls++;
        return calls < 3
            ? http.Response('', 429)
            : http.Response(
                '{"targets":[{"status":"success"}]}',
                200,
              );
      }).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.delayed);
      expect(calls, 1);
    });

    for (final statusCode in [400, 403]) {
      test('$statusCode is a reportable client-contract failure', () async {
        final result = await build(
          (_) => http.Response('', statusCode),
        ).enforce('kind5');

        expect(result.status, CreatorDeleteEnforcementStatus.failed);
        expect(reports, hasLength(1));
      });
    }

    test(
      '401 is delayed without reporting a client contract failure',
      () async {
        final result = await build(
          (_) => http.Response('', 401),
        ).enforce('kind5');

        expect(result.status, CreatorDeleteEnforcementStatus.delayed);
        expect(reports, isEmpty);
      },
    );

    test('maps a permanent target status from polling to failure', () async {
      var calls = 0;
      final result = await build((_) {
        calls++;
        return calls == 1
            ? http.Response('', 202)
            : http.Response(
                '{"targets":[{"status":"failed:permanent:blossom_400"}]}',
                200,
              );
      }).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.failed);
    });

    test('keeps accepted and transient target rows pending', () async {
      var calls = 0;
      final result = await build((_) {
        calls++;
        return calls == 1
            ? http.Response('', 202)
            : http.Response(
                '{"targets":[{"status":"failed:transient:network"}]}',
                200,
              );
      }).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.delayed);
    });

    test('treats malformed terminal JSON as reportable', () async {
      final result = await build(
        (_) => http.Response('{"unexpected":true}', 200),
      ).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.failed);
      expect(reports, hasLength(1));
    });

    test(
      'reports an unexpected client error and keeps cleanup delayed',
      () async {
        when(
          () => auth.createAuthToken(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenThrow(StateError('signer failed'));

        final result = await build(
          (_) => http.Response('{"status":"success"}', 200),
        ).enforce('kind5');

        expect(result.status, CreatorDeleteEnforcementStatus.delayed);
        expect(reports, hasLength(1));
      },
    );
  });
}
