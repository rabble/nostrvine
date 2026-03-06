import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/invite_api_service.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _MockResponse extends Mock implements http.Response {}

const _testNsec =
    'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

void main() {
  late _MockHttpClient mockClient;
  late InviteApiService inviteApiService;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockClient = _MockHttpClient();
    inviteApiService = InviteApiService(client: mockClient);
  });

  group('InviteApiService', () {
    test('normalizes invite codes', () {
      expect(InviteApiService.normalizeCode('ab12ef34'), 'AB12-EF34');
      expect(InviteApiService.normalizeCode('ab12-ef34'), 'AB12-EF34');
      expect(InviteApiService.normalizeCode('ab-cd-12-34'), 'ABCD-1234');
      expect(InviteApiService.normalizeCode('abc'), 'ABC');
      expect(InviteApiService.normalizeCode('ABCDEFGHIJ'), 'ABCD-EFGH');
    });

    test('recognizes full invite code format', () {
      expect(InviteApiService.looksLikeInviteCode('AB12-EF34'), isTrue);
      expect(InviteApiService.looksLikeInviteCode('abcd1234'), isTrue);
      expect(InviteApiService.looksLikeInviteCode('AB12'), isFalse);
      expect(InviteApiService.looksLikeInviteCode(''), isFalse);
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

      final config = await inviteApiService.getClientConfig();

      expect(config.mode, OnboardingMode.inviteCodeRequired);
      expect(config.supportEmail, 'support@divine.video');
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

      final result = await inviteApiService.validateCode('ab12ef34');

      expect(result.canContinue, isTrue);
      expect(result.code, 'AB12-EF34');
      verify(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: jsonEncode({'code': 'AB12-EF34'}),
        ),
      ).called(1);
    });

    test('maps used invite responses to an invalid result', () async {
      final response = _MockResponse();
      when(() => response.statusCode).thenReturn(404);
      when(() => response.body).thenReturn(
        jsonEncode({'message': 'Code used', 'used': true}),
      );
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => response);

      final result = await inviteApiService.validateCode('used0003');

      expect(result.canContinue, isFalse);
      expect(result.used, isTrue);
      expect(result.code, 'USED-0003');
    });

    test(
      'maps malformed validation rejections to a generic invalid result',
      () async {
        final response = _MockResponse();
        when(() => response.statusCode).thenReturn(404);
        when(() => response.body).thenReturn('Not found');
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => response);

        final result = await inviteApiService.validateCode('badcode1');

        expect(result.canContinue, isFalse);
        expect(result.used, isFalse);
        expect(result.code, 'BADC-ODE1');
      },
    );

    test('joins waitlist', () async {
      final response = _MockResponse();
      when(() => response.statusCode).thenReturn(201);
      when(() => response.body).thenReturn(
        jsonEncode({'id': 'waitlist-1', 'message': 'queued'}),
      );
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => response);

      final result = await inviteApiService.joinWaitlist(
        contact: 'user@example.com',
      );

      expect(result.id, 'waitlist-1');
      expect(result.message, 'queued');
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
      final result = await inviteApiService.consumeInviteWithKeyContainer(
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

    test('surfaces server errors', () async {
      final response = _MockResponse();
      when(() => response.statusCode).thenReturn(503);
      when(() => response.body).thenReturn(
        jsonEncode({'error': 'Invite service unavailable'}),
      );
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => response);

      await expectLater(
        inviteApiService.getClientConfig(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Invite service unavailable',
          ),
        ),
      );
    });

    test('throws on validation transport failures', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenThrow(Exception('Connection refused'));

      await expectLater(
        inviteApiService.validateCode('TEST-0001'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('Failed to validate invite code'),
          ),
        ),
      );
    });
  });
}
