import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/invite_api_service.dart';
import 'package:openvine/services/nip98_auth_service.dart'
    show HttpMethod, Nip98AuthService;

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  late _MockNip98AuthService mockAuthService;

  setUpAll(() {
    registerFallbackValue(HttpMethod.get);
  });

  setUp(() {
    mockAuthService = _MockNip98AuthService();
    when(() => mockAuthService.canCreateTokens).thenReturn(true);
    when(
      () => mockAuthService.createAuthToken(
        url: any(named: 'url'),
        method: any(named: 'method'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async => null);
  });

  group('getInviteStatus', () {
    test('returns InviteStatus on 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('GET'));
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
      });

      final service = InviteApiService(
        client: mockClient,
        authService: mockAuthService,
      );

      final result = await service.getInviteStatus();
      expect(result.canInvite, isTrue);
      expect(result.remaining, equals(3));
      expect(result.codes, hasLength(1));
    });

    test('throws ApiException on non-200', () async {
      final mockClient = MockClient(
        (request) async => http.Response('{"error": "Unauthorized"}', 401),
      );

      final service = InviteApiService(
        client: mockClient,
        authService: mockAuthService,
      );

      expect(
        service.getInviteStatus,
        throwsA(isA<ApiException>()),
      );
    });

    test('throws ApiException on timeout', () async {
      final mockClient = MockClient(
        (request) async => Future<http.Response>.delayed(
          const Duration(seconds: 30),
        ).then((_) => http.Response('', 200)),
      );

      final service = InviteApiService(
        client: mockClient,
        authService: mockAuthService,
      );

      expect(
        service.getInviteStatus,
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('generateInvite', () {
    test('returns GenerateInviteResult on 201', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, contains('/v1/generate-invite'));
        return http.Response(
          jsonEncode({'code': 'WX56-3MKT', 'remaining': 4}),
          201,
        );
      });

      final service = InviteApiService(
        client: mockClient,
        authService: mockAuthService,
      );

      final result = await service.generateInvite();
      expect(result.code, equals('WX56-3MKT'));
      expect(result.remaining, equals(4));
    });

    test('returns GenerateInviteResult on 200', () async {
      final mockClient = MockClient(
        (request) async => http.Response(
          jsonEncode({'code': 'WX56-3MKT', 'remaining': 4}),
          200,
        ),
      );

      final service = InviteApiService(
        client: mockClient,
        authService: mockAuthService,
      );

      final result = await service.generateInvite();
      expect(result.code, equals('WX56-3MKT'));
    });

    test('throws ApiException on 403', () async {
      final mockClient = MockClient(
        (request) async => http.Response(
          '{"error": "Not eligible to generate invites"}',
          403,
        ),
      );

      final service = InviteApiService(
        client: mockClient,
        authService: mockAuthService,
      );

      expect(
        service.generateInvite,
        throwsA(isA<ApiException>()),
      );
    });

    test('throws ApiException on 429', () async {
      final mockClient = MockClient(
        (request) async => http.Response(
          '{"error": "Invite limit reached", "remaining": 0}',
          429,
        ),
      );

      final service = InviteApiService(
        client: mockClient,
        authService: mockAuthService,
      );

      expect(
        service.generateInvite,
        throwsA(isA<ApiException>()),
      );
    });
  });
}
