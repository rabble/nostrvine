// ABOUTME: Tests for PasswordResetListener
// ABOUTME: Verifies that deep links navigate to the reset password screen

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/password_reset_listener.dart';

import '../helpers/go_router.dart';

void main() {
  group(PasswordResetListener, () {
    late MockGoRouter mockRouter;
    late ProviderContainer container;
    late PasswordResetListener listener;

    setUp(() {
      mockRouter = MockGoRouter();

      container = ProviderContainer(
        overrides: [goRouterProvider.overrideWith((ref) => mockRouter)],
      );

      listener = container.read(passwordResetListenerProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'navigates to reset password screen when URI contains a token',
      () async {
        const token = 'test-reset-token-abc123';
        when(() => mockRouter.go(any())).thenReturn(null);

        await listener.handleUri(
          Uri.parse('https://login.divine.video/reset-password?token=$token'),
        );

        verify(
          () =>
              mockRouter.go('${WelcomeScreen.resetPasswordPath}?token=$token'),
        ).called(1);
      },
    );

    test('ignores URIs with wrong host', () async {
      await listener.handleUri(
        Uri.parse('https://evil.com/reset-password?token=stolen-token'),
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
      when(() => mockRouter.go(any())).thenReturn(null);

      await listener.handleUri(
        Uri.parse('https://login.divine.video/reset-password'),
      );

      verifyNever(() => mockRouter.go(any()));
    });
  });
}
