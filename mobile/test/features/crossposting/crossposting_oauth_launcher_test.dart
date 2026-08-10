// ABOUTME: Tests the native crossposting OAuth browser adapter and callback.
// ABOUTME: Pins exact HTTPS routing plus cancellation and platform failures.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:openvine/features/crossposting/crossposting_oauth_launcher.dart';

// The callback validator is shared with the verify flow, so the message is
// no longer crossposting-specific.
const _invalidCallbackMessage =
    'Invalid OAuth callback. Expected '
    'https://divine.video/app/callback with no user info or explicit port.';

void main() {
  group('launchCrosspostingOAuth', () {
    test(
      'passes the exact authorization and HTTPS callback arguments',
      () async {
        final authorizationUri = Uri.parse(
          'https://crossposter.example/oauth/start?platform=youtube',
        );
        final callbackUri = Uri.parse(
          'https://divine.video/app/callback?connection=connected',
        );
        String? receivedUrl;
        String? receivedCallbackUrlScheme;
        FlutterWebAuth2Options? receivedOptions;

        final result = await launchCrosspostingOAuth(
          authorizationUri,
          authenticate:
              ({
                required url,
                required callbackUrlScheme,
                required options,
              }) async {
                receivedUrl = url;
                receivedCallbackUrlScheme = callbackUrlScheme;
                receivedOptions = options;
                return callbackUri.toString();
              },
        );

        expect(receivedUrl, authorizationUri.toString());
        expect(receivedCallbackUrlScheme, 'https');
        expect(receivedOptions?.httpsHost, 'divine.video');
        expect(receivedOptions?.httpsPath, '/app/callback');
        expect(result, callbackUri);
      },
    );

    test(
      'uses a deterministic FormatException for malformed percent triplets',
      () async {
        const malformedCallbacks = <String>[
          'https://divine.video/app/callback?code=%',
          'https://divine.video/app/callback?code=%A',
          'https://divine.video/app/callback?code=%ZZ',
        ];

        for (final callback in malformedCallbacks) {
          await expectLater(
            launchCrosspostingOAuth(
              Uri.parse('https://crossposter.example/oauth/start'),
              authenticate: _authenticateReturning(callback),
            ),
            throwsA(_invalidCallbackFormat),
          );
        }
      },
    );

    test('rejects callbacks outside the exact HTTPS return route', () async {
      const invalidCallbacks = <String, String>{
        'relative URI': '/app/callback?connection=connected',
        'wrong scheme': 'http://divine.video/app/callback',
        'uppercase scheme': 'HTTPS://divine.video/app/callback',
        'wrong host': 'https://example.com/app/callback',
        'uppercase host': 'https://DIVINE.VIDEO/app/callback',
        'Divine subdomain': 'https://login.divine.video/app/callback',
        'wrong path': 'https://divine.video/app/callback/',
        'explicit port': 'https://divine.video:443/app/callback',
        'user info': 'https://user@divine.video/app/callback',
        'empty user info': 'https://@divine.video/app/callback',
      };

      for (final invalidCallback in invalidCallbacks.entries) {
        await expectLater(
          launchCrosspostingOAuth(
            Uri.parse('https://crossposter.example/oauth/start'),
            authenticate: _authenticateReturning(invalidCallback.value),
          ),
          throwsA(_invalidCallbackFormat),
          reason: invalidCallback.key,
        );
      }
    });

    test('does not expose OAuth code or state in callback errors', () async {
      const secretCode = 'oauth-code-super-secret';
      const secretState = 'oauth-state-super-secret';
      const callback =
          'https://divine.video:443/app/callback'
          '?code=$secretCode&state=$secretState';
      FormatException? caught;

      try {
        await launchCrosspostingOAuth(
          Uri.parse('https://crossposter.example/oauth/start'),
          authenticate: _authenticateReturning(callback),
        );
      } on FormatException catch (error) {
        caught = error;
      }

      expect(caught, isNotNull);
      expect(caught?.message, _invalidCallbackMessage);
      expect(caught?.source, isNull);
      expect(caught.toString(), isNot(contains(secretCode)));
      expect(caught.toString(), isNot(contains(secretState)));
    });

    test('returns null when the platform reports CANCELED', () async {
      final result = await launchCrosspostingOAuth(
        Uri.parse('https://crossposter.example/oauth/start'),
        authenticate:
            ({
              required url,
              required callbackUrlScheme,
              required options,
            }) async {
              throw PlatformException(code: 'CANCELED');
            },
      );

      expect(result, isNull);
    });

    test('rethrows every other platform error', () async {
      final error = PlatformException(
        code: 'AUTHENTICATION_FAILED',
        message: 'Browser launch failed',
      );

      await expectLater(
        launchCrosspostingOAuth(
          Uri.parse('https://crossposter.example/oauth/start'),
          authenticate:
              ({
                required url,
                required callbackUrlScheme,
                required options,
              }) async {
                throw error;
              },
        ),
        throwsA(same(error)),
      );
    });
  });
}

CrosspostingAuthenticate _authenticateReturning(String callback) =>
    ({
      required url,
      required callbackUrlScheme,
      required options,
    }) async => callback;

final Matcher _invalidCallbackFormat = isA<FormatException>()
    .having((error) => error.message, 'message', _invalidCallbackMessage)
    .having((error) => error.source, 'source', isNull);
