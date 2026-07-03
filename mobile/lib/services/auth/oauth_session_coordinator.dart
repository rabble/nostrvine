// ABOUTME: Single-flight coordinator for Divine/Keycast OAuth session refresh.
// ABOUTME: Owns the dedup futures + timeouts so concurrent 401s, app-resume,
// ABOUTME: and expired-session recovery share one refresh-token exchange.

import 'dart:async';

import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:unified_logger/unified_logger.dart';

/// Coordinates OAuth session refresh so concurrent callers never race on a
/// one-time-use refresh token.
///
/// Extracted from `AuthService` (#4741, repository tier). Unlike the other
/// collaborators this one is STATEFUL: it owns the two single-flight futures
/// ([_pendingOAuthRefresh]/[_pendingRefresh]) — process-lifetime concurrency
/// state, not per-call snapshots. The facade retains ownership of the
/// `_hasExpiredOAuthSession` flag (written by restore orchestration) and all
/// result application (rebuilding the signer, `signInWithDivineOAuth`), reached
/// here through the injected ports so behavior is preserved exactly.
class OAuthSessionCoordinator {
  OAuthSessionCoordinator({
    required KeycastOAuth? oauthClient,
    required Duration oauthRefreshTimeout,
    required Duration expiredSessionRefreshTimeout,
    required String? Function() currentPubkeyFallback,
    required bool Function() hasExpiredSession,
    required void Function() onRefreshSucceeded,
  }) : _oauthClient = oauthClient,
       _oauthRefreshTimeout = oauthRefreshTimeout,
       _expiredSessionRefreshTimeout = expiredSessionRefreshTimeout,
       _currentPubkeyFallback = currentPubkeyFallback,
       _hasExpiredSession = hasExpiredSession,
       _onRefreshSucceeded = onRefreshSucceeded;

  final KeycastOAuth? _oauthClient;
  final Duration _oauthRefreshTimeout;
  final Duration _expiredSessionRefreshTimeout;
  final String? Function() _currentPubkeyFallback;
  final bool Function() _hasExpiredSession;
  final void Function() _onRefreshSucceeded;

  Future<bool>? _pendingRefresh;
  Future<KeycastSession?>? _pendingOAuthRefresh;

  /// Runs [attempt] under an outer single-flight, bounded by
  /// [expiredSessionRefreshTimeout], to silently refresh an expired OAuth
  /// session. [attempt] performs the refresh + result application (the caller
  /// wires it to `_tryRefreshOAuthSession`).
  ///
  /// No-ops (returns false) unless [hasExpiredSession] and an OAuth client are
  /// both present. Concurrent callers share the in-flight attempt; the shared
  /// future always releases the slot even on a hung request (#4942).
  Future<bool> refreshExpiredSession({
    required Future<bool> Function() attempt,
  }) {
    if (!_hasExpiredSession() || _oauthClient == null) {
      return Future.value(false);
    }
    final pending = _pendingRefresh;
    if (pending != null) return pending;

    late final Future<bool> refresh;
    refresh = attempt()
        .timeout(
          _expiredSessionRefreshTimeout,
          onTimeout: () {
            Log.warning(
              'tryRefreshExpiredSession: timed out after '
              '${_expiredSessionRefreshTimeout.inMilliseconds}ms — '
              'treating as failed',
              name: 'OAuthSessionCoordinator',
              category: LogCategory.auth,
            );
            return false;
          },
        )
        .whenComplete(() {
          // Only release the slot if it still holds this attempt — signOut
          // may have detached it and a fresh attempt may already be in
          // flight.
          if (identical(_pendingRefresh, refresh)) {
            _pendingRefresh = null;
          }
        });
    return _pendingRefresh = refresh;
  }

  /// Single-flight OAuth session refresh. Every code path that needs a fresh
  /// [KeycastSession] MUST call this instead of `KeycastOAuth.refreshSession()`
  /// directly.
  ///
  /// Guarantees:
  /// - Only one `refreshSession()` call in flight at a time (concurrent
  ///   callers share the same [Future]).
  /// - The shared future is bounded by [oauthRefreshTimeout] and ALWAYS
  ///   releases the single-flight slot, even if the underlying request hangs
  ///   on a dead socket — so the next attempt gets a fresh refresh instead of
  ///   joining a poisoned one (#4942).
  /// - `userPubkey` is bound before the session is persisted, so ownership
  ///   checks on restore stay valid.
  /// - [onRefreshSucceeded] runs on success (the facade clears its
  ///   `_hasExpiredOAuthSession` flag there).
  ///
  /// [expectedOwnerPubkey] binds the refreshed session to a specific account.
  /// Callers that hold a stored session should pass its `userPubkey`;
  /// mid-session callers (401 retry, app resume) may omit it — the method
  /// falls back to [currentPubkeyFallback].
  ///
  /// Returns the refreshed session on success, or `null` on failure.
  Future<KeycastSession?> refreshSession({String? expectedOwnerPubkey}) {
    final pending = _pendingOAuthRefresh;
    if (pending != null) return pending;

    late final Future<KeycastSession?> refresh;
    refresh = _doRefreshSession(expectedOwnerPubkey: expectedOwnerPubkey)
        .timeout(
          _oauthRefreshTimeout,
          onTimeout: () {
            Log.warning(
              '_refreshOAuthSession: timed out after '
              '${_oauthRefreshTimeout.inMilliseconds}ms — '
              'treating as failed',
              name: 'OAuthSessionCoordinator',
              category: LogCategory.auth,
            );
            return null;
          },
        )
        .whenComplete(() {
          // Only release the slot if it still holds this attempt — signOut
          // may have detached it and a fresh attempt may already be in
          // flight.
          if (identical(_pendingOAuthRefresh, refresh)) {
            _pendingOAuthRefresh = null;
          }
        });
    return _pendingOAuthRefresh = refresh;
  }

  Future<KeycastSession?> _doRefreshSession({
    String? expectedOwnerPubkey,
  }) async {
    final oauthClient = _oauthClient;
    if (oauthClient == null) return null;
    try {
      final pubkey = expectedOwnerPubkey ?? _currentPubkeyFallback();
      final refreshed = await oauthClient.refreshSession(userPubkey: pubkey);
      if (refreshed == null || !refreshed.hasRpcAccess) return null;

      _onRefreshSucceeded();
      Log.info(
        '_refreshOAuthSession: succeeded '
        '(userPubkey=${refreshed.userPubkey != null ? "bound" : "unbound"})',
        name: 'OAuthSessionCoordinator',
        category: LogCategory.auth,
      );
      return refreshed;
    } catch (e) {
      Log.error(
        '_refreshOAuthSession: failed: $e',
        name: 'OAuthSessionCoordinator',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// [TokenRefreshCallback] passed to [KeycastRpc] so it can recover from
  /// mid-session 401s without caller involvement.
  ///
  /// Delegates to [refreshSession] which deduplicates concurrent callers —
  /// multiple in-flight RPC 401s and app-resume refresh all share a single
  /// refresh token exchange.
  Future<String?> refreshAccessToken() async {
    final refreshed = await refreshSession();
    return refreshed?.accessToken;
  }

  /// Detaches any in-flight refresh so a post-sign-out login starts a fresh
  /// attempt instead of joining one issued for the outgoing session.
  ///
  /// The futures cannot be cancelled, but their completion handlers only
  /// release the slot they still own (identical check), so a late completion
  /// cannot clobber a newer attempt. Deliberately does NOT touch the facade's
  /// expired-session flag — sign-out clears the futures but not that flag.
  void detach() {
    _pendingOAuthRefresh = null;
    _pendingRefresh = null;
  }
}
