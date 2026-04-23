// ABOUTME: Tests the top-level /reset-password GoRoute redirect preserves
// ABOUTME: the token and email query params when rewriting to the nested path

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/app_router.dart'
    show rewriteResetPasswordDeepLink;
import 'package:openvine/screens/auth/reset_password.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('${ResetPasswordScreen.path} deep-link redirect', () {
    test('forwards token and email when both are present', () {
      final rewritten = Uri.parse(
        rewriteResetPasswordDeepLink(
          Uri.parse('${ResetPasswordScreen.path}?token=T&email=u%40x.com'),
        ),
      );

      expect(rewritten.path, equals(WelcomeScreen.resetPasswordPath));
      expect(
        rewritten.queryParameters,
        equals(<String, String>{'token': 'T', 'email': 'u@x.com'}),
        reason:
            'email must survive the redirect so ResetPasswordScreen can '
            'render the AutofillHints.username field (issue #3156)',
      );
    });

    test('omits email param when absent — backward compat with old '
        'reset emails still in users inboxes', () {
      final rewritten = Uri.parse(
        rewriteResetPasswordDeepLink(
          Uri.parse('${ResetPasswordScreen.path}?token=T'),
        ),
      );

      expect(rewritten.path, equals(WelcomeScreen.resetPasswordPath));
      expect(rewritten.queryParameters['token'], equals('T'));
      expect(
        rewritten.queryParameters.containsKey('email'),
        isFalse,
        reason:
            'redirect must not fabricate an email param when the deep '
            'link did not carry one',
      );
    });

    test('omits email param when empty string', () {
      final rewritten = Uri.parse(
        rewriteResetPasswordDeepLink(
          Uri.parse('${ResetPasswordScreen.path}?token=T&email='),
        ),
      );

      expect(rewritten.queryParameters['token'], equals('T'));
      expect(
        rewritten.queryParameters.containsKey('email'),
        isFalse,
        reason: 'empty-string email must not round-trip through the redirect',
      );
    });

    test('URL-encodes email specials so the nested route decodes them '
        'intact', () {
      final rewritten = Uri.parse(
        rewriteResetPasswordDeepLink(
          Uri.parse('${ResetPasswordScreen.path}?token=T&email=a%2Bb%40x.com'),
        ),
      );

      expect(
        rewritten.queryParameters['email'],
        equals('a+b@x.com'),
        reason:
            'the + in a+b@x.com is a common query-encoding gotcha — the '
            'rewritten URL must be decodable back to the original email',
      );
    });

    test('handles missing token without emitting the string "null"', () {
      final rewritten = rewriteResetPasswordDeepLink(
        Uri.parse(ResetPasswordScreen.path),
      );

      expect(
        rewritten,
        isNot(contains('null')),
        reason:
            'prior code emitted ?token=null via string interpolation when '
            'the token query param was absent',
      );
      expect(Uri.parse(rewritten).queryParameters['token'], equals(''));
    });
  });
}
