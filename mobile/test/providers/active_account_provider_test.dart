// ABOUTME: Tests for activeAccountProvider — the AccountScope bridge derived
// ABOUTME: from AuthService's current session.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/services/auth/account_scope.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrSigner extends Mock implements NostrSigner {}

NostrIdentity _identity(String pubkey) =>
    KeycastNostrIdentity(pubkey: pubkey, rpcSigner: _MockNostrSigner());

void main() {
  const pubkeyA =
      'aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111';

  late _MockAuthService authService;
  late StreamController<AuthState> authStateController;

  setUp(() {
    authService = _MockAuthService();
    authStateController = StreamController<AuthState>.broadcast();
    when(
      () => authService.authStateStream,
    ).thenAnswer((_) => authStateController.stream);
    when(
      () => authService.authenticationSource,
    ).thenReturn(AuthenticationSource.automatic);
  });

  tearDown(() => authStateController.close());

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(authService)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('is SignedOut when unauthenticated', () {
    when(() => authService.authState).thenReturn(AuthState.unauthenticated);
    when(() => authService.currentIdentity).thenReturn(null);
    when(() => authService.currentPublicKeyHex).thenReturn(null);

    final scope = buildContainer().read(activeAccountProvider);

    expect(scope, isA<SignedOut>());
    expect(scope.activePubkeyHex, isNull);
  });

  test('is SignedIn with the current session when authenticated', () {
    final identity = _identity(pubkeyA);
    when(() => authService.authState).thenReturn(AuthState.authenticated);
    when(() => authService.currentIdentity).thenReturn(identity);
    when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
    when(
      () => authService.authenticationSource,
    ).thenReturn(AuthenticationSource.bunker);

    final scope = buildContainer().read(activeAccountProvider);

    expect(scope, isA<SignedIn>());
    final session = (scope as SignedIn).session;
    expect(session.pubkeyHex, equals(pubkeyA));
    expect(session.identity, same(identity));
    expect(session.source, equals(AuthenticationSource.bunker));
  });

  test('is SignedOut when authenticated but identity is missing', () {
    when(() => authService.authState).thenReturn(AuthState.authenticated);
    when(() => authService.currentIdentity).thenReturn(null);
    when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);

    expect(buildContainer().read(activeAccountProvider), isA<SignedOut>());
  });

  test('re-derives from SignedOut to SignedIn on an auth transition', () async {
    when(() => authService.authState).thenReturn(AuthState.unauthenticated);
    when(() => authService.currentIdentity).thenReturn(null);
    when(() => authService.currentPublicKeyHex).thenReturn(null);

    final container = buildContainer();
    expect(container.read(activeAccountProvider), isA<SignedOut>());

    final identity = _identity(pubkeyA);
    when(() => authService.authState).thenReturn(AuthState.authenticated);
    when(() => authService.currentIdentity).thenReturn(identity);
    when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
    authStateController.add(AuthState.authenticated);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(activeAccountProvider), isA<SignedIn>());
  });
}
