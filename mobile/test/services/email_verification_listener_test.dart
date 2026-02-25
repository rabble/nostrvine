// ABOUTME: Tests for EmailVerificationListener
// ABOUTME: Verifies that deep links navigate to the verification screen

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/email_verification_listener.dart';

import '../helpers/go_router.dart';

void main() {
  group(EmailVerificationListener, () {
    late MockGoRouter mockRouter;
    late ProviderContainer container;
    late EmailVerificationListener listener;

    setUp(() {
      mockRouter = MockGoRouter();

      container = ProviderContainer(
        overrides: [goRouterProvider.overrideWith((ref) => mockRouter)],
      );

      listener = container.read(emailVerificationListenerProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'navigates to verification screen when URI contains a token',
      () async {
        const token = 'test-verification-token-abc123';
        when(() => mockRouter.go(any())).thenReturn(null);

        await listener.handleUri(
          Uri.parse('https://login.divine.video/verify-email?token=$token'),
        );

        verify(() => mockRouter.go('/verify-email?token=$token')).called(1);
      },
    );

    test('ignores URIs with wrong host', () async {
      await listener.handleUri(
        Uri.parse('https://evil.com/verify-email?token=stolen-token'),
      );

      verifyNever(() => mockRouter.go(any()));
    });

    test('ignores URIs with wrong path', () async {
      await listener.handleUri(
        Uri.parse('https://login.divine.video/other-path?token=some-token'),
      );

      verifyNever(() => mockRouter.go(any()));
    });

    test('ignores URIs without token parameter', () async {
      await listener.handleUri(
        Uri.parse('https://login.divine.video/verify-email'),
      );

      verifyNever(() => mockRouter.go(any()));
    });
  });
}
