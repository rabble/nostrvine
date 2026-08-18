// ABOUTME: Tests accountEnforcementStatusProvider: unauthenticated yields no
// ABOUTME: signal, and the authenticated path threads the session token.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

KeycastOAuth _oauthReturning(
  String body, {
  void Function(http.Request)? onCall,
}) {
  return KeycastOAuth(
    config: const OAuthConfig(
      serverUrl: 'https://login.divine.video',
      clientId: 'c',
      redirectUri: 'divine://cb',
    ),
    storage: MemoryKeycastStorage(),
    httpClient: MockClient((req) async {
      onCall?.call(req);
      return http.Response(body, 200);
    }),
  );
}

const _activeBody =
    '{"email":"a","email_verified":true,"public_key":"p",'
    '"verified_minor":false}';

const _suspendedBody =
    '{"email":"a","email_verified":true,"public_key":"p",'
    '"verified_minor":false,"account_status":"suspended"}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unauthenticated resolves to unknown without any fetch', () async {
    // There is no account to report on, so there is no signal. It must not
    // resolve to `none`, which is a positive claim of good standing.
    var requests = 0;
    final container = ProviderContainer(
      overrides: [
        currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
        oauthClientProvider.overrideWithValue(
          _oauthReturning(_activeBody, onCall: (_) => requests++),
        ),
      ],
    );
    addTearDown(container.dispose);

    final status = await container.read(
      accountEnforcementStatusProvider.future,
    );

    expect(status.kind, AccountEnforcementKind.unknown);
    expect(requests, 0);
  });

  test(
    'authenticated: threads the session token and reports suspended',
    () async {
      final authService = _MockAuthService();
      when(
        authService.activeAccountKeycastToken,
      ).thenAnswer((_) async => 'tok123');

      final container = ProviderContainer(
        overrides: [
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          oauthClientProvider.overrideWithValue(
            _oauthReturning(
              _suspendedBody,
              // Proves the provider threads the session token into the request
              // rather than querying some other account.
              onCall: (req) =>
                  expect(req.headers['Authorization'], 'Bearer tok123'),
            ),
          ),
          authServiceProvider.overrideWithValue(authService),
        ],
      );
      addTearDown(container.dispose);

      final status = await container.read(
        accountEnforcementStatusProvider.future,
      );

      expect(status.kind, AccountEnforcementKind.suspended);
      expect(status.isEnforced, isTrue);
    },
  );

  test('refetches after nothing is listening, so a mid-session suspension '
      'is seen', () async {
    // The status a user opens Settings to check must be current. Without
    // autoDispose the first read caches for the whole app session, so an
    // account suspended after launch keeps reading "in good standing" until
    // the app is restarted — the exact failure this surface exists to fix.
    var requests = 0;
    final authService = _MockAuthService();
    when(
      authService.activeAccountKeycastToken,
    ).thenAnswer((_) async => 'tok123');

    final container = ProviderContainer(
      overrides: [
        currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
        oauthClientProvider.overrideWithValue(
          _oauthReturning(_activeBody, onCall: (_) => requests++),
        ),
        authServiceProvider.overrideWithValue(authService),
      ],
    );
    addTearDown(container.dispose);

    final first = container.listen(
      accountEnforcementStatusProvider,
      (_, _) {},
    );
    await container.read(accountEnforcementStatusProvider.future);
    expect(requests, 1);

    first.close();
    await Future<void>.delayed(Duration.zero);

    await container.read(accountEnforcementStatusProvider.future);
    expect(requests, 2, reason: 'status must be refetched, not served stale');
  });

  test('authenticated: an active account reports none', () async {
    final authService = _MockAuthService();
    when(
      authService.activeAccountKeycastToken,
    ).thenAnswer((_) async => 'tok123');

    final container = ProviderContainer(
      overrides: [
        currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
        oauthClientProvider.overrideWithValue(_oauthReturning(_activeBody)),
        authServiceProvider.overrideWithValue(authService),
      ],
    );
    addTearDown(container.dispose);

    final status = await container.read(
      accountEnforcementStatusProvider.future,
    );

    expect(status.kind, AccountEnforcementKind.none);
    expect(status.isEnforced, isFalse);
  });
}
