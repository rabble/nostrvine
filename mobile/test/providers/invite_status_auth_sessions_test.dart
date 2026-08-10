// ABOUTME: Tests the invite status auth-session bridge.
// ABOUTME: Pins late signer capability without waiting for relay readiness.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/invite_status_auth_sessions.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  // A Keycast identity with no local key: the pubkey is known well before the
  // remote signer is usable.
  const keycastPubkey =
      'fc7031a810ce4b02b6195a7e477cfe3d08c0386038bd45b4431f82d9b3f5ffb0';

  late _MockAuthService authService;
  late StreamController<AuthState> authStateController;
  late StreamController<AuthRpcCapability> rpcCapabilityController;

  setUp(() {
    authService = _MockAuthService();
    authStateController = StreamController<AuthState>.broadcast();
    rpcCapabilityController = StreamController<AuthRpcCapability>.broadcast();

    when(() => authService.authState).thenReturn(AuthState.authenticated);
    when(
      () => authService.authStateStream,
    ).thenAnswer((_) => authStateController.stream);
    when(() => authService.currentPublicKeyHex).thenReturn(keycastPubkey);
    when(() => authService.canPublishNostrWritesNow).thenReturn(false);
    when(
      () => authService.authRpcCapability,
    ).thenReturn(AuthRpcCapability.unavailable);
    when(
      () => authService.authRpcCapabilityStream,
    ).thenAnswer((_) => rpcCapabilityController.stream);
  });

  tearDown(() async {
    await authStateController.close();
    await rpcCapabilityController.close();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(authService)],
    );
    addTearDown(container.dispose);
    return container;
  }

  InviteStatusAuthSession session({
    required String? accountId,
    required bool isSignerReady,
  }) => InviteStatusAuthSession(
    accountId: accountId,
    isSignerReady: isSignerReady,
  );

  group('inviteStatusAuthSessionProvider', () {
    test('reports no account while signed out', () {
      when(() => authService.authState).thenReturn(AuthState.unauthenticated);
      when(() => authService.currentPublicKeyHex).thenReturn(null);

      final container = createContainer();

      expect(
        container.read(inviteStatusAuthSessionProvider),
        equals(session(accountId: null, isSignerReady: false)),
      );
    });

    test('reports no signer while only the identity is known', () {
      final container = createContainer();

      expect(
        container.read(inviteStatusAuthSessionProvider),
        equals(session(accountId: keycastPubkey, isSignerReady: false)),
      );
    });

    test('reports a signer from auth capability before relay readiness', () {
      when(() => authService.canPublishNostrWritesNow).thenReturn(true);
      when(
        () => authService.authRpcCapability,
      ).thenReturn(AuthRpcCapability.rpcReady);

      final container = createContainer();

      expect(
        container.read(inviteStatusAuthSessionProvider),
        equals(session(accountId: keycastPubkey, isSignerReady: true)),
      );
    });
  });

  group('inviteStatusAuthSessionsProvider', () {
    // Reading auth state instead of RPC capability makes this await forever
    // rather than fail, so the await is bounded (#6977).
    const awaitBound = Duration(seconds: 5);

    test(
      'emits a ready session when RPC capability arrives after identity',
      () async {
        final container = createContainer();

        final sessions = container.read(inviteStatusAuthSessionsProvider);
        final expectation = expectLater(
          sessions.timeout(awaitBound),
          emitsInOrder([
            session(accountId: keycastPubkey, isSignerReady: false),
            session(accountId: keycastPubkey, isSignerReady: true),
          ]),
        );

        await Future<void>.delayed(Duration.zero);
        when(() => authService.canPublishNostrWritesNow).thenReturn(true);
        when(
          () => authService.authRpcCapability,
        ).thenReturn(AuthRpcCapability.rpcReady);
        rpcCapabilityController.add(AuthRpcCapability.rpcReady);

        await expectation;
      },
    );

    test(
      'emits when the auth session source recomputes after being read once',
      () async {
        when(() => authService.authState).thenReturn(AuthState.unauthenticated);
        when(() => authService.currentPublicKeyHex).thenReturn(null);

        final container = createContainer();

        final sessions = container.read(inviteStatusAuthSessionsProvider);
        final expectation = expectLater(
          sessions.timeout(awaitBound),
          emitsInOrder([
            session(accountId: null, isSignerReady: false),
            session(accountId: keycastPubkey, isSignerReady: true),
          ]),
        );

        await Future<void>.delayed(Duration.zero);
        when(() => authService.authState).thenReturn(AuthState.authenticated);
        when(() => authService.currentPublicKeyHex).thenReturn(keycastPubkey);
        when(() => authService.canPublishNostrWritesNow).thenReturn(true);
        authStateController.add(AuthState.authenticated);

        await expectation;
      },
    );
  });
}
