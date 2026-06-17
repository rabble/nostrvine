import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:openvine/services/auth_service.dart';

/// Releases the native splash once startup auth has settled — and, for an
/// authenticated user, only while the router still has a pending home-redirect
/// off the auth-entry flow (`/welcome`).
///
/// This reproduces the synchronous-after-redirect ordering proven in #2953
/// (commit b7e06144a) while keeping splash logic out of [AuthService] (#5074).
/// PR #5074 released the splash on the bare terminal auth event via a multi-hop
/// async chain, which let the `/welcome` sign-in page paint before the
/// `authenticated → /home` redirect was applied — the regression in #5242.
///
/// Release fires exactly once, on the first of:
///  * **settled**: `isTerminal(authState) && (authState != authenticated ||
///    !authenticatedRedirectPending(location))` — an authenticated user holds
///    only while the router still has a home-redirect pending for the current
///    auth-entry route (e.g. `/welcome`). Once that redirect lands, or for any
///    location an authenticated user is left on (the feed, a reset-password /
///    email-verification deep link, an expired-session login-options screen,
///    the public `/video-recorder`), and for unauthenticated /
///    `awaitingTosAcceptance` users (whose destination *is* `/welcome`), it
///    releases immediately; or
///  * **timeout**: an independent [timeout] floor so a hung restore can never
///    strand the splash.
class StartupSplashReleaseController {
  /// Creates the controller and immediately begins watching for release.
  ///
  /// [authStateStream] / [currentAuthState] report the auth state;
  /// [locationListenable] / [currentLocation] report the current router
  /// location. Use a signal that fires after redirects, such as
  /// `GoRouter.routerDelegate` with `currentConfiguration.uri.path`.
  /// [authenticatedRedirectPending] reports whether an authenticated user on a
  /// given location still has a home-redirect pending — wire it to
  /// `authenticatedRedirectsFromAuthEntry` in the router so the splash gate
  /// stays aligned with the actual redirect.
  /// [release] defaults to [FlutterNativeSplash.remove]; [timeout] defaults to
  /// [AuthService.startupAuthRestoreTimeout].
  StartupSplashReleaseController({
    required Stream<AuthState> authStateStream,
    required AuthState Function() currentAuthState,
    required Listenable locationListenable,
    required String Function() currentLocation,
    required bool Function(String location) authenticatedRedirectPending,
    Duration timeout = AuthService.startupAuthRestoreTimeout,
    void Function() release = FlutterNativeSplash.remove,
    bool Function(AuthState state)? isTerminal,
  }) : _currentAuthState = currentAuthState,
       _locationListenable = locationListenable,
       _currentLocation = currentLocation,
       _authenticatedRedirectPending = authenticatedRedirectPending,
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
  final bool Function(String location) _authenticatedRedirectPending;
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
        !_authenticatedRedirectPending(_currentLocation());
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
