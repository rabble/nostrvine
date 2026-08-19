// ABOUTME: Tests the durable account-deletion coordinator HTTP contract.
// ABOUTME: Pins exact NIP-98 URLs, payload bytes, states, and 404 semantics.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  late _MockNip98AuthService nip98;

  setUpAll(() {
    registerFallbackValue(HttpMethod.get);
  });

  setUp(() {
    nip98 = _MockNip98AuthService();
    when(
      () => nip98.createAuthToken(
        url: any(named: 'url'),
        method: any(named: 'method'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async => _token());
  });

  AccountDeletionRecoveryRepository repository(http.Client client) =>
      AccountDeletionRecoveryRepository(
        baseUrl: 'https://api.divine.video/',
        httpClient: client,
        nip98AuthService: nip98,
        currentPubkey: () =>
            '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
      );

  test('prepare signs and posts the exact coordinator URL and body', () async {
    http.Request? captured;
    final result = await repository(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'id': 'attempt-1',
            'status': 'recoverable',
            'username': 'alice',
          }),
          201,
        );
      }),
    ).prepare(username: 'alice');

    expect(result.status, AccountDeletionAttemptStatus.recoverable);
    expect(
      captured?.url.toString(),
      'https://api.divine.video/api/account-deletion/attempts',
    );
    expect(captured?.body, jsonEncode({'username': 'alice'}));
    verify(
      () => nip98.createAuthToken(
        url: 'https://api.divine.video/api/account-deletion/attempts',
        method: HttpMethod.post,
        payload: jsonEncode({'username': 'alice'}),
      ),
    ).called(1);
  });

  test('current returns null only for a definitive 404', () async {
    final result = await repository(
      MockClient((_) async => http.Response('{}', 404)),
    ).fetchCurrent();

    expect(result, isNull);
  });

  test('submit encodes IDs and surfaces processing state', () async {
    http.Request? captured;
    final result = await repository(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'id': 'attempt/1', 'status': 'processing'}),
          202,
        );
      }),
    ).submit(attemptId: 'attempt/1', vanishEventId: 'event-id');

    expect(result.status, AccountDeletionAttemptStatus.processing);
    expect(
      captured?.url.toString(),
      'https://api.divine.video/api/account-deletion/attempts/'
      'attempt%2F1/submit',
    );
    expect(captured?.body, jsonEncode({'vanish_event_id': 'event-id'}));
  });

  test('cancel requires the distinct cancelled terminal state', () async {
    final result = await repository(
      MockClient(
        (_) async => http.Response(
          jsonEncode({'id': 'attempt-1', 'status': 'cancelled'}),
          200,
        ),
      ),
    ).cancel(attemptId: 'attempt-1');

    expect(result.status, AccountDeletionAttemptStatus.cancelled);
    expect(result.requiresRecoveryScreen, isFalse);
  });

  test('unknown server state fails closed instead of guessing', () async {
    expect(
      () => repository(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'id': 'attempt-1', 'status': 'mystery'}),
            200,
          ),
        ),
      ).fetchCurrent(),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a cached NIP-98 token from a different account', () async {
    when(
      () => nip98.createAuthToken(
        url: any(named: 'url'),
        method: any(named: 'method'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async => _token(pubkey: _otherPubkey));

    expect(
      () => repository(
        MockClient((_) async => http.Response('{}', 404)),
      ).fetchCurrent(),
      throwsA(isA<AccountDeletionRecoveryException>()),
    );
  });
}

const _otherPubkey =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

Nip98Token _token({
  String pubkey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
}) {
  final now = clock.now();
  return Nip98Token(
    token: 'token',
    signedEvent: Event(
      pubkey,
      27235,
      const [],
      '',
    ),
    createdAt: now,
    expiresAt: now.add(const Duration(seconds: 45)),
  );
}
