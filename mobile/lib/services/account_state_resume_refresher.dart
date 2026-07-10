// ABOUTME: TTL-guarded refetch of the protected-minor account-state providers
// ABOUTME: on app foreground-resume, so server-side flips are picked up promptly

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/minor_account_review_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';

/// Refetches the protected-minor safeguards' account-state providers on app
/// foreground-resume, so a server-side flip that lands while the app sits
/// idle-authenticated is picked up without waiting for a relaunch or re-auth.
///
/// Guarded by [minInterval]: resolving [protectedMinorStatusProvider] can
/// trigger a Keycast token refresh, so a frequent backgrounder must not force a
/// refetch on every foreground. Invalidation only ever strengthens protection
/// or correctly lifts it — the gate providers read the sticky last-known value
/// during the reload, so a protected minor never flickers open.
class AccountStateResumeRefresher {
  AccountStateResumeRefresher({
    required VoidCallback invalidateProtectedMinorStatus,
    required VoidCallback invalidateReviewStatus,
    Duration minInterval = const Duration(minutes: 15),
    DateTime Function() now = DateTime.now,
  }) : _invalidateProtectedMinorStatus = invalidateProtectedMinorStatus,
       _invalidateReviewStatus = invalidateReviewStatus,
       _minInterval = minInterval,
       _now = now;

  final VoidCallback _invalidateProtectedMinorStatus;
  final VoidCallback _invalidateReviewStatus;
  final Duration _minInterval;
  final DateTime Function() _now;

  // Intentionally not keyed by account: an account switch transits a
  // non-authenticated authState that invalidates the status providers
  // directly, so this only bounds the resume-triggered refetch, not
  // switch-time freshness.
  DateTime? _lastRefreshedAt;

  /// Invalidate both account-state providers, unless the account is
  /// unauthenticated or the last refresh was within [minInterval].
  void refreshOnResume({required bool authenticated}) {
    if (!authenticated) return;
    final now = _now();
    final last = _lastRefreshedAt;
    if (last != null && now.difference(last) < _minInterval) return;
    _lastRefreshedAt = now;
    _invalidateProtectedMinorStatus();
    _invalidateReviewStatus();
  }
}

/// App-lifetime coordinator wired to invalidate the real account-state
/// providers. Held alive by the container; the resume handler reads it on each
/// foreground transition.
final accountStateResumeRefresherProvider =
    Provider<AccountStateResumeRefresher>((ref) {
      return AccountStateResumeRefresher(
        invalidateProtectedMinorStatus: () =>
            ref.invalidate(protectedMinorStatusProvider),
        invalidateReviewStatus: () =>
            ref.invalidate(currentMinorAccountReviewStatusProvider),
      );
    });
