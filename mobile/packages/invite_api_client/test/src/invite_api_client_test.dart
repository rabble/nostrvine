import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _MockResponse extends Mock implements http.Response {}

const _testNsec =
    'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

void main() {
  late _MockHttpClient mockClient;
  late InviteApiClient client;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockClient = _MockHttpClient();
    client = InviteApiClient(
      baseUrl: 'https://invites.divine.video',
      client: mockClient,
    );
  });

  group('InviteApiClient', () {
    test('normalizes invite codes', () {
      expect(InviteApiClient.normalizeCode('ab12ef34'), 'AB12-EF34');
      expect(InviteApiClient.normalizeCode('ab12-ef34'), 'AB12-EF34');
      expect(InviteApiClient.normalizeCode('ab-cd-12-34'), 'ABCD-1234');
      expect(InviteApiClient.normalizeCode('abc'), 'ABC');
      expect(InviteApiClient.normalizeCode('ABCDEFGHIJ'), 'ABCD-EFGH');
    });

    test('recognizes full invite code format', () {
      expect(InviteApiClient.looksLikeInviteCode('AB12-EF34'), isTrue);
      expect(InviteApiClient.looksLikeInviteCode('abcd1234'), isTrue);
      expect(InviteApiClient.looksLikeInviteCode('LELE-PONS'), isTrue);
      expect(InviteApiClient.looksLikeInviteCode('AB12'), isFalse);
      expect(InviteApiClient.looksLikeInviteCode(''), isFalse);
    });

    test('loads client config', () async {
      final response = _MockResponse();
      when(() => response.statusCode).thenReturn(200);
      when(() => response.body).thenReturn(
        jsonEncode({
          'onboarding_mode': 'invite_code_required',
          'support_email': 'support@divine.video',
        }),
      );
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => response);

      final config = await client.getClientConfig();

      expect(config.mode, OnboardingMode.inviteCodeRequired);
      expect(config.supportEmail, 'support@divine.video');
    });

    test('forces onboarding mode open when configured', () async {
      final response = _MockResponse();
      when(() => response.statusCode).thenReturn(200);
      when(() => response.body).thenReturn(
        jsonEncode({
          'onboarding_mode': 'invite_code_required',
          'support_email': 'support@divine.video',
        }),
      );
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => response);

      final previewClient = InviteApiClient(
        baseUrl: 'https://invites.divine.video',
        client: mockClient,
        forceOpenOnboarding: true,
      );

      final config = await previewClient.getClientConfig();

      expect(config.mode, OnboardingMode.open);
    });

    test('validates invite codes', () async {
      final response = _MockResponse();
      when(() => response.statusCode).thenReturn(200);
      when(() => response.body).thenReturn(
        jsonEncode({'valid': true, 'used': false, 'code': 'AB12-EF34'}),
      );
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => response);

      final result = await client.validateCode('ab12ef34');

      expect(result.canContinue, isTrue);
      expect(result.code, 'AB12-EF34');
    });

    test(
      'validates reusable creator invite codes with creator metadata',
      () async {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(200);
        when(() => response.body).thenReturn(
          jsonEncode({
            'valid': true,
            'available': true,
            'used': true,
            'code': 'LELE-PONS',
            'creatorSlug': 'lele-pons',
            'creatorDisplayName': 'Lele Pons',
            'remaining': 842,
          }),
        );
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => response);

        final result = await client.validateCode('lele-pons');

        expect(result.canContinue, isTrue);
        expect(result.code, 'LELE-PONS');
        expect(result.creatorSlug, 'lele-pons');
        expect(result.creatorDisplayName, 'Lele Pons');
        expect(result.remaining, 842);
      },
    );

    test('maps validation rejection responses to an invalid result', () async {
      final rejectionStatuses = [400, 403, 404, 409];

      for (final status in rejectionStatuses) {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(status);
        when(() => response.body).thenReturn(
          jsonEncode({
            'valid': false,
            'used': status == 409,
            'code': 'AB12-EF34',
          }),
        );
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => response);

        final result = await client.validateCode('ab12ef34');

        expect(result.valid, isFalse);
        expect(result.used, status == 409);
        expect(result.code, 'AB12-EF34');
      }
    });

    test(
      'surfaces validateCode timeout failures as InviteApiException',
      () async {
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) => Future<http.Response>.error(TimeoutException('timed out')),
        );

        await expectLater(
          client.validateCode('ab12ef34'),
          throwsA(
            isA<InviteApiException>()
                .having(
                  (error) => error.message,
                  'message',
                  'Invite code validation timed out',
                )
                .having(
                  (error) => error.code,
                  'code',
                  InviteApiErrorCode.clientTimeout,
                ),
          ),
        );
      },
    );

    test(
      'surfaces validateCode transport failures as InviteApiException',
      () async {
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(const SocketException('Connection failed'));

        await expectLater(
          client.validateCode('ab12ef34'),
          throwsA(
            isA<InviteApiException>()
                .having(
                  (error) => error.message,
                  'message',
                  contains('Failed to validate invite code'),
                )
                .having(
                  (error) => error.code,
                  'code',
                  InviteApiErrorCode.clientNetworkError,
                ),
          ),
        );
      },
    );

    test('joins waitlist and passes pubkey when provided', () async {
      final waitlistClient = InviteApiClient(
        baseUrl: 'https://invites.divine.video',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, contains('/v1/waitlist'));
          expect(jsonDecode(request.body), {
            'contact': 'test@example.com',
            'pubkey': 'pubkey-123',
          });
          return http.Response(
            jsonEncode({
              'id': 'waitlist-entry-1',
              'message': 'You are on the waitlist',
            }),
            201,
          );
        }),
      );

      final result = await waitlistClient.joinWaitlist(
        contact: 'test@example.com',
        pubkey: 'pubkey-123',
      );

      expect(result.id, 'waitlist-entry-1');
      expect(result.message, 'You are on the waitlist');
    });

    test('joins waitlist with creator source slug when provided', () async {
      final waitlistClient = InviteApiClient(
        baseUrl: 'https://invites.divine.video',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, contains('/v1/waitlist'));
          expect(jsonDecode(request.body), {
            'contact': 'test@example.com',
            'source_slug': 'lele-pons',
          });
          return http.Response(
            jsonEncode({
              'id': 'waitlist-entry-1',
              'message': 'You are on the waitlist',
            }),
            201,
          );
        }),
      );

      final result = await waitlistClient.joinWaitlist(
        contact: 'test@example.com',
        sourceSlug: 'lele-pons',
      );

      expect(result.id, 'waitlist-entry-1');
    });

    test('returns invite status on 200', () async {
      final statusClient = InviteApiClient(
        baseUrl: 'https://invites.divine.video',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, contains('/v1/invite-status'));
          return http.Response(
            jsonEncode({
              'canInvite': true,
              'remaining': 3,
              'total': 5,
              'codes': [
                {'code': 'AB23-EF7K', 'claimed': false},
              ],
            }),
            200,
          );
        }),
        authHeaderProvider: ({required url, required method, payload}) async =>
            null,
      );

      final result = await statusClient.getInviteStatus();
      expect(result.canInvite, isTrue);
      expect(result.remaining, 3);
      expect(result.codes, hasLength(1));
    });

    test('returns generate invite result on 201', () async {
      final generateClient = InviteApiClient(
        baseUrl: 'https://invites.divine.video',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, contains('/v1/generate-invite'));
          return http.Response(
            jsonEncode({'code': 'WX56-3MKT', 'remaining': 4}),
            201,
          );
        }),
        authHeaderProvider: ({required url, required method, payload}) async =>
            null,
      );

      final result = await generateClient.generateInvite();
      expect(result.code, 'WX56-3MKT');
      expect(result.remaining, 4);
    });

    test('consumes invite with a pre-generated key container', () async {
      final response = _MockResponse();
      when(() => response.statusCode).thenReturn(200);
      when(() => response.body).thenReturn(
        jsonEncode({'message': 'Welcome to diVine!', 'codesAllocated': 5}),
      );
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => response);

      final keyContainer = SecureKeyContainer.fromNsec(_testNsec);
      final result = await client.consumeInviteWithKeyContainer(
        code: 'ab12ef34',
        keyContainer: keyContainer,
      );

      expect(result.codesAllocated, 5);
      verify(
        () => mockClient.post(
          any(),
          headers: any(
            named: 'headers',
            that: containsPair('Authorization', startsWith('Nostr ')),
          ),
          body: jsonEncode({'code': 'AB12-EF34'}),
        ),
      ).called(1);

      keyContainer.dispose();
    });

    test(
      'parses already consumed invite responses as successful consumption',
      () async {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(200);
        when(() => response.body).thenReturn(
          jsonEncode({
            'result': 'already_consumed',
            'code': 'LELE-PONS',
            'codesAllocated': 0,
            'creatorSlug': 'lele-pons',
            'creatorDisplayName': 'Lele Pons',
          }),
        );
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => response);

        final result = await client.consumeInvite('lele-pons');

        expect(result.isSuccess, isTrue);
        expect(result.result, InviteConsumeStatus.alreadyConsumed);
        expect(result.code, 'LELE-PONS');
        expect(result.creatorSlug, 'lele-pons');
        expect(result.creatorDisplayName, 'Lele Pons');
      },
    );

    test('surfaces creator page full as structured invite API error', () async {
      final response = _MockResponse();
      when(() => response.statusCode).thenReturn(409);
      when(() => response.body).thenReturn(
        jsonEncode({
          'code': 'creator_page_full',
          'error': "This creator's invites are full",
          'creatorSlug': 'lele-pons',
          'creatorDisplayName': 'Lele Pons',
        }),
      );
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => response);

      await expectLater(
        client.consumeInvite('lele-pons'),
        throwsA(
          isA<InviteApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.code, 'code', InviteApiErrorCode.creatorPageFull)
              .having((e) => e.creatorSlug, 'creatorSlug', 'lele-pons'),
        ),
      );
    });

    test('treats user already joined consume errors as success', () async {
      final response = _MockResponse();
      when(() => response.statusCode).thenReturn(409);
      when(() => response.body).thenReturn(
        jsonEncode({
          'code': 'user_already_joined',
          'error': 'User has already joined',
        }),
      );
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => response);

      final result = await client.consumeInvite('lele-pons');

      expect(result.isSuccess, isTrue);
      expect(result.result, InviteConsumeStatus.userAlreadyJoined);
      expect(result.code, 'LELE-PONS');
    });

    test(
      'surfaces consumeInvite timeout failures with a structured code',
      () async {
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) => Future<http.Response>.error(TimeoutException('timed out')),
        );

        await expectLater(
          client.consumeInvite('ab12ef34'),
          throwsA(
            isA<InviteApiException>()
                .having(
                  (error) => error.message,
                  'message',
                  'Invite activation timed out',
                )
                .having(
                  (error) => error.code,
                  'code',
                  InviteApiErrorCode.clientTimeout,
                ),
          ),
        );
      },
    );

    test(
      'surfaces consumeInvite network failures with a structured code',
      () async {
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(const SocketException('Connection failed'));

        await expectLater(
          client.consumeInvite('ab12ef34'),
          throwsA(
            isA<InviteApiException>()
                .having(
                  (error) => error.message,
                  'message',
                  contains('Failed to activate invite code'),
                )
                .having(
                  (error) => error.code,
                  'code',
                  InviteApiErrorCode.clientNetworkError,
                ),
          ),
        );
      },
    );

    test(
      'surfaces invite signing failures with a structured auth code',
      () async {
        final keyContainer = SecureKeyContainer.fromNsec(_testNsec);
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(StateError('should not hit network'));

        keyContainer.dispose();

        await expectLater(
          client.consumeInviteWithKeyContainer(
            code: 'ab12ef34',
            keyContainer: keyContainer,
          ),
          throwsA(
            isA<InviteApiException>()
                .having(
                  (error) => error.message,
                  'message',
                  contains('Failed to authenticate invite request'),
                )
                .having(
                  (error) => error.code,
                  'code',
                  InviteApiErrorCode.clientAuthFailed,
                ),
          ),
        );
      },
    );

    test('surfaces server errors as InviteApiException', () async {
      final response = _MockResponse();
      when(() => response.statusCode).thenReturn(503);
      when(
        () => response.body,
      ).thenReturn(jsonEncode({'error': 'Invite service unavailable'}));
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => response);

      await expectLater(
        client.getClientConfig(),
        throwsA(
          isA<InviteApiException>().having(
            (error) => error.message,
            'message',
            'Invite service unavailable',
          ),
        ),
      );
    });

    group('joinWaitlist', () {
      test('returns result on 201', () async {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(201);
        when(() => response.body).thenReturn(
          jsonEncode({'id': 'wl-123', 'message': 'Added to waitlist'}),
        );
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => response);

        final result = await client.joinWaitlist(contact: 'user@test.com');

        expect(result.id, 'wl-123');
        expect(result.message, 'Added to waitlist');
      });

      test('returns result on 200', () async {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(200);
        when(() => response.body).thenReturn(
          jsonEncode({'id': 'wl-456', 'message': 'Already on waitlist'}),
        );
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => response);

        final result = await client.joinWaitlist(contact: 'user@test.com');

        expect(result.id, 'wl-456');
      });

      test('includes pubkey when provided', () async {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(201);
        when(
          () => response.body,
        ).thenReturn(jsonEncode({'id': 'wl-789', 'message': 'Added'}));
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => response);

        await client.joinWaitlist(contact: 'user@test.com', pubkey: 'abc123');

        final captured =
            verify(
                  () => mockClient.post(
                    any(),
                    headers: any(named: 'headers'),
                    body: captureAny(named: 'body'),
                  ),
                ).captured.last
                as String;
        final body = jsonDecode(captured) as Map<String, dynamic>;
        expect(body['contact'], 'user@test.com');
        expect(body['pubkey'], 'abc123');
      });

      test('throws on server error', () async {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(500);
        when(
          () => response.body,
        ).thenReturn(jsonEncode({'error': 'Internal error'}));
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => response);

        await expectLater(
          client.joinWaitlist(contact: 'user@test.com'),
          throwsA(isA<InviteApiException>()),
        );
      });

      test('throws on timeout', () async {
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => throw TimeoutException('timed out'));

        await expectLater(
          client.joinWaitlist(contact: 'user@test.com'),
          throwsA(
            isA<InviteApiException>().having(
              (e) => e.message,
              'message',
              'Waitlist request timed out',
            ),
          ),
        );
      });
    });

    group('validateCode', () {
      test('maps 400 rejection to invalid result', () async {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(400);
        when(() => response.body).thenReturn(
          jsonEncode({'valid': false, 'used': false, 'code': 'AB12-EF34'}),
        );
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => response);

        final result = await client.validateCode('ab12ef34');

        expect(result.valid, isFalse);
        expect(result.canContinue, isFalse);
      });

      test('maps 403 rejection to invalid result', () async {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(403);
        when(
          () => response.body,
        ).thenReturn(jsonEncode({'valid': false, 'used': false}));
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => response);

        final result = await client.validateCode('ab12ef34');

        expect(result.valid, isFalse);
      });

      test('maps 404 rejection to invalid result', () async {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(404);
        when(
          () => response.body,
        ).thenReturn(jsonEncode({'valid': false, 'used': false}));
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => response);

        final result = await client.validateCode('ab12ef34');

        expect(result.valid, isFalse);
      });

      test('maps 409 used code to used result', () async {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(409);
        when(() => response.body).thenReturn(
          jsonEncode({'valid': true, 'used': true, 'code': 'AB12-EF34'}),
        );
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => response);

        final result = await client.validateCode('ab12ef34');

        expect(result.valid, isTrue);
        expect(result.used, isTrue);
        expect(result.canContinue, isFalse);
      });

      test('handles malformed rejection body gracefully', () async {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(400);
        when(() => response.body).thenReturn('not json');
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => response);

        final result = await client.validateCode('ab12ef34');

        expect(result.valid, isFalse);
        expect(result.code, 'AB12-EF34');
      });

      test('throws on non-rejection server error', () async {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(500);
        when(
          () => response.body,
        ).thenReturn(jsonEncode({'error': 'Internal server error'}));
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => response);

        await expectLater(
          client.validateCode('ab12ef34'),
          throwsA(
            isA<InviteApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              500,
            ),
          ),
        );
      });

      test('throws on timeout', () async {
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => throw TimeoutException('timed out'));

        await expectLater(
          client.validateCode('ab12ef34'),
          throwsA(
            isA<InviteApiException>().having(
              (e) => e.message,
              'message',
              'Invite code validation timed out',
            ),
          ),
        );
      });

      test('wraps unexpected errors as InviteApiException', () async {
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(Exception('network failure'));

        await expectLater(
          client.validateCode('ab12ef34'),
          throwsA(isA<InviteApiException>()),
        );
      });
    });

    group('getClientConfig', () {
      test('throws on timeout', () async {
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => throw TimeoutException('timed out'));

        await expectLater(
          client.getClientConfig(),
          throwsA(
            isA<InviteApiException>().having(
              (e) => e.message,
              'message',
              'Invite configuration request timed out',
            ),
          ),
        );
      });

      test('wraps unexpected errors as InviteApiException', () async {
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('connection refused'));

        await expectLater(
          client.getClientConfig(),
          throwsA(isA<InviteApiException>()),
        );
      });
    });
  });
}
