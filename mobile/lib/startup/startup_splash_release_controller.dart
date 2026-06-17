import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:openvine/services/auth_service.dart';

/// Releases the native splash once startup auth has settled — and, for an
/// authenticated user, only after the router has navigated off the auth-entry
/// flow (`/welcome`).
///
/// This reproduces the synchronous-after-redirect ordering proven in #2953
/// (commit b7e06144a) while keeping splash logic out of [AuthService] (#5074).
/// PR #5074 released the splash on the bare terminal auth event via a multi-hop
/// async chain, which let the `/welcome` sign-in page paint before the
/// `authenticated → /home` redirect was applied — the regression in #5242.
///
/// Release fires exactly once, on the first of:
///  * **settled**: `isTerminal(authState) && (authState != authenticated ||
///    !isAuthEntryLocation(location))` — authenticated users wait for the
///    redirect to leave `/welcome`; unauthenticated / `awaitingTosAcceptance`
///    users (whose destination *is* `/welcome`) and non-auth-entry routes
///    (e.g. the public `/video-recorder`) release immediately; or
///  * **timeout**: an independent [timeout] floor so a hung restore can never
///    strand the splash.
class StartupSplashReleaseController {
  /// Creates the controller and immediately begins watching for release.
  ///
  /// [authStateStream] / [currentAuthState] report the auth state;
  /// [locationListenable] / [currentLocation] report the current router
  /// location (e.g. `GoRouter.routeInformationProvider` and
  /// `() => router.routeInformationProvider.value.uri.path`);
  /// [isAuthEntryLocation] is the router predicate of the same name.
  /// [release] defaults to [FlutterNativeSplash.remove]; [timeout] defaults to
  /// [AuthService.startupAuthRestoreTimeout].
  StartupSplashReleaseController({
    required Stream<AuthState> authStateStream,
    required AuthState Function() currentAuthState,
    required Listenable locationListenable,
    required String Function() currentLocation,
    required bool Function(String location) isAuthEntryLocation,
    Duration timeout = AuthService.startupAuthRestoreTimeout,
    void Function() release = FlutterNativeSplash.remove,
    bool Function(AuthState state)? isTerminal,
  }) : _currentAuthState = currentAuthState,
       _locationListenable = locationListenable,
       _currentLocation = currentLocation,
       _isAuthEntryLocation = isAuthEntryLocation,
       _release = release,
       _isTerminal = isTerminal ?? _defaultIsTerminal {
    // Cover the case where startup already settled before we subscribed
    // (e.g. a warm local-key restore).
    _maybeRelease();
    if (_released) return;
    _authSubscription = authStateStream.listen((_) => _maybeRelease());
    _locationListenable.addListener(_maybeRelease);
    _timeoutTimer = Timer(timeout, _releaseOnce);
  }

  final AuthState Function() _currentAuthState;
  final Listenable _locationListenable;
  final String Function() _currentLocation;
  final bool Function(String location) _isAuthEntryLocation;
  final void Function() _release;
  final bool Function(AuthState state) _isTerminal;

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _timeoutTimer;
  bool _released = false;

  void _maybeRelease() {
    if (_released) return;
    final state = _currentAuthState();
    if (!_isTerminal(state)) return;
    final settled =
        state != AuthState.authenticated ||
        !_isAuthEntryLocation(_currentLocation());
    if (settled) _releaseOnce();
  }

  void _releaseOnce() {
    if (_released) return;
    _released = true;
    _release();
    _teardown();
  }

  void _teardown() {
    unawaited(_authSubscription?.cancel());
    _authSubscription = null;
    _locationListenable.removeListener(_maybeRelease);
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  /// Detaches all listeners and the timeout without releasing the splash if it
  /// has not already fired. Safe to call multiple times.
  void dispose() {
    _released = true;
    _teardown();
  }

  static bool _defaultIsTerminal(AuthState state) => switch (state) {
    AuthState.unauthenticated ||
    AuthState.awaitingTosAcceptance ||
    AuthState.authenticated => true,
    AuthState.checking || AuthState.authenticating => false,
  };
}
