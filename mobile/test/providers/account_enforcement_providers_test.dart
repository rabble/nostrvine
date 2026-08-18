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
import 'package:openvine/repositories/account_enforcement_repository.dart';
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
      when(() => authService.isRegistered).thenReturn(true);
      when(() => authService.hasExpiredOAuthSession).thenReturn(false);
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
    when(() => authService.isRegistered).thenReturn(true);
    when(() => authService.hasExpiredOAuthSession).thenReturn(false);
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

  test(
    'a self-custody account reports no account state, without fetching',
    () async {
      // Only a divineOAuth account has a Keycast session. An imported or locally
      // generated key has no Divine account to be suspended, so "we could not
      // check, try again" would be a lie: retrying can never resolve it.
      var requests = 0;
      final authService = _MockAuthService();
      when(() => authService.isRegistered).thenReturn(false);

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

      final status = await container.read(
        accountEnforcementStatusProvider.future,
      );

      expect(status.kind, AccountEnforcementKind.noAccountState);
      expect(requests, 0, reason: 'no Keycast session to ask');
    },
  );

  test(
    'an expired session says so, rather than "we could not check"',
    () async {
      // The app already knows the session is dead and Settings offers re-auth.
      // Reporting a generic failure would send the user at a retry button that
      // can never succeed.
      var requests = 0;
      final authService = _MockAuthService();
      when(() => authService.isRegistered).thenReturn(true);
      when(() => authService.hasExpiredOAuthSession).thenReturn(false);
      when(() => authService.hasExpiredOAuthSession).thenReturn(true);

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

      final status = await container.read(
        accountEnforcementStatusProvider.future,
      );

      expect(status.kind, AccountEnforcementKind.sessionExpired);
      expect(requests, 0, reason: 'a dead session is not worth asking with');
    },
  );

  test(
    'a failed refresh does not clear an earned restriction marker',
    () async {
      // The settings marker is a warning. An offline refresh must not erase it:
      // only a successful read saying otherwise should lift it.
      var call = 0;
      final container = ProviderContainer(
        overrides: [
          accountEnforcementStatusProvider.overrideWith((ref) async {
            call++;
            if (call == 1) {
              return const AccountEnforcementStatus(
                kind: AccountEnforcementKind.suspended,
              );
            }
            throw const AccountStatusUnavailable();
          }),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(isAccountEnforcedProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(accountEnforcementStatusProvider.future);
      expect(container.read(isAccountEnforcedProvider), isTrue);

      container.invalidate(accountEnforcementStatusProvider);
      await expectLater(
        container.read(accountEnforcementStatusProvider.future),
        throwsA(isA<AccountStatusUnavailable>()),
      );

      expect(
        container.read(isAccountEnforcedProvider),
        isTrue,
        reason: 'a failed read must not lift a restriction we already saw',
      );
    },
  );

  test('authenticated: an active account reports none', () async {
    final authService = _MockAuthService();
    when(() => authService.isRegistered).thenReturn(true);
    when(() => authService.hasExpiredOAuthSession).thenReturn(false);
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
