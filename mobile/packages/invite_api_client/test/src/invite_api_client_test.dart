import 'dart:convert';

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
        authHeaderProvider:
            ({
              required String url,
              required InviteRequestMethod method,
              String? payload,
            }) async => null,
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
        authHeaderProvider:
            ({
              required String url,
              required InviteRequestMethod method,
              String? payload,
            }) async => null,
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
  });
}
