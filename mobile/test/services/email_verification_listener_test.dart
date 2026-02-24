// ABOUTME: Tests for EmailVerificationListener
// ABOUTME: Verifies that deep links trigger verifyEmail() API call

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/email_verification_listener.dart';

import '../helpers/go_router.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

void main() {
  group(EmailVerificationListener, () {
    late _MockKeycastOAuth mockOAuth;
    late MockGoRouter mockRouter;
    late ProviderContainer container;
    late EmailVerificationListener listener;

    setUp(() {
      mockOAuth = _MockKeycastOAuth();
      mockRouter = MockGoRouter();

      container = ProviderContainer(
        overrides: [
          oauthClientProvider.overrideWithValue(mockOAuth),
          goRouterProvider.overrideWith((ref) => mockRouter),
        ],
      );

      // Read the listener via its provider so it receives a proper Ref
      listener = container.read(emailVerificationListenerProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test('calls verifyEmail when URI contains a token', () async {
      const token = 'test-verification-token-abc123';
      when(
        () => mockOAuth.verifyEmail(token: token),
      ).thenAnswer((_) async => VerifyEmailResult(success: true));
      when(() => mockRouter.go(any())).thenReturn(null);

      await listener.handleUri(
        Uri.parse('https://login.divine.video/verify-email?token=$token'),
      );

      // Allow the fire-and-forget future to complete
      await Future<void>.delayed(Duration.zero);

      verify(() => mockOAuth.verifyEmail(token: token)).called(1);
    });

    test('attempts navigation after calling verifyEmail', () async {
      const token = 'test-token-xyz';
      when(
        () => mockOAuth.verifyEmail(token: token),
      ).thenAnswer((_) async => VerifyEmailResult(success: true));
      when(() => mockRouter.go(any())).thenReturn(null);

      await listener.handleUri(
        Uri.parse('https://login.divine.video/verify-email?token=$token'),
      );

      await Future<void>.delayed(Duration.zero);

      verify(() => mockRouter.go('/verify-email?token=$token')).called(1);
    });

    test('calls verifyEmail even when server returns error', () async {
      const token = 'expired-token';
      when(() => mockOAuth.verifyEmail(token: token)).thenAnswer(
        (_) async => VerifyEmailResult(success: false, error: 'Token expired'),
      );
      when(() => mockRouter.go(any())).thenReturn(null);

      await listener.handleUri(
        Uri.parse('https://login.divine.video/verify-email?token=$token'),
      );

      await Future<void>.delayed(Duration.zero);

      verify(() => mockOAuth.verifyEmail(token: token)).called(1);
    });

    test('handles verifyEmail network exception gracefully', () async {
      const token = 'network-error-token';
      when(
        () => mockOAuth.verifyEmail(token: token),
      ).thenAnswer((_) async => throw Exception('Network error'));
      when(() => mockRouter.go(any())).thenReturn(null);

      // Should not throw
      await listener.handleUri(
        Uri.parse('https://login.divine.video/verify-email?token=$token'),
      );

      await Future<void>.delayed(Duration.zero);

      verify(() => mockOAuth.verifyEmail(token: token)).called(1);
      verify(() => mockRouter.go(any())).called(1);
    });

    test('ignores URIs with wrong host', () async {
      await listener.handleUri(
        Uri.parse('https://evil.com/verify-email?token=stolen-token'),
      );

      verifyNever(() => mockOAuth.verifyEmail(token: any(named: 'token')));
      verifyNever(() => mockRouter.go(any()));
    });

    test('ignores URIs with wrong path', () async {
      await listener.handleUri(
        Uri.parse('https://login.divine.video/other-path?token=some-token'),
      );

      verifyNever(() => mockOAuth.verifyEmail(token: any(named: 'token')));
      verifyNever(() => mockRouter.go(any()));
    });

    test('ignores URIs without token parameter', () async {
      await listener.handleUri(
        Uri.parse('https://login.divine.video/verify-email'),
      );

      verifyNever(() => mockOAuth.verifyEmail(token: any(named: 'token')));
      verifyNever(() => mockRouter.go(any()));
    });
  });
}
